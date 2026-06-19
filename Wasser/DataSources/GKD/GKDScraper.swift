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
    /// "messwerte" page.
    func latestValue(for station: MeasurementStation,
                     parameter: MeasurementParameter) async throws -> Measurement? {
        guard let url = GKDEndpoints.messwerte(for: station, parameter: parameter) else {
            return nil
        }
        let html = try await client.getText(url)
        // Verified live 2026-06: the messwerte table is ordered newest-first,
        // so pick the row with the maximum timestamp rather than the last row.
        return GKDParser.parseMeasurementTable(html: html, parameter: parameter)
            .max { $0.timestamp < $1.timestamp }
    }

    /// Loads a time series for a parameter, preferring the CSV download and
    /// falling back to scraping the rendered table.
    func timeSeries(for station: MeasurementStation,
                    parameter: MeasurementParameter,
                    range: TimeRange) async throws -> TimeSeries {
        if let downloadURL = GKDEndpoints.download(for: station, parameter: parameter, range: range),
           let csv = try? await client.getText(downloadURL) {
            let points = GKDParser.parseCSV(csv, parameter: parameter)
            if !points.isEmpty { return TimeSeries(parameter: parameter, points: points) }
        }

        guard let url = GKDEndpoints.messwerte(for: station, parameter: parameter) else {
            throw DataSourceError.notFound
        }
        let html = try await client.getText(url)
        let points = GKDParser.parseMeasurementTable(html: html, parameter: parameter)
        return TimeSeries(parameter: parameter, points: points)
    }
}
