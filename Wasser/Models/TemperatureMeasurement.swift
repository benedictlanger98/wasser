import Foundation

struct TemperatureMeasurement: Identifiable, Codable {
    let id: String
    let waterBodyId: String
    let timestamp: Date
    let temperature: Double   // Celsius
    let depth: Double?        // meters, nil = surface

    var temperatureFormatted: String {
        String(format: "%.1f°", temperature)
    }

    var isWarm: Bool { temperature >= 20 }
    var isCold: Bool { temperature < 10 }
}

struct TemperatureForecast: Identifiable, Codable {
    let id: String
    let waterBodyId: String
    let date: Date
    let highTemperature: Double
    let lowTemperature: Double

    var highFormatted: String { String(format: "%.0f°", highTemperature) }
    var lowFormatted: String { String(format: "%.0f°", lowTemperature) }
}

struct WaterConditions: Codable {
    let waterBodyId: String
    let currentTemperature: TemperatureMeasurement
    let hourlyHistory: [TemperatureMeasurement]
    let dailyForecast: [TemperatureForecast]
    let lastUpdated: Date

    var temperatureTrend: TemperatureTrend {
        guard hourlyHistory.count >= 2 else { return .stable }
        let recent = hourlyHistory.suffix(3)
        let avgRecent = recent.map(\.temperature).reduce(0, +) / Double(recent.count)
        let diff = currentTemperature.temperature - avgRecent
        if diff > 0.3 { return .rising }
        if diff < -0.3 { return .falling }
        return .stable
    }
}

enum TemperatureTrend: String {
    case rising
    case falling
    case stable

    var icon: String {
        switch self {
        case .rising: return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .rising: return "Rising"
        case .falling: return "Falling"
        case .stable: return "Stable"
        }
    }
}
