import Foundation

/// A severe-weather warning for the station's region (WeatherKit `WeatherAlert`).
///
/// Decoupled from WeatherKit's type so the rest of the app depends only on this
/// value type and any provider can supply warnings.
struct WeatherAlertInfo: Codable, Hashable, Sendable, Identifiable {
    let summary: String          // e.g. "Amtliche Hitzewarnung"
    let severity: String         // localized severity, e.g. "Erheblich"
    let region: String?          // affected area, if given
    let symbolName: String       // SF Symbol for the banner

    var id: String { summary + (region ?? "") }
}

/// A lightweight, source-agnostic weather snapshot for a station's location.
///
/// Deliberately decoupled from Apple's WeatherKit types so the rest of the app
/// (and any non-WeatherKit provider) depends only on this value type.
struct WeatherSnapshot: Codable, Hashable, Sendable {
    let temperature: Double           // °C (air)
    let apparentTemperature: Double?  // °C, "feels like"
    let conditionDescription: String
    /// SF Symbol describing the condition (WeatherKit provides one directly).
    let symbolName: String
    let humidity: Double?             // 0...1
    let windSpeed: Double?            // km/h
    let windGust: Double?             // km/h
    let windDirectionDegrees: Double? // meteorological, 0 = from north
    let windCompass: String?          // localized short compass, e.g. "NW"
    let uvIndex: Int?
    let uvCategory: String?           // e.g. "Hoch"
    let sunrise: Date?
    let sunset: Date?
    /// Active severe-weather warnings for the region (may be empty).
    let alerts: [WeatherAlertInfo]
    let observedAt: Date

    var temperatureFormatted: String { String(format: "%.0f°", temperature) }
}
