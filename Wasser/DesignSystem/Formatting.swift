import SwiftUI

/// The temperature unit the user selected in the list's "•••" menu. Stored in
/// `@AppStorage("useFahrenheit")` and threaded through the view tree via the
/// environment so every temperature readout updates together when it changes.
enum TemperatureUnit: String {
    case celsius, fahrenheit

    /// Converts a Celsius value (the unit everything is stored/measured in) into
    /// the display unit.
    func convert(_ celsius: Double) -> Double {
        self == .fahrenheit ? celsius * 9 / 5 + 32 : celsius
    }

    /// Converts a temperature *difference* (e.g. an axis span). Differences only
    /// scale by 9/5 in Fahrenheit — they carry no +32 offset.
    func convertDelta(_ celsiusDelta: Double) -> Double {
        self == .fahrenheit ? celsiusDelta * 9 / 5 : celsiusDelta
    }
}

private struct TemperatureUnitKey: EnvironmentKey {
    static let defaultValue: TemperatureUnit = .celsius
}

extension EnvironmentValues {
    var temperatureUnit: TemperatureUnit {
        get { self[TemperatureUnitKey.self] }
        set { self[TemperatureUnitKey.self] = newValue }
    }
}

/// Number formatting helpers matching the design mock (German locale, comma
/// decimal separator).
enum Fmt {
    /// Rounded integer, e.g. 18.4 → "18".
    static func f0(_ value: Double) -> String { String(Int(value.rounded())) }

    /// One decimal place with comma, e.g. 18.42 → "18,4".
    static func f1(_ value: Double) -> String {
        String(format: "%.1f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// Two decimal places with comma, e.g. 584.0 → "584,00". Used for
    /// "m ü. NN" water-level readings where centimetre-scale variation
    /// matters.
    static func f2(_ value: Double) -> String {
        String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    /// A Celsius temperature rendered in the chosen unit as a rounded integer,
    /// e.g. 18.4 °C → "18" or, in Fahrenheit, "65".
    static func temp0(_ celsius: Double, _ unit: TemperatureUnit) -> String {
        f0(unit.convert(celsius))
    }

    /// A Celsius temperature rendered in the chosen unit to one decimal.
    static func temp1(_ celsius: Double, _ unit: TemperatureUnit) -> String {
        f1(unit.convert(celsius))
    }

    /// "HH:mm" in the Bavarian timezone.
    static func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    /// "HH:mm" rounded to the nearest half hour (e.g. 11:13 → "11:00",
    /// 11:18 → "11:30"). Berlin's offset is a whole hour, so rounding in
    /// absolute time lands cleanly on wall-clock :00/:30 marks.
    static func timeHalfHour(_ date: Date) -> String {
        let halfHour: TimeInterval = 30 * 60
        let snapped = (date.timeIntervalSinceReferenceDate / halfHour).rounded() * halfHour
        return time(Date(timeIntervalSinceReferenceDate: snapped))
    }

    /// Hour label for the hourly strip, e.g. 14 → "14".
    static func hour(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = TimeZone(identifier: "Europe/Berlin")
        f.dateFormat = "H"
        return f.string(from: date)
    }

    private static let berlin = TimeZone(identifier: "Europe/Berlin")!

    /// Short German weekday, e.g. "Mo", "Di".
    static func weekdayShort(_ date: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = berlin
        let idx = cal.component(.weekday, from: date) - 1
        return ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"][idx]
    }

    /// True if `date` is today in the Bavarian timezone.
    static func isToday(_ date: Date) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = berlin
        return cal.isDateInToday(date)
    }
}
