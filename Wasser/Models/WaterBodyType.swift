import Foundation

/// The kind of water body a station observes. Drives iconography, grouping and
/// the hero theme. `sea` is included so the UI can also render coastal sources
/// (waves/tides) if one is added later; the Bavarian GKD catalogue only
/// produces `lake` and `river`.
enum WaterBodyType: String, Codable, CaseIterable, Sendable {
    case lake   // See
    case river  // Fluss
    case sea    // Meer

    var symbolName: String {
        switch self {
        case .lake:  return "water.waves"
        case .river: return "arrow.down.right.and.arrow.up.left"
        case .sea:   return "water.waves.and.arrow.trianglehead.up"
        }
    }

    var displayName: String {
        switch self {
        case .lake:  return "See"
        case .river: return "Fluss"
        case .sea:   return "Meer"
        }
    }
}
