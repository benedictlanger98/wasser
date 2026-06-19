import Foundation

/// A lightweight, source-agnostic weather snapshot for a station's location.
///
/// Deliberately decoupled from Apple's WeatherKit types so the rest of the app
/// (and any non-WeatherKit provider) depends only on this value type.
struct WeatherSnapshot: Codable, Hashable, Sendable {
    let temperature: Double          // °C
    let apparentTemperature: Double? // °C, "feels like"
    let conditionDescription: String
    /// SF Symbol describing the condition (WeatherKit provides one directly).
    let symbolName: String
    let humidity: Double?            // 0...1
    let windSpeed: Double?           // km/h
    let uvIndex: Int?
    let observedAt: Date

    var temperatureFormatted: String {
        String(format: "%.0f°", temperature)
    }
}
