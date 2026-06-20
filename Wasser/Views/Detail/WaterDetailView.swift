import SwiftUI
import UIKit

/// The scrollable detail content for one location, rendered over the animated
/// water hero. Mirrors the design's detail screen: hero header, hourly strip,
/// 10-day trend, and a two-column grid of condition cards.
struct WaterDetailView: View {
    @ObservedObject var viewModel: StationDetailViewModel
    @EnvironmentObject private var repository: WaterRepository
    @Environment(\.temperatureUnit) private var unit

    /// Scroll offset, normalized so 0 = at rest and positive = scrolled up.
    /// Drives the Apple-style collapse of the hero into a compact pinned title.
    @State private var scrollOffset: CGFloat = 0

    /// Approximate height of the compact title strip that lives in the
    /// scroll view's top safe-area inset. Together with the device's
    /// safe-area top inset this defines the global Y at which sticky
    /// section headers stop.
    private let compactHeaderHeight: CGFloat = 64

    private let columns = [GridItem(.flexible(), spacing: 11),
                           GridItem(.flexible(), spacing: 11)]

    /// Global Y of the pin line for sticky section headers. Uses
    /// `UIApplication`'s window so the value is correct regardless of
    /// TabView's `.ignoresSafeArea()` and any in-view safe-area games.
    private var pinLineY: CGFloat {
        let safeTop = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 50
        return safeTop + compactHeaderHeight
    }

    /// 0 (hero fully expanded) … 1 (collapsed): the first ~150pt of scrolling.
    private var collapse: CGFloat {
        min(1, max(0, scrollOffset / 150))
    }

