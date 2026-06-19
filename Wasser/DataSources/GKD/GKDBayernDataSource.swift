import Foundation

/// Session cache of the latest water-temperature reading scraped from the GKD
/// overview tables, keyed by station id. It is a reference type (actor) so it is
/// shared across copies of the value-type `GKDBayernDataSource` and safe to
/// mutate concurrently while the overview is scraped.
actor GKDLatestStore {
    private var values: [String: Measurement] = [:]
    func set(_ measurement: Measurement, for id: String) { values[id] = measurement }
    func value(for id: String) -> Measurement? { values[id] }
}

/// `WaterDataSource` backed by the Gewässerkundlicher Dienst Bayern
/// (gkd.bayern.de). Maps scraped rows into the app's domain model. Weather is
/// merged in by `WaterRepository`, keeping this source purely hydrological.
///
/// Adaptability: this type only orchestrates. URL knowledge lives in
/// `GKDEndpoints`, parsing in `GKDParser`, transport in `GKDScraper`. Replacing
/// the scrape with a confirmed API means changing `GKDScraper` alone.
struct GKDBayernDataSource: WaterDataSource {
    let id = GKDStationCatalog.dataSourceID
    let displayName = "Gewässerkundlicher Dienst Bayern"

    private let scraper: GKDScraper
    /// When true, the network overview tables are scraped; otherwise only the
    /// bundled seed catalogue is returned (useful for previews / offline).
    private let useLiveCatalogue: Bool
    /// Current values harvested from the overview tables during `fetchStations`,
    /// reused by `fetchCurrentConditions` (the reliable source for lakes).
    private let latestStore = GKDLatestStore()

    init(scraper: GKDScraper = GKDScraper(),
         useLiveCatalogue: Bool = true) {
        self.scraper = scraper
        self.useLiveCatalogue = useLiveCatalogue
    }

    // MARK: - Stations

    func fetchStations() async throws -> [MeasurementStation] {
        let seed = GKDStationCatalog.stations()
        guard useLiveCatalogue else { return seed }

        async let rivers = scrapedStations(category: .rivers, type: .river)
        async let lakes = scrapedStations(category: .lakes, type: .lake)
        let scraped: [MeasurementStation]
        do {
            scraped = try await rivers + lakes
        } catch {
            scraped = []
        }

        // Prefer scraped stations (they carry real detail URLs *and* current
        // values). Add seed entries only for water bodies the scrape didn't
        // cover, so value-less placeholders never shadow a live station — the
        // root cause of lakes showing 0°. Matching tolerates spacing/spelling
        // differences ("Starnberger See" vs "StarnbergerSee").
        guard !scraped.isEmpty else { return seed }
        let covered = Set(scraped.map { GKDBayernDataSource.waterKey($0.waterBodyName) })
        var result = scraped
        for station in seed where !covered.contains(GKDBayernDataSource.waterKey(station.waterBodyName)) {
            result.append(station)
        }
        return result.sorted { $0.waterBodyName.localizedCompare($1.waterBodyName) == .orderedAscending }
    }

    private func scrapedStations(category: GKDEndpoints.Category,
                                 type: WaterBodyType) async throws -> [MeasurementStation] {
        let rows = try await scraper.overview(category: category)
        var stations: [MeasurementStation] = []
        for row in rows {
            guard let detail = row.detailURL else { continue }
            let external = GKDBayernDataSource.externalID(from: detail) ?? GKDBayernDataSource.slug(detail.absoluteString)
            let station = MeasurementStation(
                id: MeasurementStation.makeID(dataSourceID: id, externalID: external),
                externalID: external,
                dataSourceID: id,
                name: row.stationName,
                waterBodyName: row.waterBodyName.isEmpty ? row.stationName : row.waterBodyName,
                waterBodyType: type,
                region: row.region,
                latitude: 0, longitude: 0,   // overview table has no coordinates; enriched lazily
                elevation: nil,
                operatorName: "Bayerisches Landesamt für Umwelt",
                availableParameters: type == .river
                    ? [.waterTemperature, .waterLevel, .discharge]
                    : [.waterTemperature, .waterLevel],
                detailURL: detail
            )
            // Stash the current temperature from the overview so the detail/list
            // screens have a real value even when the station's messwerte page
            // carries no recent rows (true for the manually-read lake profiles).
            if let value = row.currentValue {
                await latestStore.set(
                    Measurement(parameter: .waterTemperature,
                                timestamp: row.timestamp ?? Date(),
                                value: value),
                    for: station.id)
            }
            stations.append(station)
        }
        return stations
    }

    // MARK: - Conditions

    func fetchCurrentConditions(for station: MeasurementStation) async throws -> StationConditions {
        var latest: [MeasurementParameter: Measurement] = [:]

        // Water temperature: trust the value harvested from the overview table.
        // It exists for every station (rivers and lakes alike), whereas lake
        // messwerte pages are manually-read multi-depth profiles with no recent
        // tabular rows to scrape.
        if let overview = await latestStore.value(for: station.id) {
            latest[.waterTemperature] = overview
        }

        // Fetch the remaining parameters (river level/discharge — and water
        // temperature only if the overview didn't supply it) from the messwerte
        // tables, which do render recent rows for those.
        let toFetch = station.availableParameters.filter {
            $0 != .waterTemperature || latest[.waterTemperature] == nil
        }
        if !toFetch.isEmpty {
            try await withThrowingTaskGroup(of: (MeasurementParameter, Measurement?).self) { group in
                for parameter in toFetch {
                    group.addTask { (parameter, try? await scraper.latestValue(for: station, parameter: parameter)) }
                }
                for try await (parameter, measurement) in group {
                    if let measurement { latest[parameter] = measurement }
                }
            }
        }
        return StationConditions(stationID: station.id, latest: latest, weather: nil)
    }

    func fetchTimeSeries(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         range: TimeRange) async throws -> TimeSeries {
        guard station.availableParameters.contains(parameter) else {
            throw DataSourceError.unsupportedParameter(parameter)
        }
        return try await scraper.timeSeries(for: station, parameter: parameter, range: range)
    }

    func fetchDailyTrend(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         days: Int) async throws -> [DailyAggregate] {
        let all = await scraper.dailyAggregates(for: station, parameter: parameter)
        return Array(all.sorted { $0.date > $1.date }.prefix(days))   // newest first
    }

    // MARK: - Matching / id helpers

    /// Normalised water-body key (umlaut-folded, alphanumerics only) used to
    /// decide whether the live scrape already covers a seed entry. Stripping
    /// hyphens/spaces makes "Starnberger See" and "StarnbergerSee" compare equal.
    static func waterKey(_ name: String) -> String {
        slug(name).replacingOccurrences(of: "-", with: "")
    }

    /// Extracts the trailing Messstellennummer from a GKD detail URL path
    /// (".../<place-slug>-<number>/messwerte").
    static func externalID(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        for component in parts.reversed() {
            if let match = component.range(of: "[0-9]{3,}$", options: .regularExpression) {
                return String(component[match])
            }
        }
        return nil
    }

    static func slug(_ string: String) -> String {
        let lower = string.lowercased()
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        return String(lower.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
