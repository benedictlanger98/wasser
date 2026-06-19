import Foundation

/// Derives the parts of the detail screen that GKD's hydrology feed and
/// WeatherKit don't provide directly — a swimming-comfort hint, the water
/// temperature trend, marine extras and river flow.
///
/// Comfort and trend are honest functions of the *real* measured water
/// temperature, not fabricated quality data. Marine/flow remain placeholder
/// derivations (no marine source wired in yet). Each is isolated here so a real
/// provider can replace one function without touching the view model or views.
enum ConditionEnrichment {

    /// Swimming-comfort hint derived from the measured water temperature.
    static func comfort(forWaterTemperature t: Double) -> SwimComfort {
        switch t {
        case ..<10:
            return SwimComfort(rating: "Sehr kalt", note: "Nur für Abgehärtete", symbolName: "snowflake")
        case 10..<16:
            return SwimComfort(rating: "Kalt", note: "Kurzes Bad, schnell auskühlend", symbolName: "thermometer.low")
        case 16..<20:
            return SwimComfort(rating: "Erfrischend", note: "Angenehm bei warmem Wetter", symbolName: "drop")
        case 20..<23:
            return SwimComfort(rating: "Angenehm", note: "Ideale Badetemperatur", symbolName: "figure.pool.swim")
        case 23..<26:
            return SwimComfort(rating: "Warm", note: "Sehr angenehm zum Baden", symbolName: "sun.max")
        default:
            return SwimComfort(rating: "Sehr warm", note: "Badewannentemperatur", symbolName: "thermometer.high")
        }
    }

    /// Direction of the recent water-temperature change. Compares the last
    /// reading against the average of the few before it (same logic as
    /// `TimeSeries.trend`), with a 0.2 °C dead-band to ignore sensor jitter.
    static func trend(from series: [Measurement]) -> WaterTrend {
        guard series.count >= 2, let current = series.last?.value else { return .steady }
        let tail = series.suffix(5).dropLast()
        guard !tail.isEmpty else { return .steady }
        let avg = tail.map(\.value).reduce(0, +) / Double(tail.count)
        let delta = current - avg
        if delta > 0.2 { return .rising }
        if delta < -0.2 { return .falling }
        return .steady
    }

    static func marine(for station: MeasurementStation) -> MarineInfo? {
        guard station.waterBodyType == .sea else { return nil }
        return MarineInfo(waveHeightMeters: 0.8, wavePeriodSeconds: 6,
                          nextHighTide: "14:32", nextLowTide: "20:51")
    }

    /// River flow. Uses GKD discharge (m³/s) as a magnitude hint when present,
    /// otherwise a modest default. Direction is a placeholder.
    static func flow(for station: MeasurementStation, discharge: Measurement?) -> FlowInfo? {
        guard station.waterBodyType == .river else { return nil }
        let speed: Double
        if let q = discharge?.value {
            // Rough surface-velocity proxy; replaced once a real source exists.
            speed = min(2.5, max(0.4, q / 60.0))
        } else {
            speed = 1.2
        }
        return FlowInfo(speedMetersPerSecond: speed, direction: "Nord")
    }
}
