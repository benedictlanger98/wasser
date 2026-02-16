import SwiftUI

struct LocationListView: View {
    @EnvironmentObject var viewModel: WaterTemperatureViewModel
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.waterDeep, .waterMid, .waterLight],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        if !viewModel.searchText.isEmpty && viewModel.filteredWaterBodies.isEmpty {
                            emptySearchView
                        } else {
                            lakesSection
                            riversSection
                        }
                    }
                    .padding(.horizontal)
                }
                .refreshable {
                    await viewModel.loadData()
                }
            }
            .navigationTitle("Wasser")
            .searchable(text: $viewModel.searchText, prompt: "Search lakes and rivers")
            .task {
                if viewModel.waterBodies.isEmpty {
                    await viewModel.loadData()
                }
            }
            .overlay {
                if viewModel.isLoading && viewModel.waterBodies.isEmpty {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
        }
    }

    private var lakesSection: some View {
        let lakes = viewModel.filteredWaterBodies.filter { $0.type == .lake }
        return Group {
            if !lakes.isEmpty {
                sectionHeader("Lakes", icon: "water.waves")
                ForEach(sortedByDistance(lakes)) { body in
                    NavigationLink(value: body) {
                        WaterBodyRow(
                            waterBody: body,
                            temperature: viewModel.currentTemperatures[body.id],
                            distance: locationManager.distanceToWaterBody(body),
                            isFavorite: viewModel.isFavorite(body.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .navigationDestination(for: WaterBody.self) { body in
                    LocationDetailView(waterBody: body)
                }
            }
        }
    }

    private var riversSection: some View {
        let rivers = viewModel.filteredWaterBodies.filter { $0.type == .river }
        return Group {
            if !rivers.isEmpty {
                sectionHeader("Rivers", icon: "arrow.right.to.line.compact")
                ForEach(sortedByDistance(rivers)) { body in
                    NavigationLink(value: body) {
                        WaterBodyRow(
                            waterBody: body,
                            temperature: viewModel.currentTemperatures[body.id],
                            distance: locationManager.distanceToWaterBody(body),
                            isFavorite: viewModel.isFavorite(body.id)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .navigationDestination(for: WaterBody.self) { body in
                    LocationDetailView(waterBody: body)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
            Text(title)
                .font(.headline)
            Spacer()
        }
        .foregroundStyle(.white.opacity(0.8))
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var emptySearchView: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.5))
            Text("No results for \"\(viewModel.searchText)\"")
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 60)
    }

    private func sortedByDistance(_ bodies: [WaterBody]) -> [WaterBody] {
        guard locationManager.userLocation != nil else { return bodies }
        return bodies.sorted { a, b in
            let distA = locationManager.distanceToWaterBody(a) ?? .infinity
            let distB = locationManager.distanceToWaterBody(b) ?? .infinity
            return distA < distB
        }
    }
}
