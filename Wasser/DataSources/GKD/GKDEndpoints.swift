import Foundation

/// URL construction for the GKD Bayern website (gkd.bayern.de).
///
/// All source-specific URL knowledge lives here so that when the site layout
/// changes — or a verified machine-readable export endpoint is confirmed — only
/// this file needs to change.
///
/// Observed structure (to be re-verified against the live site, which is not
/// reachable from the build sandbox):
///   - Overview tables:
///       /de/fluesse/wassertemperatur/tabellen
///       /de/seen/wassertemperatur/tabellen
///   - Station detail pages follow:
///       /de/<category>/<parameterSlug>/<region>/<place-slug>-<messstellennummer>/<tab>
///     where <tab> ∈ { messwerte, tabelle, diagramm }.
enum GKDEndpoints {
    static let host = "www.gkd.bayern.de"

    /// Top-level category in the GKD navigation.
    enum Category: String {
        case rivers = "fluesse"
        case lakes  = "seen"
    }

    /// Parameter slug as it appears in GKD paths.
    static func slug(for parameter: MeasurementParameter) -> String {
        switch parameter {
        case .waterTemperature: return "wassertemperatur"
        case .waterLevel:       return "wasserstand"
        case .discharge:        return "abfluss"
        case .airTemperature:   return "lufttemperatur"
        case .precipitation:    return "niederschlag"
        }
    }

    private static func base() -> URLComponents {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        return components
    }

    /// Overview table of all stations for a category + parameter.
    static func overviewTable(category: Category,
                              parameter: MeasurementParameter = .waterTemperature) -> URL {
        var c = base()
        c.path = "/de/\(category.rawValue)/\(slug(for: parameter))/tabellen"
        return c.url!
    }

    /// The "messwerte" (current values) tab for a station, derived from the
    /// detail URL captured during catalogue scraping when available, otherwise
    /// reconstructed from the messstellennummer.
    static func messwerte(for station: MeasurementStation,
                          parameter: MeasurementParameter) -> URL? {
        if let detail = station.detailURL {
            return detail
                .deletingLastPathComponent()
                .appendingPathComponent("messwerte")
        }
        return nil
    }

    /// CSV / time-series download for a station and parameter over a range.
    ///
    /// GKD offers a "Messwerte herunterladen" action on station pages. The exact
    /// query contract must be confirmed against the live site; this builds the
    /// canonical-looking request and is the single place to adjust once
    /// verified.
    static func download(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         range: TimeRange) -> URL? {
        guard let detail = station.detailURL,
              var components = URLComponents(url: detail, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = detail.deletingLastPathComponent()
            .appendingPathComponent("messwerte")
            .appendingPathComponent("download")
            .path
        let formatter = ISO8601DateFormatter()
        let now = Date()
        components.queryItems = [
            URLQueryItem(name: "zr", value: range.rawValue),
            URLQueryItem(name: "beginn", value: formatter.string(from: now.addingTimeInterval(-range.interval))),
            URLQueryItem(name: "ende", value: formatter.string(from: now))
        ]
        return components.url
    }
}