    var body: some View {
        ZStack {
            WaterHeroBackground(theme: heroTheme, seed: viewModel.station.appearanceSeed)
            legibilityOverlay
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                        // Fade the big hero out as the user scrolls into
                        // the compact title that occupies the safe-area
                        // inset.
                        .opacity(1 - Double(collapse))
                        .scaleEffect(1 - 0.06 * collapse, anchor: .top)
                    Color.clear.frame(height: 70) // breathing room above cards
                    if let alert = viewModel.conditions?.weather?.alerts.first {
                        // Larger fadeRange so the alert starts dissolving
                        // sooner — well before it kisses the pin line.
                        PinnedFadeCard(pinY: pinLineY, pins: false, fadeRange: 90) {
                            WeatherAlertBanner(alert: alert)
                                .padding(.horizontal, 14)
                        }
                        .padding(.bottom, 11)
                    }
                    if let conditions = viewModel.conditions {
                        cards(conditions, pinY: pinLineY)
                    }
                    SourceFooter()
                        .padding(.top, 22)
                }
                .padding(.bottom, 130)
            }
            .modifier(ScrollOffsetWatcher(offset: $scrollOffset))
            // The compact title lives in the scroll view's top safe-area
            // inset. Reserving that strip means pinned section headers
            // stop at the inset's bottom edge — below the status bar.
            .safeAreaInset(edge: .top, spacing: 0) {
                compactHeader
            }
        }
        .task { await viewModel.load() }
        .onChange(of: repository.refreshToken) { _, _ in
            Task { await viewModel.reload() }
        }
    }

    /// Apple-Weather-style condensed title that lives in the scroll view's
    /// top safe-area inset. The text is sized large enough to read as the
    /// page title; the material backdrop is light and only ramps in when
    /// the user has scrolled, so at rest the big hero reads through.
    private var compactHeader: some View {
        let c = viewModel.conditions
        return VStack(spacing: 3) {
            Text(viewModel.station.displayWaterBodyName)
                .font(.system(size: 22, weight: .medium))
            HStack(spacing: 6) {
                Text("\(Fmt.temp0(c?.waterTemperature ?? 0, unit))°")
                if !conditionText.isEmpty {
                    Text("|").opacity(0.55)
                    Text(conditionText)
                }
            }
            .font(.system(size: 16, weight: .regular))
            .opacity(0.95)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.32), radius: 10, y: 1)
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .opacity(Double(collapse))
    }

    /// Per-station themed hero: base water-type palette, varied by the station's
    /// seed and the current water temperature (warmer water → warmer tint).
    private var heroTheme: WaterTheme {
        let warmth = viewModel.conditions.map { min(1, max(0, ($0.waterTemperature - 8) / 20)) } ?? 0.5
        return WaterTheme.forType(viewModel.station.waterBodyType)
            .varied(seed: viewModel.station.appearanceSeed, warmth: warmth)
    }

    private var legibilityOverlay: some View {
        LinearGradient(stops: [
            .init(color: .black.opacity(0.45), location: 0),
            .init(color: .black.opacity(0.12), location: 0.18),
            .init(color: .clear, location: 0.42),
            .init(color: .clear, location: 0.60),
            .init(color: Color(red: 0, green: 0.04, blue: 0.06).opacity(0.45), location: 1)
        ], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Hero

    private var hero: some View {
        let c = viewModel.conditions
        return VStack(spacing: 2) {
            Text(viewModel.station.displayWaterBodyName)
                .font(.system(size: 32, weight: .medium))
            if !viewModel.station.locationSubtitle.isEmpty {
                Text(viewModel.station.locationSubtitle)
                    .font(.system(size: 14, weight: .semibold)).tracking(0.6).opacity(0.85)
            }
            HStack(alignment: .top, spacing: 0) {
                Text("\(Fmt.temp0(c?.waterTemperature ?? 0, unit))")
                    .font(.system(size: 96, weight: .light))
                Text("°").font(.system(size: 40, weight: .light)).padding(.top, 10)
            }
            Text(conditionText).font(.system(size: 21, weight: .medium))
            if c?.daily.isEmpty == false {
                Text("H: \(maxMin.hi)°  T: \(maxMin.lo)°")
                    .font(.system(size: 18, weight: .semibold)).opacity(0.92)
            }
            if let air = c?.weather?.temperature {
                Label("Luft \(Fmt.temp0(air, unit))°", systemImage: "thermometer.sun")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())
                    .padding(.top, 10)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 1)
        // safeAreaInset already supplies the room under the status bar; a
        // small top gap is enough.
        .padding(.top, 22)
        .padding(.horizontal, 20)
    }

    /// Water-focused condition line: swimming comfort plus the temperature
    /// trend, e.g. "Angenehm · steigend". Falls back to the comfort rating alone
    /// when the trend is steady or no conditions are loaded yet.
    private var conditionText: String {
        guard let c = viewModel.conditions else { return "" }
        return c.trend == .steady ? c.comfort.rating : "\(c.comfort.rating) · \(c.trend.label)"
    }

    private var maxMin: (hi: String, lo: String) {
        // Today's high/low (the daily trend is newest-first).
        guard let today = viewModel.conditions?.daily.first else { return ("–", "–") }
        return (Fmt.temp0(today.high, unit), Fmt.temp0(today.low, unit))
    }

    // MARK: Cards

    @ViewBuilder
    private func cards(_ c: LocationConditions, pinY: CGFloat) -> some View {
        // Each StickyCard tracks its own frame and self-pins to `pinY`
        // (bottom of the compact header). Its inner content gets an inverse
        // offset so it scrolls up behind the title strip; as the card's
        // own bottom approaches the pin line — i.e. the next card has
        // arrived — opacity ramps to zero for the cross-fade hand-off.
        VStack(spacing: 11) {
            if !c.hourly.isEmpty {
                StickyCard(pinY: pinY) {
                    // Use the canonical waterTemperature (same source as the
                    // hero) so the trailing number can't drift from the big
                    // value by a decimal.
                    stickySectionHeader(title: "24-STUNDEN-TREND",
                                        systemImage: "clock",
                                        trailing: "\(Fmt.temp1(c.waterTemperature, unit))°")
                } content: {
                    HourlyTemperatureCard(hourly: c.hourly, showHeader: false, corners: .bottom)
                }
            }
            if !c.daily.isEmpty {
                StickyCard(pinY: pinY) {
                    stickySectionHeader(title: "7-TAGE-TREND",
                                        systemImage: "calendar",
                                        trailing: nil)
                } content: {
                    DailyTrendCard(days: c.daily, showHeader: false, corners: .bottom)
                }
            }
            // 2-column grid of small cards, each in a StickyCard so its
            // header pins at the bottom of the compact title and its body
            // scrolls behind. Cards in the same row pin together (same
            // natural minY) and fade out together as the next row arrives.
            LazyVGrid(columns: columns, spacing: 11) {
                smallStickyCard(pinY: pinY, title: "LUFT & WASSER", systemImage: "wind") {
                    AirWaterCard(water: c.waterTemperature, air: c.weather?.temperature,
                                 showHeader: false, corners: .bottom)
                }
                smallStickyCard(pinY: pinY, title: "UV-INDEX", systemImage: "sun.max") {
                    UVCard(index: c.weather?.uvIndex ?? 0,
                           category: c.weather?.uvCategory ?? "–",
                           showHeader: false, corners: .bottom)
                }
                smallStickyCard(pinY: pinY, title: "WIND", systemImage: "wind") {
                    WindCard(speed: c.weather?.windSpeed ?? 0,
                             gust: c.weather?.windGust ?? 0,
                             compass: c.weather?.windCompass ?? "–",
                             degrees: c.weather?.windDirectionDegrees ?? 0,
                             showHeader: false, corners: .bottom)
                }
                smallStickyCard(pinY: pinY, title: "BADEHINWEIS", systemImage: c.comfort.symbolName) {
                    BadehinweisCard(comfort: c.comfort,
                                    waterTemperature: c.waterTemperature,
                                    showHeader: false, corners: .bottom)
                }
                if let marine = c.marine {
                    smallStickyCard(pinY: pinY, title: "WELLENHÖHE", systemImage: "water.waves") {
                        WaveCard(marine: marine, showHeader: false, corners: .bottom)
                    }
                    smallStickyCard(pinY: pinY, title: "GEZEITEN",
                                    systemImage: "water.waves.and.arrow.trianglehead.up") {
                        TideCard(marine: marine, showHeader: false, corners: .bottom)
                    }
                }
                // Discharge for rivers; water level wherever the station
                // gauges it (rivers + the few lakes that report a level).
                if let discharge = c.discharge {
                    smallStickyCard(pinY: pinY, title: "ABFLUSS",
                                    systemImage: "water.waves.and.arrow.trianglehead.up") {
                        AbflussCard(discharge: discharge, annualMean: c.dischargeAnnualMean,
                                    showHeader: false, corners: .bottom)
                    }
                }
                if let level = c.waterLevel {
                    smallStickyCard(pinY: pinY, title: "WASSERSTAND", systemImage: "ruler") {
                        WasserstandCard(level: level, annualMean: c.waterLevelAnnualMean,
                                        showHeader: false, corners: .bottom)
                    }
                }
                smallStickyCard(pinY: pinY, title: "SONNE", systemImage: "sunrise") {
                    SunriseCard(sunrise: c.weather?.sunrise, sunset: c.weather?.sunset,
                                showHeader: false, corners: .bottom)
                }
            }
        }
        .padding(.horizontal, 14)
    }

    /// Convenience that wraps a small (grid-cell) card in a `StickyCard`
    /// using `stickySectionHeader` for the title strip.
    @ViewBuilder
    private func smallStickyCard<Body: View>(pinY: CGFloat,
                                             title: String,
                                             systemImage: String,
                                             @ViewBuilder body: @escaping () -> Body) -> some View {
        StickyCard(pinY: pinY) {
            stickySectionHeader(title: title, systemImage: systemImage, trailing: nil)
        } content: {
            body()
        }
    }

    /// One pinned section header row. Designed to look like the top of the
    /// card below it (same material/fill/border, rounded top corners only,
    /// no bottom rounding) so when scrolled into normal position the two
    /// read as one continuous card, and when pinned the card body slides
    /// behind it.
    private func stickySectionHeader(title: String,
                                     systemImage: String,
                                     trailing: String?) -> some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: 18,
                                           bottomLeadingRadius: 0,
                                           bottomTrailingRadius: 0,
                                           topTrailingRadius: 18,
                                           style: .continuous)
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.4)
            } icon: {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.62))
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.7), in: shape)
        .background(Color.white.opacity(0.10), in: shape)
        .overlay(shape.strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
    }

}

