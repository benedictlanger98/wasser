import SwiftUI

/// Which corners of a GlassCard are rounded. Default `.all` (free-standing
/// card); use `.bottom` when the card sits directly below a separately
/// rendered sticky header that supplies the rounded top.
enum GlassCardCorners {
    case all
    case bottom
}

/// The frosted card used throughout the detail screen
/// (`rgba(255,255,255,0.13)` fill, hairline border, blur, soft shadow).
struct GlassCard<Content: View>: View {
    /// Optional fixed minimum height so a row/grid of cards share one size.
    var minHeight: CGFloat? = nil
    var corners: GlassCardCorners = .all
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .background(.ultraThinMaterial.opacity(0.7), in: shape)
            .background(Color.white.opacity(0.10), in: shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private var shape: UnevenRoundedRectangle {
        switch corners {
        case .all:
            return UnevenRoundedRectangle(topLeadingRadius: 18, bottomLeadingRadius: 18,
                                          bottomTrailingRadius: 18, topTrailingRadius: 18,
                                          style: .continuous)
        case .bottom:
            return UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 18,
                                          bottomTrailingRadius: 18, topTrailingRadius: 0,
                                          style: .continuous)
        }
    }
}

/// Shared minimum height for the two-column condition tiles so they all share
/// the same vertical dimensions.
let smallCardMinHeight: CGFloat = 118

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
