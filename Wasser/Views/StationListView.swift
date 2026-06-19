import SwiftUI

/// PLACEHOLDER UI — to be replaced by the imported `Wassertemperatur.dc.html`
/// design once the claude_design connector is authorised. Kept intentionally
/// simple so the data layer is exercisable end-to-end in the meantime.
struct StationListView: View {
    @EnvironmentObject private var repository: WaterRepository
    @EnvironmentObject private var location: LocationManager
    @State private var query = ""

    private var sections: [(type: WaterBodyType, stations: [MeasurementStation])] {
        let filtered = repository.stations(matching: query)
        return WaterBodyType.allCases.compactMap { type in
            let group = filtered.filter { $0.waterBodyType == type }
            return group.isEmpty ? nil : (type, group)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if repository.isLoadingStations && repository.stations.isEmpty {
                    ProgressView("Messstellen werden geladen …")
                } else {
                    list
                }
            }
            .navigationTitle("Wassertemperatur")
            .navigationDestination(for: MeasurementStation.self) { station in
                StationDetailView(viewModel: StationDetailViewModel(station: station, repository: repository))
            }
            .searchable(text: $query, prompt: "See oder Fluss suchen")
            .task {
                if repository.stations.isEmpty { await repository.loadStations() }
            }
            .refreshable { await repository.loadStations() }
        }
    }

    private var list: some View {
        List {
            if !repository.favoriteStations.isEmpty && query.isEmpty {
                Section("Favoriten") {
                    ForEach(repository.favoriteStations) { station in
                        stationRow(station)
                    }
                }
            }
            ForEach(sections, id: \.type) { section in
                Section(section.type == .lake ? "Seen" : "Flüsse") {
                    ForEach(section.stations) { station in
                        stationRow(station)
                    }
                }
            }
        }
    }

    private func stationRow(_ station: MeasurementStation) -> some View {
        NavigationLink(value: station) {
            HStack(spacing: 12) {
                Image(systemName: station.waterBodyType.symbolName)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(station.waterBodyName).font(.headline)
                    Text(station.name).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if let km = location.distance(to: station) {
                    Text(String(format: "%.0f km", km))
                        .font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }
}

#Preview {
    StationListView()
        .environmentObject(AppEnvironment.preview())
        .environmentObject(LocationManager())
}
