import SwiftUI

/// Top-level shell. Hosts the swipeable detail pager with its custom bottom bar
/// and overlays the list and search screens with sliding transitions, matching
/// the design's three-screen navigation.
struct RootView: View {
    @EnvironmentObject private var repository: WaterRepository
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if repository.isLoadingStations && repository.stations.isEmpty {
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
        .task {
            if repository.stations.isEmpty { await repository.loadStations() }
            if router.activeStationID == nil {
                router.activeStationID = repository.favoriteStations.first?.id
            }
        }
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
            // Page dots, centred independent of the trailing button width.
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
            HStack {
                Spacer()
                listButton
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(red: 0, green: 0.03, blue: 0.05).opacity(0.55), .clear],
                           startPoint: .bottom, endPoint: .top)
                .allowsHitTesting(false)
        )
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
