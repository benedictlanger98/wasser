import SwiftUI

/// Animated water surface behind the detail hero. This is a faithful port of
/// the design's WebGL caustics shader (`Wassertemperatur.dc.html`), run as a
/// SwiftUI `colorEffect` Metal shader (`WaterCaustics.metal`) driven by a
/// `TimelineView`. The earlier `Canvas` blob approximation is gone — the shader
/// reproduces the same layered caustics, god-rays, surface sparkle and vignette
/// at full per-pixel fidelity, themed per water body.
struct WaterHeroBackground: View {
    let theme: WaterTheme
    var animated: Bool = true
    /// Per-station 0..1 value: offsets the animation phase and nudges its speed
    /// so two open detail screens of the same water type don't move in lockstep.
    var seed: Double = 0

    /// Stable epoch so the shader's `time` stays small (Float precision) and the
    /// animation is continuous across body re-evaluations.
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            let t = Float(elapsed * (0.85 + 0.3 * seed) + seed * 50)
            GeometryReader { geo in
                Rectangle()
                    .fill(.black)
                    .colorEffect(ShaderLibrary.waterCaustics(
                        .float2(geo.size),
                        .float(t),
                        .float3(Float(theme.deepRGB.0), Float(theme.deepRGB.1), Float(theme.deepRGB.2)),
                        .float3(Float(theme.shallowRGB.0), Float(theme.shallowRGB.1), Float(theme.shallowRGB.2)),
                        .float3(Float(theme.sunRGB.0), Float(theme.sunRGB.1), Float(theme.sunRGB.2)),
                        .float(Float(theme.intensity)),
                        .float(Float(theme.rays)),
                        .float(Float(theme.flow))
                    ))
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    VStack(spacing: 0) {
        WaterHeroBackground(theme: .forType(.lake))
        WaterHeroBackground(theme: .forType(.river))
        WaterHeroBackground(theme: .forType(.sea))
    }
    .background(.black)
}
