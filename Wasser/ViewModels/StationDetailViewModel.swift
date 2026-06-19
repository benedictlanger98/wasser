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
            // Request a generous window (today + buffer for gaps/weekends) and
            // keep the 10 most recent days below, so the trend reliably fills
            // all ten rows rather than dropping to ~7 on sparse days.
            async let dailyAggregates = try? repository.dailyTrend(for: station,
                                                                   parameter: .waterTemperature,
                                                                   days: 16)
            // Whole-year aggregates for the ± annual-mean readouts on the
            // Wasserstand / Abfluss cards (only fetched where the station
            // actually reports the parameter).
            async let levelYear = annualMean(.waterLevel)
            async let dischargeYear = annualMean(.discharge)

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

            // 10-day trend from real daily aggregates (newest first). Show the
            // card only when the data is recent (newest within ~14 days) so
            // manually-read stations with months-old "daily" values render
            // nothing rather than a misleadingly recent-looking trend; when it
            // is recent, take the 10 most recent days regardless of small gaps.
            let sorted = aggregates.sorted { $0.date > $1.date }
            let freshEnough = sorted.first.map {
                $0.date >= Date().addingTimeInterval(-14 * 86_400)
            } ?? false
            let daily: [DayTrend] = freshEnough
                ? sorted.prefix(10).map { DayTrend(date: $0.date, low: $0.low, high: $0.high) }
                : []

            conditions = LocationConditions(
                station: station,
                waterTemperature: waterTemp,
                hourly: hourly,
                daily: daily,
                weather: current.weather,
                comfort: ConditionEnrichment.comfort(forWaterTemperature: waterTemp),
                trend: ConditionEnrichment.trend(from: series?.points ?? []),
                marine: ConditionEnrichment.marine(for: station),
                flow: ConditionEnrichment.flow(for: station, discharge: current.discharge),
                waterLevel: current.waterLevel,
                waterLevelAnnualMean: await levelYear,
                discharge: current.discharge,
                dischargeAnnualMean: await dischargeYear
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Mean of the daily means over the available year for `parameter`, used as
    /// the baseline for the ± deviation readouts. Returns nil when the station
    /// doesn't report the parameter or no yearly data is available.
    private func annualMean(_ parameter: MeasurementParameter) async -> Double? {
        guard station.availableParameters.contains(parameter) else { return nil }
        guard let aggregates = try? await repository.dailyTrend(for: station,
                                                                parameter: parameter,
                                                                days: 366),
              !aggregates.isEmpty else { return nil }
        return aggregates.map(\.mean).reduce(0, +) / Double(aggregates.count)
    }
}
