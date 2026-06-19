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
    /// Horizontal drift of the caustics (rivers flow; lakes/sea are still).
    let flow: Double

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
                 rays: Double,
                 flow: Double) {
        self.deepRGB = deep
        self.shallowRGB = shallow
        self.sunRGB = sun
        self.deep = Color(red: deep.0, green: deep.1, blue: deep.2)
        self.shallow = Color(red: shallow.0, green: shallow.1, blue: shallow.2)
        self.sun = Color(red: sun.0, green: sun.1, blue: sun.2)
        self.intensity = intensity
        self.rays = rays
        self.flow = flow
    }

    // Constants ported verbatim from the design's `themeFor` (Wassertemperatur.dc.html).
    static func forType(_ type: WaterBodyType) -> WaterTheme {
        switch type {
        case .sea:
            return WaterTheme(deep: (0.05, 0.32, 0.42), shallow: (0.45, 0.85, 0.82),
                              sun: (1.0, 1.0, 0.92), intensity: 1.35, rays: 0.78, flow: 0.0)
        case .river:
            return WaterTheme(deep: (0.05, 0.16, 0.12), shallow: (0.28, 0.52, 0.40),
                              sun: (0.85, 1.0, 0.82), intensity: 0.95, rays: 0.45, flow: 0.07)
        case .lake:
            return WaterTheme(deep: (0.02, 0.12, 0.20), shallow: (0.10, 0.46, 0.56),
                              sun: (0.72, 0.95, 1.0), intensity: 1.15, rays: 0.58, flow: 0.0)
        }
    }

    /// Diagonal gradient used by the saved-location cards (`linear-gradient(150deg, shallow, deep)`).
    var cardGradient: LinearGradient { cardGradient(seed: 0.5) }

    /// Card gradient whose diagonal angle is nudged a little by `seed`, so saved
    /// cards of the same water type don't share an identical sweep.
    func cardGradient(seed: Double) -> LinearGradient {
        let angle = (150.0 + (seed - 0.5) * 70.0) * .pi / 180.0   // around the design's 150°
        let dx = cos(angle) * 0.5, dy = sin(angle) * 0.5
        return LinearGradient(colors: [shallow, deep],
                              startPoint: UnitPoint(x: 0.5 - dx, y: 0.5 - dy),
                              endPoint: UnitPoint(x: 0.5 + dx, y: 0.5 + dy))
    }
}

extension WaterTheme {
    /// A per-station variant of this theme: a subtle, deterministic hue rotation
    /// and brightness shift from `seed`, nudged warmer/cooler by `warmth`
    /// (0 = cold water, 1 = warm). Keeps each card/hero distinct while staying
    /// within the water body's palette.
    func varied(seed: Double, warmth: Double = 0.5) -> WaterTheme {
        let hueShift = (seed - 0.5) * 0.07 + (warmth - 0.5) * 0.05
        let brightShift = 1.0 + (seed - 0.5) * 0.14
        let satShift = 1.0 + (warmth - 0.5) * 0.12
        func adjust(_ c: (Double, Double, Double)) -> (Double, Double, Double) {
            var hsb = WaterTheme.rgbToHSB(c)
            hsb.h = (hsb.h + hueShift).truncatingRemainder(dividingBy: 1.0)
            if hsb.h < 0 { hsb.h += 1 }
            hsb.s = min(1, max(0, hsb.s * satShift))
            hsb.b = min(1, max(0, hsb.b * brightShift))
            return WaterTheme.hsbToRGB(hsb)
        }
        return WaterTheme(deep: adjust(deepRGB),
                          shallow: adjust(shallowRGB),
                          sun: adjust(sunRGB),
                          intensity: intensity * (0.9 + 0.2 * seed),
                          rays: rays * (0.85 + 0.3 * (1 - seed)),
                          flow: flow + (seed - 0.5) * 0.02)
    }

    fileprivate static func rgbToHSB(_ c: (Double, Double, Double)) -> (h: Double, s: Double, b: Double) {
        let r = c.0, g = c.1, b = c.2
        let maxV = max(r, g, b), minV = min(r, g, b)
        let delta = maxV - minV
        var h = 0.0
        if delta != 0 {
            if maxV == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxV == g { h = (b - r) / delta + 2 }
            else { h = (r - g) / delta + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        return (h, maxV == 0 ? 0 : delta / maxV, maxV)
    }

    fileprivate static func hsbToRGB(_ c: (h: Double, s: Double, b: Double)) -> (Double, Double, Double) {
        let h = c.h * 6, s = c.s, v = c.b
        let i = floor(h), f = h - i
        let p = v * (1 - s), q = v * (1 - s * f), t = v * (1 - s * (1 - f))
        switch Int(i) % 6 {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }
}
