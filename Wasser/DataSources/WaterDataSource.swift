import Foundation

/// Errors any data source can surface, kept transport-agnostic.
enum DataSourceError: LocalizedError, Sendable {
    case transport(String)
    case http(status: Int, url: URL)
    case decoding(String)
    case parsing(String)
    case notFound
    case unsupportedParameter(MeasurementParameter)

    var errorDescription: String? {
        switch self {
        case .transport(let m):       return "Verbindungsfehler: \(m)"
        case .http(let status, _):    return "Serverfehler (HTTP \(status))."
        case .decoding(let m):        return "Daten konnten nicht gelesen werden: \(m)"
        case .parsing(let m):         return "Unerwartetes Datenformat: \(m)"
        case .notFound:               return "Messstelle nicht gefunden."
        case .unsupportedParameter(let p): return "Parameter \(p.displayName) wird hier nicht angeboten."
        }
    }
}

/// The central abstraction that makes the app adaptable to new providers.
///
/// A `WaterDataSource` knows how to enumerate its measuring stations and how to
/// load current values and historical time series for them. GKD Bayern is the
/// first implementation; adding e.g. a Swiss or Austrian provider is just
/// another conformer registered with the `DataSourceRegistry` — no UI or
/// repository changes required.
protocol WaterDataSource: Sendable {
    /// Stable identifier, embedded into station IDs (e.g. "gkd-bayern").
    var id: String { get }
    /// Human-readable name shown in attribution / settings.
    var displayName: String { get }

    /// The full catalogue of stations this source offers. Implementations may
    /// serve this from a bundled seed and refresh it from the network.
    func fetchStations() async throws -> [MeasurementStation]

    /// Latest value for each parameter the station reports.
    func fetchCurrentConditions(for station: MeasurementStation) async throws -> StationConditions

    /// Historical series for one parameter over the given range.
    func fetchTimeSeries(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         range: TimeRange) async throws -> TimeSeries

    /// Recent daily aggregates (mean/max/min), newest first, for the multi-day
    /// trend. Optional: sources without daily data return an empty array.
    func fetchDailyTrend(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         days: Int) async throws -> [DailyAggregate]
}

extension WaterDataSource {
    func fetchDailyTrend(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         days: Int) async throws -> [DailyAggregate] { [] }
}
