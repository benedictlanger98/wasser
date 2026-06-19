import Foundation
import CoreLocation

/// Deterministic weather for previews, screenshots and offline development.
/// Mirrors the kind of values WeatherKit returns so the UI renders fully.
struct MockWeatherProvider: WeatherProvider {
    func currentWeather(at coordinate: CLLocationCoordinate2D) async -> WeatherSnapshot? {
        let calendar = Calendar.current
        let now = Date()
        let sunrise = calendar.date(bySettingHour: 5, minute: 42, second: 0, of: now)
        let sunset = calendar.date(bySettingHour: 21, minute: 18, second: 0, of: now)
        return WeatherSnapshot(
            temperature: 24,
            apparentTemperature: 25,
            conditionDescription: "Klar",
            symbolName: "sun.max.fill",
            humidity: 0.55,
            windSpeed: 8,
            windGust: 14,
            windDirectionDegrees: 315,
            windCompass: "NW",
            uvIndex: 6,
            uvCategory: "Hoch",
            sunrise: sunrise,
            sunset: sunset,
            alerts: [
                WeatherAlertInfo(summary: "Amtliche Warnung vor Hitze",
                                 severity: "Erheblich",
                                 region: "Oberbayern",
                                 symbolName: "exclamationmark.triangle.fill")
            ],
            observedAt: now
        )
    }
}
