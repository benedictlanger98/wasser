import Foundation

/// Drives HTTP requests against GKD Bayern and hands raw payloads to
/// `GKDParser`. Holding the transport + endpoint + parsing wiring in one place
/// keeps `GKDBayernDataSource` focused on mapping to the app's domain types,
/// and lets the whole scraping strategy be replaced (e.g. with a confirmed
/// JSON API) without touching the data-source surface.
struct GKDScraper: Sendable {
    let client: HTTPClient

    init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    /// Scrapes the overview table for a category, returning one row per station.
    func overview(category: GKDEndpoints.Category,
                  parameter: MeasurementParameter = .waterTemperature) async throws -> [GKDParser.OverviewRow] {
        let url = GKDEndpoints.overviewTable(category: category, parameter: parameter)
        let html = try await client.getText(url)
        let rows = GKDParser.parseOverviewTable(html: html, baseURL: url)
        guard !rows.isEmpty else {
            throw DataSourceError.parsing("No station rows found in \(category.rawValue) overview")
        }
        return rows
    }

    /// Loads the latest value for a single parameter at a station from its
    /// recent (15-min) table. Works for any parameter at the location (water
    /// level / discharge reuse the same station number, slug swapped).
    func latestValue(for station: MeasurementStation,
                     parameter: MeasurementParameter) async throws -> Measurement? {
        let points = await recentSeries(for: station, parameter: parameter)
        // The table is newest-first, but pick by max timestamp to be safe.
        return points.max { $0.timestamp < $1.timestamp }
    }

    /// Recent 15-minute series (≈7 days) from `.../messwerte/tabelle`. Returns
    /// an empty array rather than throwing so a missing parameter (e.g. no level
    /// gauge at a lake buoy) degrades gracefully.
    func recentSeries(for station: MeasurementStation,
                      parameter: MeasurementParameter) async -> [Measurement] {
        guard let url = GKDEndpoints.dataURL(for: station, parameter: parameter, tab: .recentTable),
              let html = try? await client.getText(url) else { return [] }
        return GKDParser.parseMeasurementTable(html: html, parameter: parameter)
    }

    /// Daily mean/max/min aggregates from `.../jahreswerte` (the "Jahresgrafik"
    /// table), newest first.
    func dailyAggregates(for station: MeasurementStation,
                         parameter: MeasurementParameter) async -> [DailyAggregate] {
        guard let url = GKDEndpoints.dataURL(for: station, parameter: parameter, tab: .yearTable),
              let html = try? await client.getText(url) else { return [] }
        return GKDParser.parseDailyTable(html: html)
    }

    /// Fetches the station's Stammdaten page and pulls Nordwert / Ostwert from
    /// it. Returns nil on transport failure, missing URL, or unparseable
    /// content — coordinate resolution is best-effort.
    func stammdaten(for station: MeasurementStation) async -> GKDParser.StammdatenLocation? {
        guard let url = GKDEndpoints.stammdataURL(for: station),
              let html = try? await client.getText(url) else { return nil }
        return GKDParser.parseStammdaten(html: html)
    }

    /// A time series for a parameter — the recent 15-min table.
    func timeSeries(for station: MeasurementStation,
                    parameter: MeasurementParameter,
                    range: TimeRange) async throws -> TimeSeries {
        let points = await recentSeries(for: station, parameter: parameter)
        return TimeSeries(parameter: parameter, points: points)
    }
}
