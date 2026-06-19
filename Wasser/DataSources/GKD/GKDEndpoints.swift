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

    /// The "messwerte" (current values) tab for a station.
    ///
    /// Verified live 2026-06: overview links already point straight at the
    /// messwerte tab (".../<place-slug>-<nr>/messwerte?method=tabellen"), so the
    /// captured detail URL is used as-is — preserving its query, which selects
    /// the table view. Only a bare station URL gets the tab appended.
    static func messwerte(for station: MeasurementStation,
                          parameter: MeasurementParameter) -> URL? {
        guard let detail = station.detailURL else { return nil }
        if detail.lastPathComponent == "messwerte" { return detail }
        return detail.appendingPathComponent("messwerte")
    }

    /// CSV / time-series download endpoint for a station.
    ///
    /// Verified live 2026-06: the download lives at a sibling of "messwerte"
    /// (".../<place-slug>-<nr>/download"), NOT at ".../messwerte/download". The
    /// page is a POST form gated by mandatory terms/privacy checkboxes; it
    /// exports ISO-8859-1 CSV, offers only fixed periods (Aktueller Monat /
    /// Aktuelles Jahr / Gesamtzeitraum) and delivers custom ranges
    /// asynchronously by e-mail — so a plain GET with date-range query params
    /// (the previous guess) cannot drive it. This returns the canonical
    /// endpoint URL; `GKDScraper.timeSeries` treats it as best-effort and falls
    /// back to scraping the rendered table when the GET yields no CSV. Wire up
    /// the POST contract here once it is implemented.
    static func download(for station: MeasurementStation,
                         parameter: MeasurementParameter,
                         range: TimeRange) -> URL? {
        guard let detail = station.detailURL else { return nil }
        let stationDir = detail.lastPathComponent == "messwerte"
            ? detail.deletingLastPathComponent()
            : detail
        guard var components = URLComponents(
            url: stationDir.appendingPathComponent("download"),
            resolvingAgainstBaseURL: false) else { return nil }
        components.query = nil
        return components.url
    }
}
