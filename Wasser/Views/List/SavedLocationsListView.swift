import StoreKit
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
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.07, blue: 0.11),
                    Color(red: 0.03, green: 0.12, blue: 0.13),
                    Color(red: 0.02, green: 0.10, blue: 0.09)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
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
    /// switch the temperature unit, or leave a tip. While the list is in edit
    /// mode the menu collapses into a single checkmark that exits editing.
    @ViewBuilder
    private var menuButton: some View {
        if editMode.isEditing {
            Button {
                withAnimation { editMode = .inactive }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
            }
            .modifier(ListGlassCircle())
        } else {
            Menu {
                Button {
                    withAnimation { editMode = .active }
                } label: {
                    Label("Liste bearbeiten", systemImage: "pencil")
                }
                .disabled(repository.favoriteStations.isEmpty)

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

/// Tip jar sheet backed by StoreKit 2 consumables. Loads three IAP
/// products from App Store Connect (or a local .storekit file in debug),
/// displays their localised prices, and runs the purchase flow on tap.
///
/// **Setup required in App Store Connect** (or in a `Wasser.storekit`
/// configuration file selected on the run scheme): three consumable
/// in-app purchases with the product IDs listed in `Self.productIDs`.
/// Without those configured, the sheet will show "Trinkgeld-Produkte
/// werden noch geladen" instead of buttons.
struct TipJarView: View {
    @Environment(\.dismiss) private var dismiss

    /// Consumable in-app purchase IDs, sorted small → large. Must match
    /// the products created in App Store Connect.
    private static let productIDs: [String] = [
        "com.wasser.app.tip.small",
        "com.wasser.app.tip.medium",
        "com.wasser.app.tip.large"
    ]

    /// Friendly title shown for each price tier, in the same order as
    /// `productIDs`. Falls back to the product's StoreKit `displayName`
    /// if it doesn't match an entry here.
    private static let tierTitles: [String: String] = [
        "com.wasser.app.tip.small":  "Kleines Trinkgeld",
        "com.wasser.app.tip.medium": "Mittleres Trinkgeld",
        "com.wasser.app.tip.large":  "Großes Trinkgeld"
    ]

    @State private var products: [Product] = []
    @State private var purchasingID: String? = nil
    @State private var message: String? = nil
    @State private var hasLoaded = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color(red: 0.4, green: 0.82, blue: 0.96))
                .padding(.top, 36)
            Text("Trinkgeld geben")
                .font(.system(size: 24, weight: .bold))
            Text("Wenn dir die App gefällt, gib gerne ein...")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)

            tierList

            if let message {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .transition(.opacity)
            }

            Spacer()
            Button("Schließen") { dismiss() }
                .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
        .task { await loadProducts() }
    }

    @ViewBuilder
    private var tierList: some View {
        if products.isEmpty {
            VStack(spacing: 6) {
                if hasLoaded {
                    Text("Trinkgeld-Produkte sind im App-Store-Connect-Setup noch nicht freigegeben.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(products, id: \.id) { product in
                    tipButton(for: product)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func tipButton(for product: Product) -> some View {
        let title = Self.tierTitles[product.id] ?? product.displayName
        let isPurchasing = purchasingID == product.id
        return Button {
            Task { await purchase(product) }
        } label: {
            HStack {
                Text(title)
                Spacer()
                if isPurchasing {
                    ProgressView()
                } else {
                    Text(product.displayPrice).fontWeight(.semibold)
                }
            }
            .font(.system(size: 16))
            .padding(.vertical, 14).padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(purchasingID != nil)
    }

    private func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Set(Self.productIDs))
            // Keep the canonical small → medium → large order from productIDs.
            products = Self.productIDs.compactMap { id in fetched.first { $0.id == id } }
        } catch {
            message = "Trinkgeld-Kasse konnte nicht geladen werden."
        }
        hasLoaded = true
    }

    private func purchase(_ product: Product) async {
        purchasingID = product.id
        defer { purchasingID = nil }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    withAnimation { message = "Vielen Dank für die Unterstützung! 🐳" }
                case .unverified:
                    message = "Zahlung konnte nicht verifiziert werden."
                }
            case .userCancelled:
                break
            case .pending:
                message = "Zahlung wartet auf Bestätigung."
            @unknown default:
                break
            }
        } catch {
            message = "Fehler beim Kauf: \(error.localizedDescription)"
        }
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
                    Text(conditionText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Fmt.temp0(waterTemp ?? 0, unit))°")
                        .font(.system(size: 50, weight: .light))
                    Spacer()
                    if let today {
                        Text("H: \(Fmt.temp0(today.high, unit))° T: \(Fmt.temp0(today.low, unit))°")
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
        case .river: return "Fluss"
        case .sea:   return "Meer"
        case .lake:  return "See"
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
