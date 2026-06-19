import SwiftUI

@main
struct WasserApp: App {
    @StateObject private var repository = AppEnvironment.live()
    @StateObject private var router = AppRouter()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(repository)
                .environmentObject(router)
                .environmentObject(locationManager)
                .preferredColorScheme(.dark)
                .onAppear { locationManager.requestPermission() }
        }
    }
}
