import Foundation
import CoreLocation

/// Source-agnostic weather lookup. The app depends only on this protocol and on
/// `WeatherSnapshot`, so WeatherKit can be swapped for another provider (or
/// mocked in previews) without touching data sources or UI.
protocol WeatherProvider: Sendable {
    func currentWeather(at coordinate: CLLocationCoordinate2D) async -> WeatherSnapshot?
}

/// A provider that returns nothing — the default when weather is disabled or
/// unavailable, so call sites never need to special-case a missing provider.
struct NoWeatherProvider: WeatherProvider {
    func currentWeather(at coordinate: CLLocationCoordinate2D) async -> WeatherSnapshot? { nil }
}
