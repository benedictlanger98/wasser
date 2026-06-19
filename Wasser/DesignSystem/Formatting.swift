import Foundation

/// Number formatting helpers matching the design mock (German locale, comma
/// decimal separator).
enum Fmt {
    /// Rounded integer, e.g. 18.4 → "18".
    static func f0(_ value: Double) -> String { String(Int(value.rounded())) }

    /// One decimal place with comma, e.g. 18.42 → "18,4".
    static func f1(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// "HH:mm" in the Bavarian timezone.
    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// Hour label for the hourly strip, e.g. 14 → "14".
    static func hour(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        f.dateFormat = "H"
        return f.string(from: date)
    }
}
