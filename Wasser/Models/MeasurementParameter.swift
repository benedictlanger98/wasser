import Foundation

/// A physical quantity that a measurement station can report.
///
/// Kept open-ended on purpose: GKD Bayern exposes water temperature, water
/// level and discharge today, but other data sources (or future GKD
/// parameters) can add cases without touching call sites that switch
/// exhaustively, because everything routes through `unit`, `symbolName` and
/// `displayName`.
enum MeasurementParameter: String, Codable, CaseIterable, Sendable, Hashable {
    case waterTemperature       // Wassertemperatur
    case waterLevel             // Wasserstand
    case discharge              // Abfluss / Durchfluss (flow rate)
    case airTemperature         // Lufttemperatur (e.g. from weather)
    case precipitation          // Niederschlag

    /// Unit of measure as displayed to the user.
    var unit: String {
        switch self {
        case .waterTemperature, .airTemperature: return "°C"
        case .waterLevel:                         return "cm"
        case .discharge:                          return "m³/s"
        case .precipitation:                      return "mm"
        }
    }

    /// SF Symbol used to represent the parameter in lists and cards.
    var symbolName: String {
        switch self {
        case .waterTemperature: return "thermometer.medium"
        case .airTemperature:   return "thermometer.sun"
        case .waterLevel:       return "ruler"
        case .discharge:        return "water.waves.and.arrow.trianglehead.up"
        case .precipitation:    return "cloud.rain"
        }
    }

    /// Localised label (German, matching the GKD source terminology).
    var displayName: String {
        switch self {
        case .waterTemperature: return "Wassertemperatur"
        case .airTemperature:   return "Lufttemperatur"
        case .waterLevel:       return "Wasserstand"
        case .discharge:        return "Abfluss"
        case .precipitation:    return "Niederschlag"
        }
    }

    /// Number of fraction digits typically shown for this parameter.
    var fractionDigits: Int {
        switch self {
        case .waterTemperature, .airTemperature: return 1
        case .discharge:                          return 2
        case .waterLevel, .precipitation:         return 0
        }
    }
}
