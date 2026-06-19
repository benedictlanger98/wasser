import SwiftUI

/// The saved-locations list (design's LIST screen): a large title, a tappable
/// search field, and one gradient card per saved station.
struct SavedLocationsListView: View {
    @EnvironmentObject private var repository: WaterRepository
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    searchField
                    VStack(spacing: 12) {
                        ForEach(repository.favoriteStations) { station in
                            SavedLocationCard(station: station)
                                .environmentObject(repository)
                                .onTapGesture { router.showDetail(station.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Wassertemperatur")
                .font(.system(size: 34, weight: .bold)).tracking(0.3)
            Spacer()
            Button { router.openSearch(fromList: true) } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 24, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
            }
            .foregroundStyle(.white)
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

    private var theme: WaterTheme { WaterTheme.forType(station.waterBodyType) }

    var body: some View {
        ZStack {
            theme.cardGradient
            ShimmerOverlay()
            LinearGradient(colors: [.black.opacity(0.28), .black.opacity(0.05), .black.opacity(0.18)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            HStack(alignment: .top) {
                VStack(alignment: .leading) {
                    Text(station.waterBodyName).font(.system(size: 23, weight: .semibold))
                    Text(station.region ?? station.name).font(.system(size: 13, weight: .medium)).opacity(0.9)
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

/// Slow diagonal light shimmer used on the cards.
private struct ShimmerOverlay: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        GeometryReader { geo in
            RadialGradient(colors: [.white.opacity(0.30), .clear],
                           center: .init(x: 0.3, y: 0.2), startRadius: 0, endRadius: geo.size.width * 0.7)
                .blendMode(.softLight)
                .offset(x: phase * geo.size.width * 0.3)
                .onAppear {
                    withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { phase = 1 }
                }
        }
    }
}
