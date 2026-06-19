import Foundation

/// Loads and assembles all data the detail screen renders for a single station:
/// current + hourly water temperature from the data source, co-located weather,
/// and the derived enrichment cards.
@MainActor
final class StationDetailViewModel: ObservableObject {
    let station: MeasurementStation

    @Published var conditions: LocationConditions?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: WaterRepository

    init(station: MeasurementStation, repository: WaterRepository) {
        self.station = station
        self.repository = repository
    }

    func load() async {
        guard conditions == nil else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            async let snapshot = repository.conditions(for: station)
            async let hourlySeries = try? repository.timeSeries(for: station,
                                                                parameter: .waterTemperature,
                                                                range: .day)
            let current = try await snapshot
            let series = await hourlySeries

            let waterTemp = current.waterTemperature?.value
                ?? series?.latest?.value
                ?? 0
            let hourly = (series?.points.isEmpty == false)
                ? Array(series!.points.suffix(24))
                : ConditionEnrichment.syntheticHourly(base: waterTemp)

            conditions = LocationConditions(
                station: station,
                waterTemperature: waterTemp,
                hourly: hourly,
                daily: ConditionEnrichment.dailyTrend(base: waterTemp),
                weather: current.weather,
                quality: ConditionEnrichment.quality(for: station, waterTemperature: waterTemp),
                marine: ConditionEnrichment.marine(for: station),
                flow: ConditionEnrichment.flow(for: station, discharge: current.discharge)
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
