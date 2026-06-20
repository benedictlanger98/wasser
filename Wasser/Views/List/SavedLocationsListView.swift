import SwiftUI

/// The saved-locations list (design's LIST screen): a large title, a tappable
/// search field, and one gradient card per saved station.
struct SavedLocationsListView: View {
    @EnvironmentObject private var repository: WaterRepository
    @EnvironmentObject private var router: AppRouter
    @State private var editMode: EditMode = .inactive
    @AppStorage("useFahrenheit") private var useFahrenheit = false
    @State private var showingTip = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                List {
                    ForEach(repository.favoriteStations) { station in
                        SavedLocationCard(station: station)
                            .environmentObject(repository)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if editMode == .inactive { router.showDetail(station.id) }
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .onMove { repository.moveFavorite(fromOffsets: $0, toOffset: $1) }
                    .onDelete { repository.removeFavorites(atOffsets: $0) }

                    // Data-source credit, then space for the sticky search bar.
                    SourceFooter(includesWeather: false)
                        .padding(.top, 10)
                        .padding(.bottom, 96)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
            }
            stickySearchBar
        }
        .sheet(isPresented: $showingTip) { TipJarView() }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Gewässer")
                .font(.system(size: 34, weight: .bold)).tracking(0.3)
            Spacer()
            menuButton
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 64)
        .padding(.bottom, 8)
    }

    /// Apple-style "•••" overflow menu in a Liquid-Glass circle: edit the list,
    /// switch the temperature unit, or leave a tip.
    private var menuButton: some View {
        Menu {
            Button {
                withAnimation { editMode = editMode.isEditing ? .inactive : .active }
            } label: {
                Label(editMode.isEditing ? "Fertig" : "Liste bearbeiten",
                      systemImage: editMode.isEditing ? "checkmark" : "pencil")
            }
            .disabled(repository.favoriteStations.isEmpty && !editMode.isEditing)

            Picker("Einheit", selection: unitBinding) {
                Text("°C  Celsius").tag(TemperatureUnit.celsius)
                Text("°F  Fahrenheit").tag(TemperatureUnit.fahrenheit)
            }

            Section {
                Button { showingTip = true } label: {
                    Label("Trinkgeld geben", systemImage: "heart")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
        }
        .modifier(ListGlassCircle())
    }

    private var unitBinding: Binding<TemperatureUnit> {
        Binding(get: { useFahrenheit ? .fahrenheit : .celsius },
                set: { useFahrenheit = ($0 == .fahrenheit) })
    }

    /// Search field pinned to the bottom edge (Apple Weather's sticky search),
    /// tapping it opens the full search screen.
    private var stickySearchBar: some View {
        Button { router.openSearch(fromList: true) } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Gewässer oder Ort suchen")
                Spacer()
                Image(systemName: "mic.fill").opacity(0.8)
            }
            .font(.system(size: 17))
            .foregroundStyle(Color(white: 0.95).opacity(0.7))
            .padding(.vertical, 13).padding(.horizontal, 16)
            .modifier(ListGlassCapsule())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// Liquid-Glass circle (iOS 26+) with a frosted fallback, for the menu button.
private struct ListGlassCircle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Circle())
        } else {
            content
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
        }
    }
}

/// Liquid-Glass capsule (iOS 26+) with a frosted fallback, for the sticky search.
private struct ListGlassCapsule: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
        }
    }
}

