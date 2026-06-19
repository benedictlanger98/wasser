import SwiftUI

/// The frosted card used throughout the detail screen
/// (`rgba(255,255,255,0.13)` fill, hairline border, blur, soft shadow).
struct GlassCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.7), in: shape)
            .background(Color.white.opacity(0.10), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }
}

/// Uppercase section header with a leading glyph, matching the design's
/// `rgba(255,255,255,0.62)` caption style.
struct CardHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.4)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.62))
    }
}
