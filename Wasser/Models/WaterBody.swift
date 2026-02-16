import Foundation
import CoreLocation

enum WaterBodyType: String, Codable, CaseIterable {
    case lake = "Lake"
    case river = "River"

    var icon: String {
        switch self {
        case .lake: return "water.waves"
        case .river: return "arrow.right.to.line.compact"
        }
    }
}

struct WaterBody: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let type: WaterBodyType
    let latitude: Double
    let longitude: Double
    let region: String
    let elevation: Int?        // meters above sea level
    let maxDepth: Double?      // meters
    let surfaceArea: Double?   // km²

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WaterBody, rhs: WaterBody) -> Bool {
        lhs.id == rhs.id
    }
}
