import Foundation

/// A snapshot of the most recent value for each parameter a station reports,
/// plus optional co-located weather. This is what the detail screen renders at
/// the top, before the user drills into a specific time series.
struct StationConditions: Codable, Hashable, Sendable {
    let stationID: String
    /// Latest measurement per parameter.
    let latest: [MeasurementParameter: Measurement]
    let weather: WeatherSnapshot?
    let fetchedAt: Date

    init(stationID: String,
         latest: [MeasurementParameter: Measurement],
         weather: WeatherSnapshot? = nil,
         fetchedAt: Date = Date()) {
        self.stationID = stationID
        self.latest = latest
        self.weather = weather
        self.fetchedAt = fetchedAt
    }

    var waterTemperature: Measurement? { latest[.waterTemperature] }
    var waterLevel: Measurement? { latest[.waterLevel] }
    var discharge: Measurement? { latest[.discharge] }

    /// Most recent timestamp across all parameters, useful for "last updated".
    var observationTime: Date? {
        latest.values.map(\.timestamp).max()
    }
}
