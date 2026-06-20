import WidgetKit
import SwiftUI

/// The widget extension's entry point. Only the compact water-temperature
/// widget is exposed for now; the detail and chart widgets are defined below
/// but intentionally not registered here.
@main
struct WasserWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CurrentTemperatureWidget()
    }
}

// MARK: - Timeline

/// The widget is non-configurable — it always renders the first station
/// from the saved favourites. The user changes which body of water the
/// widget shows by reordering the list inside the app.

struct WaterEntry: TimelineEntry {
    let date: Date
    let station: WidgetStation?
    let useFahrenheit: Bool
}

struct Provider: TimelineProvider {
    typealias Entry = WaterEntry

    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: Date(), station: .preview, useFahrenheit: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        let entry = currentEntry()
        // The app refreshes the snapshot; ask WidgetKit to revisit hourly so a
        // widget left on screen still ages forward if the app hasn't run.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    /// First station from the shared snapshot, or `nil` if there are no
    /// favourites yet (the widget renders an empty-state view in that case).
    private func currentEntry() -> WaterEntry {
        let snapshot = WidgetSharedStore.load()
        return WaterEntry(date: Date(),
                          station: snapshot?.stations.first,
                          useFahrenheit: snapshot?.useFahrenheit ?? false)
    }
}

// MARK: - Widgets

/// 1) Current temperature + today's high/low (small).
struct CurrentTemperatureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WasserCurrentTemperature", provider: Provider()) { entry in
            CurrentTemperatureView(entry: entry)
                .waterContainerBackground(entry.station)
        }
        .configurationDisplayName("Wassertemperatur")
        .description("Aktuelle Wassertemperatur mit Tageshoch und -tief.")
        .supportedFamilies([.systemSmall])
    }
}

/// 2) Current temperature + high/low + wind + water level (medium).
struct DetailConditionsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WasserDetailConditions", provider: Provider()) { entry in
            DetailConditionsView(entry: entry)
                .waterContainerBackground(entry.station)
        }
        .configurationDisplayName("Gewässer – Details")
        .description("Temperatur, Hoch/Tief, Wind und Wasserstand.")
        .supportedFamilies([.systemMedium])
    }
}

/// 3) Current temperature + high/low + 24-hour line chart (medium & large).
struct ChartWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WasserChart", provider: Provider()) { entry in
            ChartWidgetView(entry: entry)
                .waterContainerBackground(entry.station)
        }
        .configurationDisplayName("Gewässer – Tagesverlauf")
        .description("Temperatur mit dem Verlauf der letzten 24 Stunden.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
