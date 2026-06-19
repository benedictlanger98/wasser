import SwiftUI

/// Animated water surface behind the detail hero. The design renders a WebGL
/// caustics shader; this is a self-contained SwiftUI port using `TimelineView`
/// + `Canvas`: a deep→shallow vertical gradient, drifting caustic light blobs
/// concentrated near the top, and faint vertical light rays. It captures the
/// same look (colour theme, shimmering light) without a Metal dependency.
struct WaterHeroBackground: View {
    let theme: WaterTheme
    var animated: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !animated)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                draw(in: &context, size: size, time: t)
            }
        }
        .ignoresSafeArea()
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        // Base vertical gradient: deep at the top, shallow toward the waterline.
        let base = Rectangle().path(in: CGRect(origin: .zero, size: size))
        context.fill(base, with: .linearGradient(
            Gradient(colors: [theme.deep, theme.shallow]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)))

        // Caustic blobs — additive, brighter near the top (where light enters).
        context.addFilter(.blur(radius: 18))
        let blobCount = 7
        for i in 0..<blobCount {
            let phase = Double(i) / Double(blobCount)
            let drift = sin(time * 0.35 + phase * .pi * 2)
            let bob = cos(time * 0.5 + phase * 6)
            let x = (phase * 1.15 + 0.08 * drift).truncatingRemainder(dividingBy: 1.0) * size.width
            let y = (0.12 + 0.6 * phase + 0.04 * bob) * size.height
            let radius = size.width * (0.10 + 0.05 * (1 - phase))
            let topMask = 1.0 - (y / size.height) * 0.7
            let opacity = max(0, theme.intensity * 0.10 * topMask)

            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            context.fill(Circle().path(in: rect),
                         with: .color(theme.sun.opacity(opacity)))
        }

        // Light rays: soft vertical bands fading toward the bottom.
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 26))
            let rayCount = 4
            for i in 0..<rayCount {
                let phase = Double(i) / Double(rayCount)
                let x = (phase + 0.06 * sin(time * 0.15 + phase * 5)) * size.width
                let width = size.width * 0.12
                let rect = CGRect(x: x - width / 2, y: 0, width: width, height: size.height)
                layer.fill(Rectangle().path(in: rect),
                           with: .linearGradient(
                            Gradient(colors: [theme.sun.opacity(theme.rays * 0.16), .clear]),
                            startPoint: CGPoint(x: 0, y: size.height),
                            endPoint: .zero))
            }
        }
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
