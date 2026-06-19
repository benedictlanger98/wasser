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

            // Hourly line: the 15-min series for the current day only. Left
            // empty (card hidden) when no real series exists — e.g. lakes that
            // are read manually rather than logged continuously. No synthetic
            // placeholder.
            let todayPoints = (series?.points ?? []).filter { Fmt.isToday($0.timestamp) }
            let hourly = todayPoints.count >= 2 ? todayPoints : []

            // 10-day trend from real daily aggregates (today first). Only days
            // within the last ~11 days count, so manually-read stations whose
            // newest "daily" value is months old show nothing rather than a
            // misleadingly recent-looking trend (card hidden when empty).
            let recentCutoff = Date().addingTimeInterval(-11 * 86_400)
            let daily: [DayTrend] = aggregates
                .filter { $0.date >= recentCutoff }
                .map { DayTrend(date: $0.date, low: $0.low, high: $0.high) }

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
