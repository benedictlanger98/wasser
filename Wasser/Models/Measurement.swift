import Foundation

/// A single observed value for one parameter at one point in time.
struct Measurement: Identifiable, Codable, Hashable, Sendable {
    let parameter: MeasurementParameter
    let timestamp: Date
    let value: Double

    /// Stable identity derived from parameter + timestamp so the same reading
    /// from two fetches de-duplicates cleanly.
    var id: String { "\(parameter.rawValue)@\(Int(timestamp.timeIntervalSince1970))" }

    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = parameter.fractionDigits
        formatter.maximumFractionDigits = parameter.fractionDigits
        let number = formatter.string(from: value as NSNumber) ?? "\(value)"
        return "\(number) \(parameter.unit)"
    }
}

/// One calendar day's aggregated values for a parameter (GKD "Tageswerte":
/// daily mean, maximum and minimum), used by the 10-day trend.
struct DailyAggregate: Codable, Hashable, Sendable {
    let date: Date
    let mean: Double
    let high: Double
    let low: Double
}

/// An ordered series of measurements for a single parameter over a time range.
struct TimeSeries: Codable, Hashable, Sendable {
    let parameter: MeasurementParameter
    /// Sorted ascending by timestamp.
    let points: [Measurement]

    init(parameter: MeasurementParameter, points: [Measurement]) {
        self.parameter = parameter
        self.points = points.sorted { $0.timestamp < $1.timestamp }
    }

    var latest: Measurement? { points.last }
    var isEmpty: Bool { points.isEmpty }

    var range: ClosedRange<Date>? {
        guard let first = points.first?.timestamp,
              let last = points.last?.timestamp,
              first <= last else { return nil }
        return first...last
    }

    var valueBounds: ClosedRange<Double>? {
        let values = points.map(\.value)
        guard let min = values.min(), let max = values.max() else { return nil }
        return min...(max > min ? max : min + 1)
    }

    /// Direction of change across the last few samples.
    var trend: Trend {
        guard points.count >= 2 else { return .stable }
        let tail = points.suffix(4)
        guard let current = tail.last?.value else { return .stable }
        let earlier = tail.dropLast()
        let avg = earlier.map(\.value).reduce(0, +) / Double(earlier.count)
        let delta = current - avg
        let threshold = parameter == .waterTemperature ? 0.2 : 0.01
        if delta > threshold { return .rising }
        if delta < -threshold { return .falling }
        return .stable
    }

    enum Trend: String, Sendable {
        case rising, falling, stable

        var symbolName: String {
            switch self {
            case .rising:  return "arrow.up.right"
            case .falling: return "arrow.down.right"
            case .stable:  return "arrow.right"
            }
        }
    }
}

/// The time window requested when loading a series.
enum TimeRange: String, CaseIterable, Sendable, Identifiable {
    case day = "24h"
    case week = "7 Tage"
    case month = "30 Tage"
    case year = "1 Jahr"

    var id: String { rawValue }

    /// Duration relative to "now", used by data sources to scope a request.
    var interval: TimeInterval {
        switch self {
        case .day:   return 60 * 60 * 24
        case .week:  return 60 * 60 * 24 * 7
        case .month: return 60 * 60 * 24 * 30
        case .year:  return 60 * 60 * 24 * 365
        }
    }
}
