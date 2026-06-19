import SwiftUI

/// Drives top-level navigation between the three screens of the design
/// (detail / saved list / search) and tracks which saved station is shown.
@MainActor
final class AppRouter: ObservableObject {
    enum Screen { case detail, list, search }

    @Published var screen: Screen = .detail
    @Published var activeStationID: String?
    @Published var query: String = ""
    /// Whether search was opened from the list (controls where "Abbrechen" returns).
    private(set) var searchOpenedFromList = false

    func showDetail(_ stationID: String) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            activeStationID = stationID
            screen = .detail
        }
    }

    func openList() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { screen = .list }
    }

    func openSearch(fromList: Bool) {
        searchOpenedFromList = fromList
        query = ""
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) { screen = .search }
    }

    func closeSearch() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.9)) {
            screen = searchOpenedFromList ? .list : .detail
        }
    }
}
