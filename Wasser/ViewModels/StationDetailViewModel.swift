import Foundation

/// Drives the station detail screen: loads current conditions and the selected
/// parameter's time series, reacting to parameter/range changes.
@MainActor
final class StationDetailViewModel: ObservableObject {
    let station: MeasurementStation

    @Published var conditions: StationConditions?
    @Published var series: TimeSeries?
    @Published var selectedParameter: MeasurementParameter
    @Published var selectedRange: TimeRange = .week
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: WaterRepository

    init(station: MeasurementStation, repository: WaterRepository) {
        self.station = station
        self.repository = repository
        self.selectedParameter = station.availableParameters.first ?? .waterTemperature
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            async let conditions = repository.conditions(for: station)
            async let series = repository.timeSeries(for: station,
                                                     parameter: selectedParameter,
                                                     range: selectedRange)
            self.conditions = try await conditions
            self.series = try await series
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func reloadSeries() async {
        do {
            series = try await repository.timeSeries(for: station,
                                                     parameter: selectedParameter,
                                                     range: selectedRange)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
