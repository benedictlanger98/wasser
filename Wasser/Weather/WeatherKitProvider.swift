import Foundation
import CoreLocation
#if canImport(WeatherKit)
import WeatherKit
#endif

/// `WeatherProvider` backed by Apple's WeatherKit.
///
/// Requires the WeatherKit capability/entitlement on the App ID and a paid
/// developer account at runtime; it compiles without one. Wrapped in
/// `canImport` so the project still builds on platforms/toolchains where
/// WeatherKit is absent — it then returns nil like `NoWeatherProvider`.
struct WeatherKitProvider: WeatherProvider {

    func currentWeather(at coordinate: CLLocationCoordinate2D) async -> WeatherSnapshot? {
        #if canImport(WeatherKit)
        guard #available(iOS 16.0, *) else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let today = weather.dailyForecast.first
            let alerts = (weather.weatherAlerts ?? []).map { alert in
                WeatherAlertInfo(
                    summary: alert.summary,
                    severity: Self.severityLabel(alert.severity),
                    region: alert.region,
                    symbolName: "exclamationmark.triangle.fill")
            }

            return WeatherSnapshot(
                temperature: current.temperature.converted(to: .celsius).value,
                apparentTemperature: current.apparentTemperature.converted(to: .celsius).value,
                conditionDescription: current.condition.description,
                symbolName: current.symbolName,
                humidity: current.humidity,
                windSpeed: current.wind.speed.converted(to: .kilometersPerHour).value,
                windGust: current.wind.gust?.converted(to: .kilometersPerHour).value,
                windDirectionDegrees: current.wind.direction.converted(to: .degrees).value,
                windCompass: current.wind.compassDirection.abbreviation,
                uvIndex: current.uvIndex.value,
                uvCategory: current.uvIndex.category.description,
                sunrise: today?.sun.sunrise,
                sunset: today?.sun.sunset,
                alerts: alerts,
                observedAt: current.date
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    #if canImport(WeatherKit)
    /// Maps WeatherKit's severity to a short German label for the banner.
    @available(iOS 16.0, *)
    private static func severityLabel(_ severity: WeatherSeverity) -> String {
        switch severity {
        case .extreme:  return "Extrem"
        case .severe:   return "Erheblich"
        case .moderate: return "Mäßig"
        case .minor:    return "Gering"
        case .unknown:  return "Warnung"
        @unknown default: return "Warnung"
        }
    }
    #endif
}
