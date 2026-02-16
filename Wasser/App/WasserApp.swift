import SwiftUI

@main
struct WasserApp: App {
    @StateObject private var viewModel = WaterTemperatureViewModel()
    @StateObject private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(locationManager)
                .onAppear {
                    locationManager.requestPermission()
                }
        }
    }
}
