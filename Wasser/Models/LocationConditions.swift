import Foundation

/// Bathing-water-quality summary shown in the WASSERQUALITÄT card.
///
/// Not provided by GKD's hydrology feed. For Bavaria the authoritative source
/// is the LGL Badegewässer dataset; until that source is wired in, values are
/// derived deterministically from water body type + temperature (see
/// `ConditionEnrichment`). Modelled as its own type so swapping in a real
/// provider is isolated.
struct WaterQualityInfo: Hashable, Sendable {
    let rating: String        // e.g. "Ausgezeichnet"
    let note: String          // short caption
    let clarityMeters: Double // Sichttiefe
}

/// Sea-only marine extras (waves + tides). Placeholder until a marine source.
struct MarineInfo: Hashable, Sendable {
    let waveHeightMeters: Double
    let wavePeriodSeconds: Int
    let nextHighTide: String
    let nextLowTide: String
}

/// River-only flow summary, derived from GKD discharge where available.
struct FlowInfo: Hashable, Sendable {
    let speedMetersPerSecond: Double
    let direction: String
}

/// One bar in the 10-day trend.
struct DayTrend: Identifiable, Hashable, Sendable {
    let id = UUID()
    let label: String   // "Heute", "Mi", …
    let low: Double
    let high: Double
}

/// Everything the detail screen needs for one location, assembled from the
/// water data source, the weather provider and derived enrichment.
struct LocationConditions: Sendable {
    let station: MeasurementStation
    let waterTemperature: Double
    /// Recent hourly water temperatures (oldest → newest, "now" last).
    let hourly: [Measurement]
    let daily: [DayTrend]
    let weather: WeatherSnapshot?
    let quality: WaterQualityInfo
    let marine: MarineInfo?
    let flow: FlowInfo?

    var theme: WaterTheme { WaterTheme.forType(station.waterBodyType) }
}
