import SwiftUI

@main
struct WasserApp: App {
    @StateObject private var repository = AppEnvironment.live()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            StationListView()
                .environmentObject(repository)
                .environmentObject(locationManager)
                .onAppear { locationManager.requestPermission() }
        }
    }
}
