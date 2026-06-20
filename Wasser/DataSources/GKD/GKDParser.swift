import CoreLocation
import Foundation

/// Stateless parsing helpers for GKD content, isolated from transport so they
/// can be exercised against captured HTML/CSV fixtures in tests without a
/// network. Dependency-free on purpose (no SwiftSoup): the parsers are
/// intentionally forgiving and centralised so markup changes touch one file.
///
/// NOTE: The GKD site is not reachable from the build sandbox, so the concrete
/// selectors below encode the documented/observed structure and are marked for
/// verification. Swapping in a more robust HTML library later only affects this
/// type.
enum GKDParser {

    // MARK: - Overview table

    /// A row scraped from an overview table page.
    struct OverviewRow {
        let stationName: String
        let waterBodyName: String
        let detailURL: URL?
        let currentValue: Double?
        let timestamp: Date?
        let region: String?
    }

    /// Parses the station overview table. The GKD table renders one `<tr>` per
    /// station with cells for the measuring point, water body, current value
    /// and a link to the detail page.
    static func parseOverviewTable(html: String, baseURL: URL) -> [OverviewRow] {
        var rows: [OverviewRow] = []
        for rowHTML in tagContents(of: "tr", in: html) {
            let cells = tagContents(of: "td", in: rowHTML)
            guard cells.count >= 2 else { continue }

            let link = firstHref(in: rowHTML)
            let detailURL = link.flatMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
            // Columns (verified live 2026-06): Messstelle | Gewässer | Lkr. |
            // Datum | <value>. The current value is the right-most numeric cell
            // (the date cell never parses as a number), and the Landkreis
            // abbreviation in column 3 is the only region hint the table gives.
            let stationName = spacedName(stripTags(cells[0]))
            let waterBodyName = cells.count > 1 ? spacedName(stripTags(cells[1])) : ""
            let district = cells.count > 2 ? stripTags(cells[2]) : ""
            let value = cells.reversed().compactMap { germanDouble(stripTags($0)) }.first
            // The "Datum" column carries the observation time of the current
            // value; it's the only timestamp the overview offers.
            let timestamp = cells.lazy.compactMap { germanDateTime(stripTags($0)) }.first

            guard !stationName.isEmpty else { continue }
            rows.append(OverviewRow(stationName: stationName,
                                    waterBodyName: waterBodyName,
                                    detailURL: detailURL,
                                    currentValue: value,
                                    timestamp: timestamp,
                                    region: district.isEmpty ? nil : district))
        }
        return rows
    }

    // MARK: - Stammdaten (station master data)

    /// Raw coordinates read off a GKD "Stammdaten" page. Nordwert is the
    /// northing, Ostwert the easting; the projection is detected downstream by
    /// the magnitude of the easting (GK4 vs UTM 32N).
    struct StammdatenLocation: Sendable {
        let nordwert: Double
        let ostwert: Double
    }

