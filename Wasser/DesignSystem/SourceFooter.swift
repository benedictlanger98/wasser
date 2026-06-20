import SwiftUI

/// A small, unobtrusive data-source credit shown under the saved-locations list
/// and under each detail screen, mirroring Apple Weather's "Weather data
/// provided by …" footer. The strings name the real providers the app ships
/// with (see `AppEnvironment`): GKD Bayern for hydrology, Apple Weather for
/// meteorology.
struct SourceFooter: View {
    /// When true (detail screen) the weather provider is credited too; the list
    /// only shows hydrology cards, so it credits GKD alone.
    var includesWeather: Bool = true

    var body: some View {
        VStack(spacing: 2) {
            Text("Gewässerdaten: Gewässerkundlicher Dienst Bayern (gkd.bayern.de)")
            if includesWeather {
                Text("Wetterdaten von Apple Wetter")
            }
        }
        .font(.system(size: 11))
        .multilineTextAlignment(.center)
        .foregroundStyle(.white.opacity(0.45))
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}
