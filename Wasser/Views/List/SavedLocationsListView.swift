import SwiftUI

/// The saved-locations list (design's LIST screen): a large title, a tappable
/// search field, and one gradient card per saved station.
struct SavedLocationsListView: View {
    @EnvironmentObject private var repository: WaterRepository
    @EnvironmentObject private var router: AppRouter
    @State private var editMode: EditMode = .inactive

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
                searchField
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
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("Wassertemperatur")
                .font(.system(size: 34, weight: .bold)).tracking(0.3)
            Spacer()
            Button {
                withAnimation { editMode = editMode.isEditing ? .inactive : .active }
            } label: {
                Image(systemName: editMode.isEditing ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle")
                    .font(.system(size: 24, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
            }
            .disabled(repository.favoriteStations.isEmpty)
            Button { router.openSearch(fromList: true) } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.top, 64)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        Button { router.openSearch(fromList: true) } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                Text("Gewässer oder Ort suchen")
                Spacer()
            }
            .font(.system(size: 17))
            .foregroundStyle(Color(white: 0.92).opacity(0.6))
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(Color(red: 0.46, green: 0.46, blue: 0.50).opacity(0.24),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }
}

/// One 118pt gradient card with shimmer, name/region/condition and big temp.
struct SavedLocationCard: View {
    @EnvironmentObject private var repository: WaterRepository
    let station: MeasurementStation
    @State private var conditions: LocationConditions?

    /// Warmth (0 cold … 1 warm) from the current water temperature, used to tint
    /// the card; defaults to neutral until the value loads.
    private var warmth: Double {
        guard let t = conditions?.waterTemperature else { return 0.5 }
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
                    Text(station.waterBodyName).font(.system(size: 23, weight: .semibold))
                    Text(station.locationSubtitle).font(.system(size: 13, weight: .medium)).opacity(0.9)
                    Spacer()
                    Text(conditionText).font(.system(size: 14, weight: .medium)).opacity(0.95)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Fmt.f0(conditions?.waterTemperature ?? 0))°")
                        .font(.system(size: 50, weight: .ultraLight))
                    Spacer()
                    if let mm = maxMin {
                        Text("Max.\(mm.hi)° Min.\(mm.lo)°").font(.system(size: 13, weight: .semibold)).opacity(0.92)
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
        .task(id: station.id) {
            let vm = StationDetailViewModel(station: station, repository: repository)
            await vm.load()
            conditions = vm.conditions
        }
    }

    private var conditionText: String {
        switch station.waterBodyType {
        case .river: return "Strömung mäßig"
        case .sea:   return "Leichte Brandung"
        case .lake:  return "Klar · Ruhig"
        }
    }

    private var maxMin: (hi: String, lo: String)? {
        let all = (conditions?.daily ?? []).flatMap { [$0.low, $0.high] }
        guard let hi = all.max(), let lo = all.min() else { return nil }
        return (Fmt.f0(hi), Fmt.f0(lo))
    }
}

/// Slow diagonal light shimmer used on the cards. `seed` varies the speed,
/// origin and travel so neighbouring cards don't shimmer in unison.
private struct ShimmerOverlay: View {
    var seed: Double = 0.5
    @State private var phase: CGFloat = -1
    var body: some View {
        GeometryReader { geo in
            let duration = 7.0 + seed * 6.0
            RadialGradient(colors: [.white.opacity(0.30), .clear],
                           center: .init(x: 0.2 + seed * 0.45, y: 0.18),
                           startRadius: 0, endRadius: geo.size.width * (0.6 + 0.3 * seed))
                .blendMode(.softLight)
                .offset(x: phase * geo.size.width * 0.3, y: phase * geo.size.width * 0.05)
                .onAppear {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        phase = 1
                    }
                }
        }
    }
}