/// A lightweight "tip jar" sheet. The real in-app-purchase products still need
/// to be configured in App Store Connect and wired through StoreKit; until then
/// this presents the intent and the tiers without charging.
struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color(red: 0.4, green: 0.82, blue: 0.96))
                .padding(.top, 36)
            Text("Trinkgeld geben")
                .font(.system(size: 24, weight: .bold))
            Text("Wasser ist werbefrei und nutzt offene Daten. Wenn dir die App "
                 + "gefällt, kannst du die Weiterentwicklung mit einem Trinkgeld "
                 + "unterstützen.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
            VStack(spacing: 12) {
                tipButton("Kleines Trinkgeld", "1,99 €")
                tipButton("Mittleres Trinkgeld", "4,99 €")
                tipButton("Großes Trinkgeld", "9,99 €")
            }
            .padding(.horizontal, 24)
            Spacer()
            Button("Schließen") { dismiss() }
                .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
    }

    private func tipButton(_ title: String, _ price: String) -> some View {
        Button {
            // TODO: trigger the matching StoreKit purchase once products exist.
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(price).fontWeight(.semibold)
            }
            .font(.system(size: 16))
            .padding(.vertical, 14).padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// One 118pt gradient card with shimmer, name/region/condition and big temp.
struct SavedLocationCard: View {
    @EnvironmentObject private var repository: WaterRepository
    @Environment(\.temperatureUnit) private var unit
    let station: MeasurementStation
    @State private var waterTemp: Double?
    @State private var today: DailyAggregate?

    /// Warmth (0 cold … 1 warm) from the current water temperature, used to tint
    /// the card; defaults to neutral until the value loads.
    private var warmth: Double {
        guard let t = waterTemp else { return 0.5 }
        return min(1, max(0, (t - 8) / 20))
    }
    private var theme: WaterTheme {
        WaterTheme.forType(station.waterBodyType).varied(seed: station.appearanceSeed, warmth: warmth)
    }

    var body: some View {
        ZStack {
            theme.cardGradient(seed: station.appearanceSeed)
            ShimmerOverlay(seed: station.appearanceSeed)
            LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0.05), .black.opacity(0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(station.displayWaterBodyName).font(.system(size: 23, weight: .semibold))
                    if !station.locationSubtitle.isEmpty {
                        Text(station.locationSubtitle).font(.system(size: 13, weight: .medium)).opacity(0.9)
                    }
                    Spacer()
                    Text(conditionText).font(.system(size: 14, weight: .medium)).opacity(0.95)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Fmt.temp0(waterTemp ?? 0, unit))°")
                        .font(.system(size: 50, weight: .light))
                    Spacer()
                    if let today {
                        Text("H:\(Fmt.temp0(today.high, unit))° T:\(Fmt.temp0(today.low, unit))°")
                            .font(.system(size: 13, weight: .semibold)).opacity(0.92)
                    }
                }
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 1)
            .padding(.horizontal, 18).padding(.vertical, 14)
        }
        .frame(height: 118)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 6)
        .task(id: "\(station.id)#\(repository.refreshToken)") {
            // The card only needs the current value and today's max/min — fetch
            // those directly rather than the full detail (no 15-min series).
            // Keying on `refreshToken` re-runs this after a foreground refresh.
            async let conditions = try? repository.conditions(for: station)
            async let trend = try? repository.dailyTrend(for: station, parameter: .waterTemperature, days: 1)
            waterTemp = (await conditions)?.waterTemperature?.value
            today = (await trend)?.first
        }
    }

    private var conditionText: String {
        switch station.waterBodyType {
        case .river: return "Strömung mäßig"
        case .sea:   return "Leichte Brandung"
        case .lake:  return "Klar · Ruhig"
        }
    }
}

/// A soft sheen sweeping horizontally across the card. The gradient fades to
/// clear at its own left/right edges (so there are no hard band borders) and is
/// full height (no top/bottom seam); `seed` varies the cadence so neighbouring
/// cards don't sweep in unison.
private struct ShimmerOverlay: View {
    var seed: Double = 0.5
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let bandW = w * 0.6
            LinearGradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.10), location: 0.5),
                .init(color: .clear, location: 1)
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: bandW, height: geo.size.height)
            .offset(x: phase * (w + bandW) - bandW)
            .blendMode(.plusLighter)
            .onAppear {
                withAnimation(.linear(duration: 6.0 + seed * 4.0).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .allowsHitTesting(false)
    }
}
