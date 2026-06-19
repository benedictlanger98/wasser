import Foundation

/// The kind of water body a station observes. Drives iconography and grouping.
enum WaterBodyType: String, Codable, CaseIterable, Sendable {
    case lake   // See
    case river  // Fluss

    var symbolName: String {
        switch self {
        case .lake:  return "water.waves"
        case .river: return "arrow.down.right.and.arrow.up.left"
        }
    }

    var displayName: String {
        switch self {
        case .lake:  return "See"
        case .river: return "Fluss"
        }
    }
}