/// Apple-Weather-style sticky card. Stays in document flow normally,
/// then once its top crosses `pinY` it self-pins to that line while its
/// content slides up behind the header. As the card's own bottom
/// approaches the pin line (the next card has arrived), opacity ramps to
/// zero for a cross-fade hand-off.
private struct StickyCard<Header: View, Content: View>: View {
    let pinY: CGFloat
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    /// Live measurement of the card's natural layout frame in the global
    /// coordinate space. `nil` until the GeometryReader fires — when nil,
    /// no offset or fade is applied, so the card renders at its natural
    /// position from the very first frame.
    @State private var frame: CGRect? = nil

    var body: some View {
        VStack(spacing: 0) {
            header()
                .zIndex(1)
            content()
                .offset(y: contentOffset)
                .zIndex(0)
                .clipped()
        }
        .opacity(opacity)
        .offset(y: cardOffset)
        .overlay(
            // .overlay (not .background) + GeometryReader is the pattern
            // from the reference; the colocated preference+listener stays
            // scoped to THIS card's subtree.
            GeometryReader { geo in
                Color.clear
                    .preference(key: StickyCardFrameKey.self,
                                value: geo.frame(in: .global))
                    .onPreferenceChange(StickyCardFrameKey.self) { rect in
                        frame = rect
                    }
            }
            .allowsHitTesting(false)
        )
    }

