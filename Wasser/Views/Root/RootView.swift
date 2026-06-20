import SwiftUI

/// Top-level shell. Hosts the swipeable detail pager with its custom bottom bar
/// and overlays the list and search screens with sliding transitions, matching
/// the design's three-screen navigation.
struct RootView: View {
    @EnvironmentObject private var repository: WaterRepository
    @EnvironmentObject private var router: AppRouter
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useFahrenheit") private var useFahrenheit = false

    var body: some View {
        ZStack {
            // Behind the pager: a gradient drawn from the active card's water
            // theme, so over-scrolling past the first/last page reveals matching
            // water tones instead of black.
            backgroundView

            if repository.isLoadingStations && repository.stations.isEmpty {
                // The themed gradient is already on screen, so no jarring white
                // launch — just a quiet spinner over it.
                ProgressView().tint(.white)
            } else {
                detailLayer
            }

            if router.screen == .list {
                SavedLocationsListView()
                    .transition(.move(edge: .trailing))
                    .zIndex(2)
            }
            if router.screen == .search {
                SearchView()
                    .transition(.move(edge: .trailing))
                    .zIndex(3)
            }
        }
        .environment(\.temperatureUnit, useFahrenheit ? .fahrenheit : .celsius)
        .task {
            if repository.stations.isEmpty { await repository.loadStations() }
            if router.activeStationID == nil {
                router.activeStationID = repository.favoriteStations.first?.id
            }
        }
        // Re-fetch when the app comes back to the foreground after being idle,
        // so stale readings refresh instead of lingering from a past session.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await repository.refreshIfStale() }
            }
        }
    }

    // MARK: Themed background

    /// Theme of the currently shown station, used for the pager backdrop.
    private var activeTheme: WaterTheme? {
        guard let id = router.activeStationID,
              let station = repository.station(withID: id) else { return nil }
        return WaterTheme.forType(station.waterBodyType).varied(seed: station.appearanceSeed)
    }

    @ViewBuilder
    private var backgroundView: some View {
        let t = activeTheme ?? WaterTheme.forType(.lake)
        let bottom = Color(red: t.deepRGB.0 * 0.45,
                           green: t.deepRGB.1 * 0.45,
                           blue: t.deepRGB.2 * 0.45)
        LinearGradient(colors: [t.deep, bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            // A slower ease keeps the backdrop cross-fading gently as you swipe
            // between pages, instead of snapping to the next page's tone.
            .animation(.easeInOut(duration: 0.6), value: router.activeStationID)
    }

    // MARK: Detail pager + bottom bar

    private var detailLayer: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: activeBinding) {
                ForEach(repository.favoriteStations) { station in
                    DetailPage(station: station, repository: repository)
                        .tag(station.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            bottomBar
        }
        .opacity(router.screen == .detail ? 1 : 0.5)
        .offset(x: router.screen == .detail ? 0 : -UIScreen.main.bounds.width * 0.22)
    }

    private var activeBinding: Binding<String> {
        Binding(
            get: { router.activeStationID ?? repository.favoriteStations.first?.id ?? "" },
            set: { router.activeStationID = $0 }
        )
    }

    private var bottomBar: some View {
        ZStack {
            // Page dots in a Liquid Glass pill (iOS 26+), centred independent of
            // the trailing button width.
            HStack(spacing: 9) {
                ForEach(repository.favoriteStations) { station in
                    Circle()
                        .fill(.white.opacity(station.id == router.activeStationID ? 0.95 : 0.4))
                        .frame(width: 7, height: 7)
                        .onTapGesture {
                            withAnimation { router.activeStationID = station.id }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: router.activeStationID)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .modifier(GlassCapsule())
            HStack {
                Spacer()
                listButton
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
    }

    private var listButton: some View {
        Button { router.openList() } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
        }
        .modifier(GlassCircle())
    }
}

/// Applies a circular Liquid Glass background (iOS 26+), falling back to a
/// frosted material on earlier systems.
private struct GlassCircle: ViewModifier {
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

/// Liquid Glass pill (iOS 26+) behind the pagination dots, with a frosted
/// fallback on earlier systems.
private struct GlassCapsule: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: Capsule())
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
        }
    }
}

/// Wraps a station's detail VM so each page keeps its own state across paging.
private struct DetailPage: View {
    @StateObject private var viewModel: StationDetailViewModel

    init(station: MeasurementStation, repository: WaterRepository) {
        _viewModel = StateObject(wrappedValue: StationDetailViewModel(
            station: station, repository: repository))
    }

    var body: some View {
        WaterDetailView(viewModel: viewModel)
    }
}