    /// Pulls Nordwert and Ostwert from a Stammdaten HTML page. Lenient: the
    /// labels can be in `<th>`/`<td>` pairs or inline, and the numbers may be
    /// German-formatted ("5.400.000,12") — anything `germanDouble` accepts.
    static func parseStammdaten(html: String) -> StammdatenLocation? {
        func value(after label: String) -> Double? {
            // Find the label, then the next German-number token. `.dotMatchesLineSeparators`
            // lets the gap between the label cell and the value cell span tags
            // and whitespace.
            let pattern = "\(label)\\b.*?(-?\\d[\\d.,]*)"
            guard let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return nil }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, range: range),
                  match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { return nil }
            return germanDouble(String(html[r]))
        }
        guard let nord = value(after: "Nordwert"),
              let ost = value(after: "Ostwert") else { return nil }
        return StammdatenLocation(nordwert: nord, ostwert: ost)
    }

    // MARK: - Measurement (time series) table

    /// Parses a "Messwerte" table of timestamp/value pairs. Timestamps on GKD
    /// are local German time formatted as `dd.MM.yyyy HH:mm`. The unit (if
    /// declared in a column header) is attached to each parsed Measurement so
    /// downstream cards can label e.g. "584,00 m ü. NN" vs. "132 cm".
    static func parseMeasurementTable(html: String,
                                      parameter: MeasurementParameter) -> [Measurement] {
        let unit = parseUnit(html: html)
        var measurements: [Measurement] = []
        for rowHTML in tagContents(of: "tr", in: html) {
            let cells = tagContents(of: "td", in: rowHTML).map { stripTags($0) }
            guard cells.count >= 2 else { continue }
            // Be tolerant of extra columns. Some station tables carry a leading
            // index, a trailing unit, or a multi-column layout, so don't assume
            // the timestamp is column 0 and the value is column 1: take the
            // first cell that parses as a datetime and the right-most other cell
            // that parses as a number (mirroring the overview table's logic).
            guard let dateIdx = cells.firstIndex(where: { germanDateTime($0) != nil }) else { continue }
            let date = germanDateTime(cells[dateIdx])!
            guard let value = cells.enumerated().reversed()
                    .first(where: { $0.offset != dateIdx && germanDouble($0.element) != nil })
                    .map({ germanDouble($0.element)! }) else { continue }
            measurements.append(Measurement(parameter: parameter, timestamp: date, value: value, unit: unit))
        }
        return measurements
    }

    /// Pulls the first plausible unit string out of the table HTML's column
    /// headers. GKD wraps the unit in square brackets next to the parameter
    /// label, e.g. `<th>Wasserstand [cm]</th>` or `<th>Wasserstand [m ü. NN]</th>`.
    /// Restricted to a small known set so a stray "[…]" elsewhere on the page
    /// can't be mistaken for a unit.
    static func parseUnit(html: String) -> String? {
        let known: [String] = ["m ü. NN", "m\u{00FC}. NN", "m³/s", "cm", "l/s", "°C", "m"]
        let pattern = "\\[\\s*([^\\[\\]]+?)\\s*\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: [.dotMatchesLineSeparators]) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for match in regex.matches(in: html, range: range) {
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: html) else { continue }
            let candidate = String(html[r]).trimmingCharacters(in: .whitespaces)
            // Allow whitespace flex: normalise "m ü.NN" / "m ü. NN" etc.
            let normalised = candidate.replacingOccurrences(of: "\\s+",
                                                            with: " ",
                                                            options: .regularExpression)
            if known.contains(where: { $0.compare(normalised, options: .caseInsensitive) == .orderedSame }) {
                return normalised
            }
        }
        return nil
    }

    /// Parses a GKD CSV export (semicolon-separated, German decimal commas,
    /// `dd.MM.yyyy HH:mm` timestamps). Header/comment lines are skipped.
    static func parseCSV(_ text: String, parameter: MeasurementParameter) -> [Measurement] {
        var result: [Measurement] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let columns = line.split(separator: ";", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard columns.count >= 2,
                  let date = germanDateTime(columns[0]),
                  let value = germanDouble(columns[1]) else { continue }
            result.append(Measurement(parameter: parameter, timestamp: date, value: value))
        }
        return result
    }

    /// Parses a GKD "Jahresgrafik"/Tageswerte table whose rows are
    /// `Datum | Mittel | Maximum | Minimum` at daily resolution (date only, no
    /// time). Verified live 2026-06.
    static func parseDailyTable(html: String) -> [DailyAggregate] {
        var result: [DailyAggregate] = []
        for rowHTML in tagContents(of: "tr", in: html) {
            let cells = tagContents(of: "td", in: rowHTML).map { stripTags($0) }
            guard cells.count >= 4,
                  let date = germanDate(cells[0]),
                  let mean = germanDouble(cells[1]) else { continue }
            let high = germanDouble(cells[2]) ?? mean
            let low = germanDouble(cells[3]) ?? mean
            result.append(DailyAggregate(date: date, mean: mean, high: high, low: low))
        }
        return result
    }

    // MARK: - Lightweight HTML helpers

    /// Returns the inner HTML of every `<tag ...>...</tag>` occurrence.
    static func tagContents(of tag: String, in html: String) -> [String] {
        let pattern = "<\(tag)\\b[^>]*>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern,
                                                   options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        return regex.matches(in: html, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: html) else { return nil }
            return String(html[r])
        }
    }

    /// Inserts a space where a lowercase letter is immediately followed by an
    /// uppercase one ("StarnbergerSee" → "Starnberger See"); GKD sometimes drops
    /// the space in compound water-body names.
    static func spacedName(_ string: String) -> String {
        string.replacingOccurrences(of: "(?<=\\p{Ll})(?=\\p{Lu})",
                                    with: " ",
                                    options: .regularExpression)
    }

    /// First `href` attribute value found in a fragment.
    static func firstHref(in html: String) -> String? {
        let pattern = "href\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[r])
    }

    /// Removes tags and collapses whitespace; decodes the few HTML entities GKD
    /// pages use in labels.
    static func stripTags(_ html: String) -> String {
        let withoutTags = html.replacingOccurrences(of: "<[^>]+>",
                                                     with: " ",
                                                     options: .regularExpression)
        let decoded = withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&ouml;", with: "ö")
            .replacingOccurrences(of: "&auml;", with: "ä")
            .replacingOccurrences(of: "&uuml;", with: "ü")
            .replacingOccurrences(of: "&szlig;", with: "ß")
        return decoded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - German number / date parsing

    /// Parses German-formatted decimals ("12,3" → 12.3). Returns nil for
    /// placeholders like "-" or empty strings.
    static func germanDouble(_ string: String) -> Double? {
        let cleaned = string
            .replacingOccurrences(of: ".", with: "")   // thousands separator
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned != "-" else { return nil }
        return Double(cleaned)
    }

    private static let germanDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter
    }()

    private static let germanDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(identifier: "Europe/Berlin")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    /// Parses a date-only German timestamp ("19.06.2026").
    static func germanDate(_ string: String) -> Date? {
        germanDayFormatter.date(from: string.trimmingCharacters(in: .whitespaces))
    }

    static func germanDateTime(_ string: String) -> Date? {
        // Verified live 2026-06: GKD renders timestamps as
        // "dd.MM.yyyy HH:mm Uhr". Strip the trailing "Uhr" label (and any
        // surrounding whitespace) so the formatter gets an exact match —
        // otherwise every row is silently dropped.
        var cleaned = string.trimmingCharacters(in: .whitespaces)
        if cleaned.hasSuffix("Uhr") {
            cleaned = String(cleaned.dropLast(3)).trimmingCharacters(in: .whitespaces)
        }
        return germanDateFormatter.date(from: cleaned)
    }
}

