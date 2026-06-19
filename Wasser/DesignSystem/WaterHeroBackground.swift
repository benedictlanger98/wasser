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

    /// Stable epoch so the shader's `time` stays small (Float precision) and the
    /// animation is continuous across body re-evaluations.
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: !animated)) { timeline in
            let t = Float(timeline.date.timeIntervalSince(start))
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
