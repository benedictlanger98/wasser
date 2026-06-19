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
            let stationName = stripTags(cells[0])
            let waterBodyName = cells.count > 1 ? stripTags(cells[1]) : ""
            let value = cells.compactMap { germanDouble(stripTags($0)) }.first

            guard !stationName.isEmpty else { continue }
            rows.append(OverviewRow(stationName: stationName,
                                    waterBodyName: waterBodyName,
                                    detailURL: detailURL,
                                    currentValue: value,
                                    region: nil))
        }
        return rows
    }

    // MARK: - Measurement (time series) table

    /// Parses a "Messwerte" table of timestamp/value pairs. Timestamps on GKD
    /// are local German time formatted as `dd.MM.yyyy HH:mm`.
    static func parseMeasurementTable(html: String,
                                      parameter: MeasurementParameter) -> [Measurement] {
        var measurements: [Measurement] = []
        for rowHTML in tagContents(of: "tr", in: html) {
            let cells = tagContents(of: "td", in: rowHTML).map { stripTags($0) }
            guard cells.count >= 2,
                  let date = germanDateTime(cells[0]),
                  let value = germanDouble(cells[1]) else { continue }
            measurements.append(Measurement(parameter: parameter, timestamp: date, value: value))
        }
        return measurements
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

    static func germanDateTime(_ string: String) -> Date? {
        germanDateFormatter.date(from: string.trimmingCharacters(in: .whitespaces))
    }
}
