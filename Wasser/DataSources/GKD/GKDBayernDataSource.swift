import Foundation

/// `WaterDataSource` backed by the Gewässerkundlicher Dienst Bayern
/// (gkd.bayern.de). Maps scraped rows into the app's domain model and, when a
/// `WeatherProvider` is supplied, decorates current conditions with co-located
/// weather.
///
/// Adaptability: this type only orchestrates. URL knowledge lives in
/// `GKDEndpoints`, parsing in `GKDParser`, transport in `GKDScraper`. Replacing
/// the scrape with a confirmed API means changing `GKDScraper` alone.
struct GKDBayernDataSource: WaterDataSource {
    let id = GKDStationCatalog.dataSourceID
    let displayName = "Gewässerkundlicher Dienst Bayern"

    private let scraper: GKDScraper
    private let weather: WeatherProvider?
    /// When true, the network overview tables are scraped; otherwise only the
    /// bundled seed catalogue is returned (useful for previews / offline).
    private let useLiveCatalogue: Bool

    init(scraper: GKDScraper = GKDScraper(),
         weather: WeatherProvider? = nil,
         useLiveCatalogue: Bool = true) {
        self.scraper = scraper
        self.weather = weather
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

        // Prefer scraped stations (they carry real detail URLs); fall back to
        // seed entries the scrape didn't cover so the library is never empty.
        guard !scraped.isEmpty else { return seed }
        var byKey: [String: MeasurementStation] = [:]
        for station in seed { byKey[matchKey(station)] = station }
        for station in scraped { byKey[matchKey(station)] = station }
        return byKey.values.sorted { $0.waterBodyName < $1.waterBodyName }
    }

    private func scrapedStations(category: GKDEndpoints.Category,
                                 type: WaterBodyType) async throws -> [MeasurementStation] {
        let rows = try await scraper.overview(category: category)
        return rows.compactMap { row in
            guard let detail = row.detailURL else { return nil }
            let external = GKDBayernDataSource.externalID(from: detail) ?? GKDBayernDataSource.slug(detail.absoluteString)
            return MeasurementStation(
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
                    : [.waterTemperature],
                detailURL: detail
            )
        }
    }

    // MARK: - Conditions

    func fetchCurrentConditions(for station: MeasurementStation) async throws -> StationConditions {
        var latest: [MeasurementParameter: Measurement] = [:]
        try await withThrowingTaskGroup(of: (MeasurementParameter, Measurement?).self) { group in
            for parameter in station.availableParameters {
                group.addTask { (parameter, try? await scraper.latestValue(for: station, parameter: parameter)) }
            }
            for try await (parameter, measurement) in group {
                if let measurement { latest[parameter] = measurement }
            }
        }

        let snapshot = await weather?.currentWeather(at: station.coordinate)
        return StationConditions(stationID: station.id, latest: latest, weather: snapshot)
    }

    func fetchTimeSeries(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         range: TimeRange) async throws -> TimeSeries {
        guard station.availableParameters.contains(parameter) else {
            throw DataSourceError.unsupportedParameter(parameter)
        }
        return try await scraper.timeSeries(for: station, parameter: parameter, range: range)
    }

    // MARK: - Matching / id helpers

    /// Normalised key used to reconcile seed and scraped entries.
    private func matchKey(_ station: MeasurementStation) -> String {
        GKDBayernDataSource.slug("\(station.waterBodyName)-\(station.name)")
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
