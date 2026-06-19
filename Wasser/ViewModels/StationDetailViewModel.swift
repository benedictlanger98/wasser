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
            async let dailyAggregates = try? repository.dailyTrend(for: station,
                                                                   parameter: .waterTemperature,
                                                                   days: 10)
            let current = try await snapshot
            let series = await hourlySeries
            let aggregates = (await dailyAggregates) ?? []

            let waterTemp = current.waterTemperature?.value
                ?? series?.latest?.value
                ?? 0

            // Hourly line: the last ~36h of the 15-min series; synthesise when a
            // real series is unavailable (e.g. lakes, which are manually read).
            let cutoff = Date().addingTimeInterval(-36 * 3600)
            let recent = (series?.points ?? []).filter { $0.timestamp >= cutoff }
            let hourly = recent.isEmpty
                ? ConditionEnrichment.syntheticHourly(base: waterTemp)
                : recent

            // 10-day trend from real daily aggregates (today first), else synthetic.
            let daily: [DayTrend] = aggregates.isEmpty
                ? ConditionEnrichment.dailyTrend(base: waterTemp)
                : aggregates.map { agg in
                    DayTrend(label: Fmt.isToday(agg.date) ? "Heute" : Fmt.weekdayShort(agg.date),
                             low: agg.low, high: agg.high)
                }

            conditions = LocationConditions(
                station: station,
                waterTemperature: waterTemp,
                hourly: hourly,
                daily: daily,
                weather: current.weather,
                quality: ConditionEnrichment.quality(for: station, waterTemperature: waterTemp),
                marine: ConditionEnrichment.marine(for: station),
                flow: ConditionEnrichment.flow(for: station, discharge: current.discharge),
                waterLevel: current.waterLevel,
                discharge: current.discharge
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
