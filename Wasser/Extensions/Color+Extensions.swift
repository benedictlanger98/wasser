import SwiftUI

extension Color {
    // Deep water blue gradient palette — inspired by the native Weather app
    static let waterDeep = Color(red: 0.05, green: 0.10, blue: 0.30)
    static let waterMid = Color(red: 0.08, green: 0.20, blue: 0.45)
    static let waterLight = Color(red: 0.15, green: 0.35, blue: 0.55)
    static let waterSurface = Color(red: 0.25, green: 0.55, blue: 0.70)

    // Temperature-based colors
    static let tempCold = Color(red: 0.20, green: 0.50, blue: 0.90)
    static let tempCool = Color(red: 0.20, green: 0.75, blue: 0.85)
    static let tempMild = Color(red: 0.30, green: 0.80, blue: 0.50)
    static let tempWarm = Color(red: 0.95, green: 0.75, blue: 0.20)
    static let tempHot = Color(red: 0.95, green: 0.45, blue: 0.15)

    static func forTemperature(_ celsius: Double) -> Color {
        switch celsius {
        case ..<8: return .tempCold
        case 8..<14: return .tempCool
        case 14..<20: return .tempMild
        case 20..<24: return .tempWarm
        default: return .tempHot
        }
    }
}
