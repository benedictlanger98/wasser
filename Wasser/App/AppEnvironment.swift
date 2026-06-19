import Foundation

/// Composition root. Wires concrete data sources and the weather provider into
/// the registry and repository. This is the one place that decides *which*
/// providers the app ships with — adding a new `WaterDataSource` is a one-line
/// change here.
@MainActor
enum AppEnvironment {

    /// Production configuration: live GKD Bayern scraping + WeatherKit.
    static func live() -> WaterRepository {
        let gkd = GKDBayernDataSource(useLiveCatalogue: true)
        let registry = DataSourceRegistry(sources: [gkd])
        return WaterRepository(registry: registry, weatherProvider: WeatherKitProvider())
    }

    /// Network-free configuration for previews, screenshots and UI tests.
    static func preview() -> WaterRepository {
        let registry = DataSourceRegistry(sources: [MockWaterDataSource()])
        return WaterRepository(registry: registry, weatherProvider: MockWeatherProvider())
    }
}