    /// Pushes the whole card down enough to keep its top at `pinY` once
    /// natural scrolling would carry it above the line.
    private var cardOffset: CGFloat {
        guard let frame, frame.minY < pinY else { return 0 }
        return pinY - frame.minY
    }

    /// Inverse offset on the content body so it appears to scroll up
    /// behind the (now-stationary) header.
    private var contentOffset: CGFloat {
        guard let frame, frame.minY < pinY else { return 0 }
        return -(pinY - frame.minY)
    }

    /// 1 → 0 over the last 30pt as the card's bottom approaches `pinY`
    /// (i.e. the next card has arrived to take over).
    private var opacity: Double {
        guard let frame else { return 1 }
        let bottomDistance = frame.maxY - pinY
        let fadeRange: CGFloat = 30
        if bottomDistance < fadeRange {
            return max(0, Double(bottomDistance / fadeRange))
        }
        return 1
    }
}

/// Per-StickyCard global frame; each card writes its own and observes only
/// its own value, so no cross-card reduction is needed.
private struct StickyCardFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Lighter sibling of `StickyCard` for items that should pin in place and
/// fade out as the next card arrives but don't need the inner
/// content-scrolls-behind-header animation. Used for the weather alert
/// (with `pins: false` — just the fade, no pin) and for the smaller
/// condition cards that already carry their own internal header.
private struct PinnedFadeCard<Content: View>: View {
    let pinY: CGFloat
    var pins: Bool = true
    /// How many points the fade is spread over as the card's bottom
    /// approaches the pin line. Larger = starts fading earlier.
    var fadeRange: CGFloat = 30
    @ViewBuilder let content: () -> Content

    @State private var frame: CGRect? = nil

    var body: some View {
        content()
            .offset(y: pinOffset)
            .opacity(opacity)
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: PinnedFadeFrameKey.self,
                                    value: geo.frame(in: .global))
                        .onPreferenceChange(PinnedFadeFrameKey.self) { frame = $0 }
                }
                .allowsHitTesting(false)
            )
    }

    private var pinOffset: CGFloat {
        guard pins, let frame, frame.minY < pinY else { return 0 }
        return pinY - frame.minY
    }

    private var opacity: Double {
        guard let frame else { return 1 }
        let bottomDistance = frame.maxY - pinY
        if bottomDistance < fadeRange {
            return max(0, Double(bottomDistance / fadeRange))
        }
        return 1
    }
}

private struct PinnedFadeFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Reads the scroll view's content offset on iOS 18+, where it is reliable
/// inside a paged TabView. Earlier systems silently skip the tracking.
private struct ScrollOffsetWatcher: ViewModifier {
    @Binding var offset: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y + geo.contentInsets.top
            } action: { _, newValue in
                offset = newValue
            }
        } else {
            content
        }
    }
}
