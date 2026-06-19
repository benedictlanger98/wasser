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
    /// Saved stations in user/display order (the detail pager and list use this).
    @Published var favoriteOrder: [String] = []

    private let registry: DataSourceRegistry
    private let weatherProvider: WeatherProvider
    private let favoritesKey = "favorite_station_ids"

    /// Conditions cache keyed by station id, with a short freshness window.
    private var conditionsCache: [String: (value: StationConditions, fetchedAt: Date)] = [:]
    private let conditionsTTL: TimeInterval = 60 * 5

    init(registry: DataSourceRegistry, weatherProvider: WeatherProvider = NoWeatherProvider()) {
        self.registry = registry
        self.weatherProvider = weatherProvider
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
        seedDefaultFavoritesIfNeeded()
        isLoadingStations = false
    }

    /// On first launch there are no saved locations; pre-populate a few
    /// recognisable Bavarian waters so the detail screen has content.
    private func seedDefaultFavoritesIfNeeded() {
        guard favoriteIDs.isEmpty, !stations.isEmpty else { return }
        let preferred = ["Walchensee", "Isar", "Starnberger See", "Chiemsee", "Tegernsee"]
        var seeded: [String] = []
        for name in preferred {
            if let match = stations.first(where: { $0.waterBodyName == name }) {
                seeded.append(match.id)
            }
        }
        if seeded.isEmpty { seeded = Array(stations.prefix(3)).map(\.id) }
        favoriteIDs = Set(seeded)
        favoriteOrder = seeded
        saveFavorites()
    }

    func station(withID id: String) -> MeasurementStation? {
        stations.first { $0.id == id }
    }

    var favoriteStations: [MeasurementStation] {
        favoriteOrder.compactMap { id in stations.first { $0.id == id } }
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
        // Hydrology and weather are fetched concurrently from independent
        // providers, then merged — neither blocks the other.
        async let hydrology = registry.fetchCurrentConditions(for: station)
        async let weather = weatherProvider.currentWeather(at: station.coordinate)
        let base = try await hydrology
        let merged = StationConditions(stationID: base.stationID,
                                       latest: base.latest,
                                       weather: await weather,
                                       fetchedAt: base.fetchedAt)
        conditionsCache[station.id] = (merged, Date())
        return merged
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
            favoriteOrder.removeAll { $0 == station.id }
        } else {
            favoriteIDs.insert(station.id)
            favoriteOrder.append(station.id)
        }
        saveFavorites()
    }

    /// Adds a station to the saved list if absent and returns it (for search).
    @discardableResult
    func addFavorite(_ station: MeasurementStation) -> MeasurementStation {
        if !favoriteIDs.contains(station.id) {
            favoriteIDs.insert(station.id)
            favoriteOrder.append(station.id)
            saveFavorites()
        }
        return station
    }

    private func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: favoritesKey),
              let ids = try? JSONDecoder().decode([String].self, from: data) else { return }
        favoriteOrder = ids
        favoriteIDs = Set(ids)
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteOrder) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
}
