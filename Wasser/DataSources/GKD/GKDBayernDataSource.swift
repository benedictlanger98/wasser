import CoreLocation
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

/// In-memory cache of full daily-aggregate series, keyed by station + parameter.
/// The `jahreswerte/tabelle` page returns multiple years of daily rows so
/// fetching and parsing it is expensive. The same series is needed twice
/// per station load (7-day trend + annual mean), so without caching we'd
/// hit GKD twice for the same payload. Entries are kept for a short TTL —
/// daily aggregates don't change inside a single foreground session.
actor GKDDailyAggregatesCache {
    private struct Entry {
        let aggregates: [DailyAggregate]
        let fetchedAt: Date
    }
    private var entries: [String: Entry] = [:]
    /// Daily aggregates only roll once per day; refreshing on app foreground
    /// (which also clears `WaterRepository.conditionsCache`) is plenty.
    private let ttl: TimeInterval = 60 * 60 * 6

    private func key(_ stationID: String, _ parameter: MeasurementParameter) -> String {
        "\(stationID).\(parameter.rawValue)"
    }

    func aggregates(stationID: String, parameter: MeasurementParameter) -> [DailyAggregate]? {
        guard let entry = entries[key(stationID, parameter)],
              Date().timeIntervalSince(entry.fetchedAt) < ttl else { return nil }
        return entry.aggregates
    }

    func set(_ aggregates: [DailyAggregate], stationID: String, parameter: MeasurementParameter) {
        entries[key(stationID, parameter)] = Entry(aggregates: aggregates, fetchedAt: Date())
    }
}

/// Persistent (UserDefaults-backed) cache of resolved station coordinates
/// keyed by externalID (Messstellennummer). Coordinates are expensive to
/// resolve — each one is an extra HTTP fetch of the station's Stammdaten
/// page — and they essentially never change for a given station, so caching
/// across launches keeps weather lookups instant after first use.
actor GKDCoordinateCache {
    private static let key = "gkd_station_coordinates_v1"
    private var inMemory: [String: CLLocationCoordinate2D]

    init() {
        var initial: [String: CLLocationCoordinate2D] = [:]
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let dict = try? JSONDecoder().decode([String: [Double]].self, from: data) {
            for (id, pair) in dict where pair.count == 2 {
                initial[id] = CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
            }
        }
        self.inMemory = initial
    }

    func coordinate(for externalID: String) -> CLLocationCoordinate2D? { inMemory[externalID] }

    func set(_ coord: CLLocationCoordinate2D, for externalID: String) {
        inMemory[externalID] = coord
        let dict = inMemory.mapValues { [$0.latitude, $0.longitude] }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
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
    /// Persistent cache of station coordinates resolved from Stammdaten pages.
    private let coordinateCache = GKDCoordinateCache()
    /// Session cache of daily aggregates so the 7-day trend and the annual
    /// mean don't double-fetch the same `jahreswerte/tabelle` page.
    private let dailyCache = GKDDailyAggregatesCache()

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

        // Scrape succeeded: return only the stations GKD actually serves. The
        // seed catalogue is a pure offline fallback (used when the scrape yields
        // nothing) — merging its uncovered entries here would surface lakes GKD
        // doesn't measure (e.g. Walchensee) as permanent 0° cards.
        guard !scraped.isEmpty else { return seed }
        return scraped.sorted { $0.waterBodyName.localizedCompare($1.waterBodyName) == .orderedAscending }
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
        // Reuse the cached full-year series when present (same scrape feeds
        // both the 7-day trend and the annual mean → otherwise we'd hit
        // `jahreswerte/tabelle` twice for the same payload).
        let all: [DailyAggregate]
        if let cached = await dailyCache.aggregates(stationID: station.id, parameter: parameter) {
            all = cached
        } else {
            let fetched = await scraper.dailyAggregates(for: station, parameter: parameter)
            await dailyCache.set(fetched, stationID: station.id, parameter: parameter)
            all = fetched
        }
        return Array(all.sorted { $0.date > $1.date }.prefix(days))   // newest first
    }

    // MARK: - Matching / id helpers

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

    // MARK: - Coordinate resolution

    /// Lazily resolves a station's coordinate. The overview scrape stores
    /// `(0, 0)` because GKD's listing pages carry no location — this method
    /// fetches and converts the Stammdaten Nordwert/Ostwert on first use, then
    /// reuses the cached value forever after.
    func resolveCoordinate(for station: MeasurementStation) async -> CLLocationCoordinate2D {
        // Trust any coordinate already on the station (seed catalogue entries).
        if abs(station.latitude) > 0.0001 || abs(station.longitude) > 0.0001 {
            return station.coordinate
        }
        if let cached = await coordinateCache.coordinate(for: station.externalID) {
            return cached
        }
        guard let raw = await scraper.stammdaten(for: station),
              let coord = GKDProjection.wgs84(nordwert: raw.nordwert, ostwert: raw.ostwert) else {
            return station.coordinate
        }
        await coordinateCache.set(coord, for: station.externalID)
        return coord
    }
}
