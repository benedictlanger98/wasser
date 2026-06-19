import SwiftUI

/// Per–water-body colour theme driving the hero gradient, caustic highlights
/// and list-card gradients. Values are ported directly from the design mock
/// (`themeFor`), expressed in 0–1 RGB.
struct WaterTheme: Equatable {
    let deep: Color
    let shallow: Color
    let sun: Color
    /// Brightness of the caustic light pattern.
    let intensity: Double
    /// Strength of the light "rays".
    let rays: Double

    /// Raw shallow/deep components for building gradients elsewhere.
    let deepRGB: (Double, Double, Double)
    let shallowRGB: (Double, Double, Double)
    let sunRGB: (Double, Double, Double)

    static func == (lhs: WaterTheme, rhs: WaterTheme) -> Bool {
        lhs.deepRGB == rhs.deepRGB && lhs.shallowRGB == rhs.shallowRGB
    }

    private init(deep: (Double, Double, Double),
                 shallow: (Double, Double, Double),
                 sun: (Double, Double, Double),
                 intensity: Double,
                 rays: Double) {
        self.deepRGB = deep
        self.shallowRGB = shallow
        self.sunRGB = sun
        self.deep = Color(red: deep.0, green: deep.1, blue: deep.2)
        self.shallow = Color(red: shallow.0, green: shallow.1, blue: shallow.2)
        self.sun = Color(red: sun.0, green: sun.1, blue: sun.2)
        self.intensity = intensity
        self.rays = rays
    }

    static func forType(_ type: WaterBodyType) -> WaterTheme {
        switch type {
        case .sea:
            return WaterTheme(deep: (0.05, 0.32, 0.42), shallow: (0.45, 0.85, 0.82),
                              sun: (1.0, 1.0, 0.92), intensity: 1.35, rays: 0.78)
        case .river:
            return WaterTheme(deep: (0.05, 0.16, 0.12), shallow: (0.28, 0.52, 0.40),
                              sun: (0.85, 1.0, 0.82), intensity: 0.95, rays: 0.45)
        case .lake:
            return WaterTheme(deep: (0.02, 0.12, 0.20), shallow: (0.10, 0.46, 0.56),
                              sun: (0.72, 0.95, 1.0), intensity: 1.15, rays: 0.58)
        }
    }

    /// Diagonal gradient used by the saved-location cards (`linear-gradient(150deg, shallow, deep)`).
    var cardGradient: LinearGradient {
        LinearGradient(colors: [shallow, deep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
