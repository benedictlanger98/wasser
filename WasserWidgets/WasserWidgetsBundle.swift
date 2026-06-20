import WidgetKit
import SwiftUI
import AppIntents

/// The widget extension's entry point. Bundles the three configurable widgets:
/// a compact temperature widget, a detailed conditions widget, and a 24-hour
/// chart widget. Each lets the user pick which saved water body it shows.
@main
struct WasserWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CurrentTemperatureWidget()
        DetailConditionsWidget()
        ChartWidget()
    }
}

// MARK: - Configuration intent (pick a water body)

/// One selectable saved water body, sourced from the shared snapshot the app
/// writes. Backs the widget's "choose a body of water" configuration.
struct WaterBodyEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Gewässer"
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
    static var defaultQuery = WaterBodyQuery()
}

struct WaterBodyQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WaterBodyEntity] {
        all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [WaterBodyEntity] { all() }
    func defaultResult() async -> WaterBodyEntity? { all().first }

    private func all() -> [WaterBodyEntity] {
        (WidgetSharedStore.load()?.stations ?? [])
            .map { WaterBodyEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectWaterBodyIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Gewässer wählen"
    static var description = IntentDescription("Wähle das Gewässer, das dieses Widget anzeigt.")

    @Parameter(title: "Gewässer")
    var waterBody: WaterBodyEntity?
}

// MARK: - Timeline

struct WaterEntry: TimelineEntry {
    let date: Date
    let station: WidgetStation?
    let useFahrenheit: Bool
}

struct Provider: AppIntentTimelineProvider {
    typealias Entry = WaterEntry
    typealias Intent = SelectWaterBodyIntent

    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: Date(), station: .preview, useFahrenheit: false)
    }

    func snapshot(for configuration: SelectWaterBodyIntent, in context: Context) async -> WaterEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectWaterBodyIntent, in context: Context) async -> Timeline<WaterEntry> {
        let entry = entry(for: configuration)
        // The app refreshes the snapshot; ask WidgetKit to revisit hourly so a
        // widget left on screen still ages forward if the app hasn't run.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(next))
    }

    /// Resolves the configured water body (falling back to the first saved one)
    /// from the shared snapshot.
    private func entry(for configuration: SelectWaterBodyIntent) -> WaterEntry {
        let snapshot = WidgetSharedStore.load()
        let station = configuration.waterBody
            .flatMap { selected in snapshot?.stations.first { $0.id == selected.id } }
            ?? snapshot?.stations.first
        return WaterEntry(date: Date(),
                          station: station,
                          useFahrenheit: snapshot?.useFahrenheit ?? false)
    }
}

// MARK: - Widgets

/// 1) Current temperature + today's high/low (small).
struct CurrentTemperatureWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "WasserCurrentTemperature",
                               intent: SelectWaterBodyIntent.self,
                               provider: Provider()) { entry in
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
        AppIntentConfiguration(kind: "WasserDetailConditions",
                               intent: SelectWaterBodyIntent.self,
                               provider: Provider()) { entry in
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
        AppIntentConfiguration(kind: "WasserChart",
                               intent: SelectWaterBodyIntent.self,
                               provider: Provider()) { entry in
            ChartWidgetView(entry: entry)
                .waterContainerBackground(entry.station)
        }
        .configurationDisplayName("Gewässer – Tagesverlauf")
        .description("Temperatur mit dem Verlauf der letzten 24 Stunden.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
