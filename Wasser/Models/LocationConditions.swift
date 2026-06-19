import Foundation

/// Swimming-comfort summary shown in the BADEHINWEIS card and folded into the
/// hero condition line.
///
/// Honest, data-backed: derived purely from the *real* water temperature (see
/// `ConditionEnrichment`), not a fabricated bathing-quality rating. GKD's
/// hydrology feed carries no bathing-quality / clarity data, so we surface a
/// comfort hint from the one quantity we actually measure.
struct SwimComfort: Hashable, Sendable {
    let rating: String        // e.g. "Angenehm"
    let note: String          // short caption
    let symbolName: String
}

/// Direction the water temperature is moving, used in the hero condition line.
enum WaterTrend: Sendable, Hashable {
    case rising, falling, steady

    var label: String {
        switch self {
        case .rising:  return "steigend"
        case .falling: return "fallend"
        case .steady:  return "gleichbleibend"
        }
    }

    var symbolName: String {
        switch self {
        case .rising:  return "arrow.up.right"
        case .falling: return "arrow.down.right"
        case .steady:  return "arrow.right"
        }
    }
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

/// One day in the 10-day trend.
struct DayTrend: Identifiable, Hashable, Sendable {
    let id = UUID()
    let date: Date
    let low: Double
    let high: Double
}

/// Everything the detail screen needs for one location, assembled from the
/// water data source, the weather provider and derived enrichment.
struct LocationConditions: Sendable {
    let station: MeasurementStation
    let waterTemperature: Double
    /// Recent water temperatures at 15-min resolution (oldest → newest).
    let hourly: [Measurement]
    /// Daily trend, newest first (today at index 0).
    let daily: [DayTrend]
    let weather: WeatherSnapshot?
    /// Swimming-comfort hint derived from the water temperature.
    let comfort: SwimComfort
    /// Direction of the water-temperature change (from the recent series).
    let trend: WaterTrend
    let marine: MarineInfo?
    let flow: FlowInfo?
    /// Latest water level (Wasserstand), shown for lakes and rivers.
    let waterLevel: Measurement?
    /// Annual mean water level (cm) for the ± deviation readout, if known.
    let waterLevelAnnualMean: Double?
    /// Latest discharge (Abfluss), shown for rivers.
    let discharge: Measurement?
    /// Annual mean discharge (m³/s) for the ± deviation readout, if known.
    let dischargeAnnualMean: Double?

    var theme: WaterTheme { WaterTheme.forType(station.waterBodyType) }
}
