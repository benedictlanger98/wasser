import SwiftUI

struct FavoritesView: View {
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

                if viewModel.favoriteWaterBodies.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.favoriteWaterBodies) { body in
                                NavigationLink(value: body) {
                                    WaterBodyRow(
                                        waterBody: body,
                                        temperature: viewModel.currentTemperatures[body.id],
                                        distance: locationManager.distanceToWaterBody(body),
                                        isFavorite: true
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .navigationDestination(for: WaterBody.self) { body in
                                LocationDetailView(waterBody: body)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .refreshable {
                        await viewModel.loadData()
                    }
                }
            }
            .navigationTitle("Favorites")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "star")
                .font(.system(size: 50))
                .foregroundStyle(.white.opacity(0.4))
            Text("No Favorites Yet")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
            Text("Tap the star on any water body\nto add it to your favorites.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
    }
}
