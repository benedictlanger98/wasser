import Foundation

/// Deterministic, network-free data source used for SwiftUI previews, tests and
/// offline development. Reuses the real Bavarian seed catalogue so previews look
/// representative, and synthesises plausible seasonal time series.
struct MockWaterDataSource: WaterDataSource {
    let id = "mock"
    let displayName = "Beispieldaten"

    func fetchStations() async throws -> [MeasurementStation] {
        GKDStationCatalog.stations().map { station in
            // Re-home seed stations onto the mock source so routing works.
            MeasurementStation(
                id: MeasurementStation.makeID(dataSourceID: id, externalID: station.externalID),
                externalID: station.externalID,
                dataSourceID: id,
                name: station.name,
                waterBodyName: station.waterBodyName,
                waterBodyType: station.waterBodyType,
                region: station.region,
                latitude: station.latitude,
                longitude: station.longitude,
                elevation: station.elevation,
                operatorName: station.operatorName,
                availableParameters: station.availableParameters,
                detailURL: station.detailURL
            )
        }
    }

    func fetchCurrentConditions(for station: MeasurementStation) async throws -> StationConditions {
        var latest: [MeasurementParameter: Measurement] = [:]
        for parameter in station.availableParameters {
            latest[parameter] = synthesise(parameter, for: station, range: .day).last
        }
        return StationConditions(stationID: station.id, latest: latest, weather: nil)
    }

    func fetchTimeSeries(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         range: TimeRange) async throws -> TimeSeries {
        TimeSeries(parameter: parameter, points: synthesise(parameter, for: station, range: range))
    }

    func fetchDailyTrend(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         days: Int) async throws -> [DailyAggregate] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .current
        let today = cal.startOfDay(for: Date())
        let base = baseValue(parameter, station: station)
        let amp = dailyAmplitude(parameter)
        let seed = Double(abs(station.id.hashValue % 100)) / 100.0
        return (0..<max(0, days)).map { i in
            let date = cal.date(byAdding: .day, value: -i, to: today) ?? today
            let wobble = sin(Double(i) * 0.6 + seed * 6) * amp
            let mean = max(0, base + wobble)
            return DailyAggregate(date: date, mean: mean,
                                  high: mean + amp, low: max(0, mean - amp))
        }
    }

    // MARK: - Synthesis

    private func synthesise(_ parameter: MeasurementParameter,
                            for station: MeasurementStation,
                            range: TimeRange) -> [Measurement] {
        let now = Date()
        let sampleCount = 48
        let step = range.interval / Double(sampleCount)
        let base = baseValue(parameter, station: station)
        let seed = Double(abs(station.id.hashValue % 100)) / 100.0

        return (0..<sampleCount).map { i in
            let t = now.addingTimeInterval(-Double(sampleCount - i) * step)
            let daily = sin(Double(i) / Double(sampleCount) * 2 * .pi + seed) * dailyAmplitude(parameter)
            let noise = sin(Double(i) * 1.3 + seed * 6) * dailyAmplitude(parameter) * 0.2
            return Measurement(parameter: parameter, timestamp: t, value: max(0, base + daily + noise))
        }
    }

    private func baseValue(_ parameter: MeasurementParameter, station: MeasurementStation) -> Double {
        let dayOfYear = Double(Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 180)
        let seasonal = sin((dayOfYear - 80) * .pi / 182.5)
        switch parameter {
        case .waterTemperature:
            return (station.waterBodyType == .lake ? 13 : 11) + seasonal * 8
        case .airTemperature:
            return 14 + seasonal * 12
        case .waterLevel:
            return 120 + seasonal * 30
        case .discharge:
            return 80 + seasonal * 40
        case .precipitation:
            return 1.5
        }
    }

    private func dailyAmplitude(_ parameter: MeasurementParameter) -> Double {
        switch parameter {
        case .waterTemperature, .airTemperature: return 1.5
        case .waterLevel:                          return 8
        case .discharge:                           return 12
        case .precipitation:                       return 1
        }
    }
}
