import Foundation
import WidgetKit

/// Builds the compact `WidgetSnapshot` from the saved stations and writes it to
/// the shared App Group container, then asks WidgetKit to reload. The widget
/// extension reads that snapshot instead of touching the scraper/WeatherKit, so
/// it stays cheap and offline-safe.
extension WaterRepository {
    /// Refreshes the data the home-screen widgets render for every saved water
    /// body. Safe to call fire-and-forget; failures for one station are skipped.
    func publishWidgetData() async {
        let stations = favoriteStations
        guard !stations.isEmpty else {
            WidgetSharedStore.save(WidgetSnapshot(stations: [],
                                                  useFahrenheit: UserDefaults.standard.bool(forKey: "useFahrenheit"),
                                                  generatedAt: Date()))
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        var entries: [WidgetStation] = []
        for station in stations {
            // Always include every favorite so the widget picker can offer
            // them, even if their conditions fetch fails. Placeholders are
            // used for missing readings instead of silently dropping the
            // station — otherwise the user picks a station in Edit Widget
            // and the lookup falls back to "first".
            let conditions = try? await self.conditions(for: station)
            let series = try? await timeSeries(for: station, parameter: .waterTemperature, range: .day)
            let recent = series?.points ?? []
            let temp = conditions?.waterTemperature?.value ?? series?.latest?.value ?? 0

            let hourly: [WidgetPoint]
            if let newest = recent.last?.timestamp {
                let cutoff = newest.addingTimeInterval(-24 * 60 * 60)
                hourly = recent.filter { $0.timestamp >= cutoff }
                    .map { WidgetPoint(t: $0.timestamp, v: $0.value) }
            } else {
                hourly = []
            }

            let today = (try? await dailyTrend(for: station, parameter: .waterTemperature, days: 1))?.first

            let warmth = min(1, max(0, (temp - 8) / 20))
            let theme = WaterTheme.forType(station.waterBodyType)
                .varied(seed: station.appearanceSeed, warmth: warmth)

            let comfort = ConditionEnrichment.comfort(forWaterTemperature: temp)
            let trend = ConditionEnrichment.trend(from: recent)
            let conditionText = trend == .steady ? comfort.rating : "\(comfort.rating) · \(trend.label)"

            entries.append(WidgetStation(
                id: station.id,
                name: station.displayWaterBodyName,
                subtitle: station.locationSubtitle,
                currentTemp: temp,
                todayHigh: today?.high,
                todayLow: today?.low,
                windSpeedKmh: conditions?.weather?.windSpeed,
                windCompass: conditions?.weather?.windCompass,
                waterLevelCm: conditions?.waterLevel?.value,
                conditionText: conditionText,
                hourly: hourly,
                deepRGB: [theme.deepRGB.0, theme.deepRGB.1, theme.deepRGB.2],
                shallowRGB: [theme.shallowRGB.0, theme.shallowRGB.1, theme.shallowRGB.2],
                updatedAt: conditions?.observationTime ?? conditions?.fetchedAt ?? Date()))
        }

        let useFahrenheit = UserDefaults.standard.bool(forKey: "useFahrenheit")
        WidgetSharedStore.save(WidgetSnapshot(stations: entries,
                                              useFahrenheit: useFahrenheit,
                                              generatedAt: Date()))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
