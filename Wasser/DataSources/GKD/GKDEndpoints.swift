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

    /// A data view ("tab") on a GKD station page. Verified live 2026-06:
    /// these are sibling paths under the same station, e.g.
    /// `.../<station>/messwerte/tabelle`, `.../<station>/jahreswerte/tabelle`.
    /// The `/jahreswerte/tabelle` view returns the actual daily mean/max/min
    /// numbers used by the Jahresmittel calculation — the bare `/jahreswerte`
    /// path was the chart view and didn't always agree with the table.
    enum Tab {
        case recentTable   // messwerte/tabelle — recent 15-min readings
        case yearTable     // jahreswerte/tabelle — daily mean/max/min over the year

        var path: String {
            switch self {
            case .recentTable: return "messwerte/tabelle"
            case .yearTable:   return "jahreswerte/tabelle"
            }
        }
    }

    /// URL that serves the station's Stammdaten (master-data) section. The
    /// bare detail URL — `/de/<category>/<paramSlug>/<region>/<station>` —
    /// already renders the Stammdaten table inline (incl. Nordwert / Ostwert),
    /// so we just strip any trailing tab suffix (`messwerte/tabelle`, …) from
    /// the stored detailURL and return the canonical path.
    static func stammdataURL(for station: MeasurementStation) -> URL? {
        guard let detail = station.detailURL else { return nil }
        let comps = detail.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard let stationIdx = comps.firstIndex(where: {
                  $0.range(of: "[0-9]{3,}$", options: .regularExpression) != nil
              }) else { return nil }
        let parts = Array(comps[0...stationIdx])
        var c = base()
        c.path = "/" + parts.joined(separator: "/")
        return c.url
    }

    /// Builds the URL of a data tab for a *given parameter* at the same physical
    /// station as `station.detailURL`. Verified live 2026-06: water level and
    /// discharge for one location reuse the very same Messstellennummer — only
    /// the parameter slug in the path changes
    /// (`.../<category>/<paramSlug>/<region>/<station>/<tab>`), so we swap that
    /// one path component and append the tab.
    static func dataURL(for station: MeasurementStation,
                        parameter: MeasurementParameter,
                        tab: Tab) -> URL? {
        guard let detail = station.detailURL else { return nil }
        let comps = detail.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        // station component = trailing "...-<number>"; the parameter slug sits
        // two segments earlier (.../<category>/<paramSlug>/<region>/<station>).
        guard let stationIdx = comps.firstIndex(where: {
                  $0.range(of: "[0-9]{3,}$", options: .regularExpression) != nil
              }), stationIdx >= 2 else { return nil }
        var parts = Array(comps[0...stationIdx])
        parts[stationIdx - 2] = slug(for: parameter)
        var c = base()
        c.path = "/" + parts.joined(separator: "/") + "/" + tab.path
        return c.url
    }

}
