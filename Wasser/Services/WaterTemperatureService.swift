import Foundation
import Combine

protocol WaterTemperatureServiceProtocol {
    func fetchWaterBodies() async throws -> [WaterBody]
    func fetchConditions(for waterBodyId: String) async throws -> WaterConditions
    func fetchAllCurrentTemperatures() async throws -> [String: TemperatureMeasurement]
}

enum WaterServiceError: LocalizedError {
    case networkError
    case decodingError
    case notFound
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .networkError: return "Unable to connect. Check your internet connection."
        case .decodingError: return "Unexpected data format received."
        case .notFound: return "Water body not found."
        case .serverError(let code): return "Server error (\(code)). Try again later."
        }
    }
}

@MainActor
final class WaterTemperatureViewModel: ObservableObject {
    @Published var waterBodies: [WaterBody] = []
    @Published var currentTemperatures: [String: TemperatureMeasurement] = [:]
    @Published var selectedConditions: WaterConditions?
    @Published var isLoading = false
    @Published var error: String?
    @Published var searchText = ""
    @Published var favoriteIds: Set<String> = []

    private let service: WaterTemperatureServiceProtocol
    private let favoritesKey = "favoriteWaterBodies"

    var filteredWaterBodies: [WaterBody] {
        if searchText.isEmpty {
            return waterBodies
        }
        return waterBodies.filter { body in
            body.name.localizedCaseInsensitiveContains(searchText) ||
            body.region.localizedCaseInsensitiveContains(searchText)
        }
    }

    var favoriteWaterBodies: [WaterBody] {
        waterBodies.filter { favoriteIds.contains($0.id) }
    }

    init(service: WaterTemperatureServiceProtocol = MockDataProvider()) {
        self.service = service
        loadFavorites()
    }

    func loadData() async {
        isLoading = true
        error = nil
        do {
            async let bodies = service.fetchWaterBodies()
            async let temps = service.fetchAllCurrentTemperatures()
            let (fetchedBodies, fetchedTemps) = try await (bodies, temps)
            waterBodies = fetchedBodies
            currentTemperatures = fetchedTemps
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadConditions(for waterBodyId: String) async {
        isLoading = true
        error = nil
        do {
            selectedConditions = try await service.fetchConditions(for: waterBodyId)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func toggleFavorite(_ waterBodyId: String) {
        if favoriteIds.contains(waterBodyId) {
            favoriteIds.remove(waterBodyId)
        } else {
            favoriteIds.insert(waterBodyId)
        }
        saveFavorites()
    }

    func isFavorite(_ waterBodyId: String) -> Bool {
        favoriteIds.contains(waterBodyId)
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favoriteIds = ids
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteIds) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }
}
