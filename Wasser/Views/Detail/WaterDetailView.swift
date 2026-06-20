import SwiftUI

/// The scrollable detail content for one location, rendered over the animated
/// water hero. Mirrors the design's detail screen: hero header, hourly strip,
/// 10-day trend, and a two-column grid of condition cards.
struct WaterDetailView: View {
    @ObservedObject var viewModel: StationDetailViewModel
    @EnvironmentObject private var repository: WaterRepository
    @Environment(\.temperatureUnit) private var unit

    /// Scroll offset in the named scroll space: 0 at rest, negative as content
    /// scrolls up. Drives the Apple-style collapse of the hero into a compact
    /// pinned title.
    @State private var scrollOffset: CGFloat = 0

    private let columns = [GridItem(.flexible(), spacing: 11),
                           GridItem(.flexible(), spacing: 11)]

    /// 0 (hero fully expanded) … 1 (collapsed): the first ~150pt of scrolling.
    private var collapse: CGFloat {
        min(1, max(0, -scrollOffset / 150))
    }

    var body: some View {
        ZStack {
            WaterHeroBackground(theme: heroTheme, seed: viewModel.station.appearanceSeed)
            legibilityOverlay
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Tracks scroll offset for the collapse animation.
                    GeometryReader { geo in
                        Color.clear.preference(key: ScrollOffsetKey.self,
                                               value: geo.frame(in: .named("detailScroll")).minY)
                    }
                    .frame(height: 0)

                    if let alert = viewModel.conditions?.weather?.alerts.first {
                        WeatherAlertBanner(alert: alert)
                            .padding(.horizontal, 14)
                            .padding(.top, 56)
                            .padding(.bottom, 2)
                    }
                    hero
                        // Compress the big hero away as the user scrolls, so it
                        // doesn't read double with the pinned compact title.
                        .opacity(1 - Double(collapse))
                        .scaleEffect(1 - 0.06 * collapse, anchor: .top)
                    Color.clear.frame(height: 118) // let the water show through
                    if let conditions = viewModel.conditions {
                        cards(conditions)
                    }
                    SourceFooter()
                        .padding(.top, 22)
                }
                .padding(.bottom, 130)
            }
            .coordinateSpace(name: "detailScroll")
            .onPreferenceChange(ScrollOffsetKey.self) { scrollOffset = $0 }

            compactHeader
        }
        .task { await viewModel.load() }
        .onChange(of: repository.refreshToken) { _, _ in
            Task { await viewModel.reload() }
        }
    }

    /// Apple-style condensed title that fades/slides in once the hero scrolls
    /// away, keeping the location name (and temperature) visible at the top.
    private var compactHeader: some View {
        let c = viewModel.conditions
        return VStack(spacing: 1) {
            Text(viewModel.station.displayWaterBodyName)
                .font(.system(size: 17, weight: .semibold))
            HStack(spacing: 6) {
                Text("\(Fmt.temp0(c?.waterTemperature ?? 0, unit))°")
                    .font(.system(size: 15, weight: .medium))
                if !conditionText.isEmpty {
                    Text("·").opacity(0.5)
                    Text(conditionText).font(.system(size: 14)).opacity(0.85)
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.top, 56)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial.opacity(Double(collapse) * 0.9))
        .opacity(Double(collapse))
        .offset(y: (1 - collapse) * -8)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
        .allowsHitTesting(false)
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

    private var hasAlert: Bool {
        !(viewModel.conditions?.weather?.alerts.isEmpty ?? true)
    }

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
                Label("Luft \(Fmt.temp0(air, unit))°", systemImage: "drop")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.16), in: Capsule())
                    .padding(.top, 10)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.28), radius: 18, y: 1)
        .padding(.top, hasAlert ? 16 : 78)
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
    private func cards(_ c: LocationConditions) -> some View {
        VStack(spacing: 11) {
            if !c.hourly.isEmpty {
                HourlyTemperatureCard(hourly: c.hourly)
            }
            if !c.daily.isEmpty {
                DailyTrendCard(days: c.daily)
            }
            LazyVGrid(columns: columns, spacing: 11) {
                AirWaterCard(water: c.waterTemperature, air: c.weather?.temperature)
                UVCard(index: c.weather?.uvIndex ?? 0, category: c.weather?.uvCategory ?? "–")
                WindCard(speed: c.weather?.windSpeed ?? 0,
                         gust: c.weather?.windGust ?? 0,
                         compass: c.weather?.windCompass ?? "–",
                         degrees: c.weather?.windDirectionDegrees ?? 0)
                BadehinweisCard(comfort: c.comfort, waterTemperature: c.waterTemperature)
                if let marine = c.marine {
                    WaveCard(marine: marine)
                    TideCard(marine: marine)
                }
                // Discharge for rivers; water level wherever the station gauges
                // it (rivers and the few lakes that report a level).
                if let discharge = c.discharge {
                    AbflussCard(discharge: discharge, annualMean: c.dischargeAnnualMean)
                }
                if let level = c.waterLevel {
                    WasserstandCard(level: level, annualMean: c.waterLevelAnnualMean)
                }
                SunriseCard(sunrise: c.weather?.sunrise, sunset: c.weather?.sunset)
            }
        }
        .padding(.horizontal, 14)
    }
}

/// Reports the top of the scroll content within the `detailScroll` coordinate
/// space, so the hero can collapse into a compact title as the user scrolls.
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