/// Converts GKD Stammdaten coordinates (Nordwert / Ostwert) into WGS84
/// latitude / longitude.
///
/// Bavarian GKD pages publish coordinates in one of two projections:
///   - ETRS89 / UTM Zone 32N (easting 500k–900k, central meridian 9°E)
///   - DHDN / Gauss-Krüger Zone 4 (easting prefixed with the zone number, so
///     values land between 4.4M and 4.7M, central meridian 12°E)
///
/// They're distinguished here by the magnitude of the easting alone. The datum
/// shift between DHDN and WGS84 (~600 m in Bavaria) is ignored — close enough
/// for weather lookups against multi-kilometre forecast cells.
enum GKDProjection {

    private static let a: Double = 6_378_137.0            // WGS84 semi-major axis
    private static let f: Double = 1.0 / 298.257_223_563  // WGS84 flattening
    private static let e2: Double = f * (2 - f)
    private static let ep2: Double = e2 / (1 - e2)

    static func wgs84(nordwert: Double, ostwert: Double) -> CLLocationCoordinate2D? {
        // Detect the projection from the easting's order of magnitude.
        let centralMeridianDeg: Double
        let falseEasting: Double
        let scaleFactor: Double
        if ostwert > 3_000_000 {
            centralMeridianDeg = 12.0
            falseEasting = 4_500_000.0
            scaleFactor = 1.0
        } else {
            centralMeridianDeg = 9.0
            falseEasting = 500_000.0
            scaleFactor = 0.9996
        }

        let dE = ostwert - falseEasting
        let M = nordwert / scaleFactor

        // Footprint latitude φ1 (Snyder 1987, "Map Projections — A Working Manual",
        // §8 inverse Transverse Mercator).
        let e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))
        let mu = M / (a * (1 - e2/4 - 3*e2*e2/64 - 5*e2*e2*e2/256))
        let phi1 = mu
            + (3*e1/2 - 27*pow(e1, 3)/32) * sin(2*mu)
            + (21*pow(e1, 2)/16 - 55*pow(e1, 4)/32) * sin(4*mu)
            + (151*pow(e1, 3)/96) * sin(6*mu)

        let sinPhi1 = sin(phi1)
        let cosPhi1 = cos(phi1)
        let tanPhi1 = tan(phi1)
        let N1 = a / sqrt(1 - e2 * sinPhi1 * sinPhi1)
        let T1 = tanPhi1 * tanPhi1
        let C1 = ep2 * cosPhi1 * cosPhi1
        let R1 = a * (1 - e2) / pow(1 - e2 * sinPhi1 * sinPhi1, 1.5)
        let D = dE / (N1 * scaleFactor)

        let latRad = phi1
            - (N1 * tanPhi1 / R1) * (
                D*D/2
                - (5 + 3*T1 + 10*C1 - 4*C1*C1 - 9*ep2) * pow(D, 4)/24
                + (61 + 90*T1 + 298*C1 + 45*T1*T1 - 252*ep2 - 3*C1*C1) * pow(D, 6)/720
            )
        let lambda0 = centralMeridianDeg * .pi / 180
        let lonRad = lambda0
            + (D
               - (1 + 2*T1 + C1) * pow(D, 3) / 6
               + (5 - 2*C1 + 28*T1 - 3*C1*C1 + 8*ep2 + 24*T1*T1) * pow(D, 5) / 120
              ) / cosPhi1

        let lat = latRad * 180 / .pi
        let lon = lonRad * 180 / .pi
        // Sanity-check against Bavaria's geographic envelope; a result outside
        // it means the inputs were nonsense (wrong projection, parser glitch).
        guard lat.isFinite, lon.isFinite,
              (45...55).contains(lat), (5...16).contains(lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
