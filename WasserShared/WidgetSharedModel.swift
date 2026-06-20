import Foundation

/// Data shared between the app and the widget extension.
///
/// The widget runs in its own process and must stay lightweight, so it never
/// touches the GKD scraper or WeatherKit. Instead the app fetches as usual and
/// writes a compact `WidgetSnapshot` into the shared App Group container; the
/// widget only reads and renders it. The widget is intentionally
/// non-configurable: it always shows the first station from the saved
/// favourites — the user changes which one by reordering the list in the
/// app.
public enum WidgetSharedStore {
    /// Must match the App Group capability enabled on both targets.
    public static let appGroupID = "group.com.wasser.app"
    private static let snapshotKey = "widget_snapshot_v1"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    public static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    public static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

/// Everything the widgets need for every saved water body, plus the chosen
/// temperature unit, captured the last time the app refreshed.
public struct WidgetSnapshot: Codable, Hashable, Sendable {
    public var stations: [WidgetStation]
    public var useFahrenheit: Bool
    public var generatedAt: Date

    public init(stations: [WidgetStation], useFahrenheit: Bool, generatedAt: Date) {
        self.stations = stations
        self.useFahrenheit = useFahrenheit
        self.generatedAt = generatedAt
    }
}

/// One saved water body as the widget sees it.
public struct WidgetStation: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String           // display water-body name, e.g. "Tegernsee"
    public var subtitle: String       // measuring point, e.g. "Gmund"
    public var currentTemp: Double     // °C
    public var todayHigh: Double?      // °C
    public var todayLow: Double?       // °C
    public var windSpeedKmh: Double?
    public var windCompass: String?
    public var waterLevelCm: Double?
    public var conditionText: String   // e.g. "Erfrischend · steigend"
    /// Last ~24h of water temperature (°C), oldest → newest, for the chart widget.
    public var hourly: [WidgetPoint]
    /// Theme colours (0–1 RGB) so the widget can draw the matching gradient
    /// without importing the app's `WaterTheme`.
    public var deepRGB: [Double]
    public var shallowRGB: [Double]
    public var updatedAt: Date

    public init(id: String, name: String, subtitle: String, currentTemp: Double,
                todayHigh: Double?, todayLow: Double?, windSpeedKmh: Double?,
                windCompass: String?, waterLevelCm: Double?, conditionText: String,
                hourly: [WidgetPoint], deepRGB: [Double], shallowRGB: [Double],
                updatedAt: Date) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.currentTemp = currentTemp
        self.todayHigh = todayHigh
        self.todayLow = todayLow
        self.windSpeedKmh = windSpeedKmh
        self.windCompass = windCompass
        self.waterLevelCm = waterLevelCm
        self.conditionText = conditionText
        self.hourly = hourly
        self.deepRGB = deepRGB
        self.shallowRGB = shallowRGB
        self.updatedAt = updatedAt
    }
}

/// One timestamped temperature reading for the chart widget.
public struct WidgetPoint: Codable, Hashable, Sendable {
    public var t: Date
    public var v: Double
    public init(t: Date, v: Double) { self.t = t; self.v = v }
}

