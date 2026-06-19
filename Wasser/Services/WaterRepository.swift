import Foundation

/// The application's single entry point for water data. It owns a
/// `DataSourceRegistry`, holds an in-memory cache, and persists favourites.
///
/// UI layers observe this object; they never see individual data sources, so
/// providers can be added or reordered behind it freely.
@MainActor
final class WaterRepository: ObservableObject {
    @Published private(set) var stations: [MeasurementStation] = []
    @Published private(set) var isLoadingStations = false
    @Published var lastError: String?
    @Published var favoriteIDs: Set<String> = []

    private let registry: DataSourceRegistry
    private let favoritesKey = "favorite_station_ids"

    /// Conditions cache keyed by station id, with a short freshness window.
    private var conditionsCache: [String: (value: StationConditions, fetchedAt: Date)] = [:]
    private let conditionsTTL: TimeInterval = 60 * 5

    init(registry: DataSourceRegistry) {
        self.registry = registry
        loadFavorites()
    }

    // MARK: - Stations

    func loadStations() async {
        isLoadingStations = true
        lastError = nil
        stations = await registry.fetchAllStations()
            .sorted { $0.waterBodyName.localizedCompare($1.waterBodyName) == .orderedAscending }
        if stations.isEmpty {
            lastError = "Keine Messstellen gefunden."
        }
        isLoadingStations = false
    }

    func station(withID id: String) -> MeasurementStation? {
        stations.first { $0.id == id }
    }

    var favoriteStations: [MeasurementStation] {
        stations.filter { favoriteIDs.contains($0.id) }
    }

    func stations(matching query: String) -> [MeasurementStation] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return stations }
        return stations.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.waterBodyName.localizedCaseInsensitiveContains(query) ||
            ($0.region?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    // MARK: - Conditions & series

    func conditions(for station: MeasurementStation, forceRefresh: Bool = false) async throws -> StationConditions {
        if !forceRefresh,
           let cached = conditionsCache[station.id],
           Date().timeIntervalSince(cached.fetchedAt) < conditionsTTL {
            return cached.value
        }
        let conditions = try await registry.fetchCurrentConditions(for: station)
        conditionsCache[station.id] = (conditions, Date())
        return conditions
    }

    func timeSeries(for station: MeasurementStation,
                    parameter: MeasurementParameter,
                    range: TimeRange) async throws -> TimeSeries {
        try await registry.fetchTimeSeries(for: station, parameter: parameter, range: range)
    }

    // MARK: - Favourites

    func isFavorite(_ station: MeasurementStation) -> Bool {
        favoriteIDs.contains(station.id)
    }

    func toggleFavorite(_ station: MeasurementStation) {
        if favoriteIDs.contains(station.id) {
            favoriteIDs.remove(station.id)
        } else {
            favoriteIDs.insert(station.id)
        }
        saveFavorites()
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favoriteIDs = ids
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteIDs) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
}
