import Foundation
import CoreLocation

/// A physical measuring point ("Messstelle" in GKD terminology).
///
/// A station belongs to exactly one data source (identified by
/// `dataSourceID`) and exposes a set of parameters. The `externalID` is the
/// source-specific identifier the scraper uses to build detail/data URLs
/// (e.g. the GKD Messstellennummer).
struct MeasurementStation: Identifiable, Codable, Hashable, Sendable {
    let id: String                          // app-wide stable id: "<dataSource>.<externalID>"
    let externalID: String                  // source-specific id (GKD Messstellennummer)
    let dataSourceID: String                // which WaterDataSource owns this station
    let name: String                        // station / place name
    let waterBodyName: String               // the river or lake it sits on
    let waterBodyType: WaterBodyType
    let region: String?                     // Regierungsbezirk / Landkreis
    let latitude: Double
    let longitude: Double
    let elevation: Double?                   // m above sea level, if known
    let operatorName: String?                // betreibende Behörde
    /// Parameters this station is known to report.
    let availableParameters: [MeasurementParameter]
    /// Canonical URL of the station's detail page on the source website.
    let detailURL: URL?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: MeasurementStation, rhs: MeasurementStation) -> Bool { lhs.id == rhs.id }
}

extension MeasurementStation {
    /// Builds the app-wide stable id from a data source id and external id.
    static func makeID(dataSourceID: String, externalID: String) -> String {
        "\(dataSourceID).\(externalID)"
    }

    /// Deterministic value in 0..1 derived from the station id, used to give
    /// each saved card/hero a subtly different gradient hue and animation phase
    /// so they don't all look identical. Stable across launches (FNV-1a hash).
    var appearanceSeed: Double {
        var hash: UInt64 = 1469598103934665603
        for byte in id.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return Double(hash % 10_000) / 10_000.0
    }

    /// Location line shown small under the (big) water-body title: the specific
    /// measuring point (Messstelle). District abbreviations are intentionally
    /// omitted. Empty when the Messstelle is just the water-body name again.
    var locationSubtitle: String {
        name == waterBodyName ? "" : name
    }
}
