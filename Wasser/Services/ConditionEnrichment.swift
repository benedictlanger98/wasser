import Foundation

/// Derives the parts of the detail screen that GKD's hydrology feed and
/// WeatherKit don't provide directly — bathing-water quality, clarity, marine
/// extras, flow direction, and a multi-day trend.
///
/// These derivations mirror the design mock and are clearly placeholder logic:
/// they are deterministic functions of water-body type and temperature so the
/// UI is fully populated. Each is isolated here so a real provider (e.g. LGL
/// Badegewässer for quality, a marine API for waves/tides) can replace one
/// function without touching the view model or views.
enum ConditionEnrichment {

    static func quality(for station: MeasurementStation, waterTemperature: Double) -> WaterQualityInfo {
        switch station.waterBodyType {
        case .lake:
            return WaterQualityInfo(rating: "Ausgezeichnet",
                                    note: "Beste Sicht, badetauglich",
                                    clarityMeters: 5.0)
        case .sea:
            return WaterQualityInfo(rating: "Gut",
                                    note: "Badewasser amtlich geprüft",
                                    clarityMeters: 3.5)
        case .river:
            return WaterQualityInfo(rating: "Mäßig",
                                    note: "Nach Regen meiden",
                                    clarityMeters: 1.8)
        }
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

    /// 10-day trend derived from the current water temperature, mirroring the
    /// mock's `genDaily`. Placeholder until a water-temperature forecast exists.
    static func dailyTrend(base: Double) -> [DayTrend] {
        let labels = ["Heute", "Mi", "Do", "Fr", "Sa", "So", "Mo", "Di", "Mi", "Do"]
        return labels.enumerated().map { index, label in
            let center = base + sin(Double(index) / 2) * 1.4 - Double(index) * 0.18
            let low = center - 2.1 - Double(index % 3) * 0.2
            let high = center + 1.7 + Double(index % 2) * 0.3
            return DayTrend(label: label, low: low, high: high)
        }
    }

    /// Synthesises 24 hourly water-temperature points around `base` for when a
    /// real series is unavailable (mirrors the mock's `genHourly`).
    static func syntheticHourly(base: Double, parameter: MeasurementParameter = .waterTemperature) -> [Measurement] {
        let now = Date()
        return (0..<24).map { i in
            let value = base + sin(Double(i) / 24 * .pi * 2 - 0.7) * 0.9 + sin(Double(i) / 3) * 0.12
            let timestamp = now.addingTimeInterval(-Double(23 - i) * 3600)
            return Measurement(parameter: parameter, timestamp: timestamp, value: value)
        }
    }
}
