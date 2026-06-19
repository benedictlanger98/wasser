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
/// WeatherKit is absent — it then behaves like `NoWeatherProvider`.
struct WeatherKitProvider: WeatherProvider {

    func currentWeather(at coordinate: CLLocationCoordinate2D) async -> WeatherSnapshot? {
        #if canImport(WeatherKit)
        guard #available(iOS 16.0, *) else { return nil }
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let current = try await WeatherService.shared.weather(for: location, including: .current)
            return WeatherSnapshot(
                temperature: current.temperature.converted(to: .celsius).value,
                apparentTemperature: current.apparentTemperature.converted(to: .celsius).value,
                conditionDescription: current.condition.description,
                symbolName: current.symbolName,
                humidity: current.humidity,
                windSpeed: current.wind.speed.converted(to: .kilometersPerHour).value,
                uvIndex: current.uvIndex.value,
                observedAt: current.date
            )
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }
}
