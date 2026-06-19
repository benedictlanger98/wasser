import Foundation
import CoreLocation

/// Provides the user's location and distance helpers so the UI can surface
/// nearby stations. Kept independent of the data layer.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published var userLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestLocation() {
        manager.requestLocation()
    }

    /// Distance in kilometres to a station, or nil if location is unknown.
    func distance(to station: MeasurementStation) -> Double? {
        guard let location = userLocation else { return nil }
        return location.distance(from: station.location) / 1000.0
    }

    /// Stations sorted by proximity to the user (unknown location → unchanged).
    func sortedByProximity(_ stations: [MeasurementStation]) -> [MeasurementStation] {
        guard let location = userLocation else { return stations }
        return stations.sorted {
            location.distance(from: $0.location) < location.distance(from: $1.location)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in self.userLocation = locations.last }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location is optional; the user can still browse the full library.
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
