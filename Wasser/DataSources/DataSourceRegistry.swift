import Foundation

/// Aggregates one or more `WaterDataSource`s and routes requests to the source
/// that owns a given station. This is the single seam the rest of the app talks
/// to, so adding a provider never ripples beyond registration.
actor DataSourceRegistry {
    private var sources: [String: WaterDataSource] = [:]

    init(sources: [WaterDataSource] = []) {
        for source in sources { self.sources[source.id] = source }
    }

    func register(_ source: WaterDataSource) {
        sources[source.id] = source
    }

    var allSources: [WaterDataSource] {
        Array(sources.values)
    }

    func source(for station: MeasurementStation) throws -> WaterDataSource {
        guard let source = sources[station.dataSourceID] else {
            throw DataSourceError.notFound
        }
        return source
    }

    /// Stations from every registered source, merged. Failures in one source do
    /// not prevent others from contributing.
    func fetchAllStations() async -> [MeasurementStation] {
        await withTaskGroup(of: [MeasurementStation].self) { group in
            for source in sources.values {
                group.addTask {
                    (try? await source.fetchStations()) ?? []
                }
            }
            var merged: [MeasurementStation] = []
            for await stations in group { merged.append(contentsOf: stations) }
            return merged
        }
    }

    func fetchCurrentConditions(for station: MeasurementStation) async throws -> StationConditions {
        try await source(for: station).fetchCurrentConditions(for: station)
    }

    func fetchTimeSeries(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         range: TimeRange) async throws -> TimeSeries {
        try await source(for: station).fetchTimeSeries(for: station, parameter: parameter, range: range)
    }
}
