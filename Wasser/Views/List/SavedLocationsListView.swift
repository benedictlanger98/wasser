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
            Text("Gewässer")
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
                    Text("\(Fmt.f0(waterTemp ?? 0))°")
                        .font(.system(size: 50, weight: .light))
                    Spacer()
                    if let today {
                        Text("H:\(Fmt.f0(today.high))° T:\(Fmt.f0(today.low))°")
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
        .task(id: station.id) {
            // The card only needs the current value and today's max/min — fetch
            // those directly rather than the full detail (no 15-min series).
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
