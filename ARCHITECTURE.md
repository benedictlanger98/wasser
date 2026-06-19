# Wasser — Architecture

A SwiftUI app for water data (temperature, level, discharge) of Bavarian lakes
and rivers, sourced from the Gewässerkundlicher Dienst Bayern (GKD,
gkd.bayern.de), enriched with WeatherKit.

The guiding goal is **adaptability**: new data sources, parameters and weather
providers can be added without rippling through the app.

## Layers

```
Views / ViewModels        SwiftUI screens (placeholder until the design import)
        │
WaterRepository           @MainActor façade: caching, favourites, search
        │
DataSourceRegistry        actor; routes each station to its owning source,
        │                 merges stations across sources
        ▼
WaterDataSource (protocol)        ◄── the key seam
   ├── GKDBayernDataSource         live GKD scraping + WeatherKit decoration
   │      ├── GKDScraper           transport orchestration
   │      ├── GKDEndpoints         all URL knowledge
   │      ├── GKDParser            HTML/CSV parsing (dependency-free)
   │      └── GKDStationCatalog    bundled seed of real Bavarian water bodies
   └── MockWaterDataSource         deterministic, offline previews/tests

HTTPClient (protocol)     injectable transport (URLSession impl sets the
                          browser User-Agent GKD requires)

WeatherProvider (protocol)
   ├── WeatherKitProvider  Apple WeatherKit (wrapped in canImport)
   └── NoWeatherProvider   null object
```

### Why these seams

- **`WaterDataSource`** — adding a provider (e.g. Switzerland, Austria) is a new
  conformer registered in `AppEnvironment`. Nothing above the registry changes.
- **A different scraper later** — `GKDScraper`/`GKDParser`/`GKDEndpoints` isolate
  every brittle detail (URLs, markup, CSV shape). If GKD ships a confirmed JSON
  API, only `GKDScraper` changes.
- **WeatherKit** — the app depends on the `WeatherSnapshot` value type and the
  `WeatherProvider` protocol, never on WeatherKit types directly.
- **Parameters** — `MeasurementParameter` is the single place that defines
  units, symbols and formatting; new quantities (pH, oxygen, …) drop in here.

## ⚠️ Scraper assumptions to verify

The build sandbox cannot reach `www.gkd.bayern.de` (blocked by the network
egress allowlist) and there is no macOS/Swift toolchain here, so the scraper was
written to GKD's documented/observed structure and **has not been run against
live data**. Verify and adjust, in order of likelihood:

1. **Overview table columns** (`GKDParser.parseOverviewTable`) — confirm which
   `<td>` holds the station name vs. water body vs. current value.
2. **Detail / data URLs** (`GKDEndpoints.messwerte`, `.download`) — confirm the
   `messwerte` tab path and whether a CSV download endpoint + query params exist.
   The download path/params are a best guess.
3. **CSV / table format** (`GKDParser.parseCSV`, `.parseMeasurementTable`) —
   confirm separator (`;`), German decimal comma, and `dd.MM.yyyy HH:mm`
   timestamps in `Europe/Berlin`.
4. **Coordinates** — the overview table has no lat/lon; scraped stations get
   `(0,0)` and should be enriched from the detail page or matched to the seed
   catalogue. The seed coordinates are approximate town/lake centroids.

Until verified, `GKDStationCatalog` guarantees the library is never empty, and
`MockWaterDataSource` powers previews offline.

## Project format

The Xcode project uses a **file-system-synchronized root group** (Xcode 16,
`objectVersion = 77`): every file under `Wasser/` is compiled automatically, so
adding Swift files needs no `project.pbxproj` edits.

## UI — implemented from the design

The `Wassertemperatur.dc.html` handoff (an Apple-Weather-style concept) is built
in SwiftUI under `Views/` + `DesignSystem/`:

- **Detail** (`Views/Detail/`) — animated water hero (`WaterHeroBackground`, a
  `TimelineView`+`Canvas` port of the mock's WebGL caustics), hero header,
  hourly strip, 10-day trend, and the two-column condition grid (Luft & Wasser,
  UV, Wind, Wasserqualität, Sonnenauf-/untergang; Strömung for rivers,
  Wellenhöhe/Gezeiten for sea). Cards use the frosted `GlassCard`.
- **List** (`Views/List/`) — saved-location gradient cards with shimmer.
- **Search** (`Views/Search/`) — system keyboard (the mock's drawn keyboard is a
  web artifact), live filtering over the catalogue, tap-to-save.
- **Root** (`Views/Root/`) — swipeable detail pager with the custom bottom bar
  (search · page dots · list) and sliding screen transitions, driven by
  `AppRouter`.

Per-type colour themes (`WaterTheme`) are ported verbatim from the mock.

## Outstanding

- **Visuals are render-unverified** — there is no macOS/Swift toolchain in this
  environment, so the SwiftUI was written but not compiled or run. Build in
  Xcode 16+ and reconcile against the mock screenshots.
- **WeatherKit** needs the capability/entitlement on the App ID and a paid
  developer account to return data at runtime; without it the weather cards
  show "–". Previews use `MockWeatherProvider`.
- The scraper assumptions in the section above still require live verification.
