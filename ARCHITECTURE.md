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

## Outstanding

- **Design import is pending** — the `claude_design` connector was not connected
  in the session that scaffolded this. Run `/design-login`, then the
  `Wassertemperatur.dc.html` design replaces the placeholder views. The data
  layer is design-independent and ready to bind.
- WeatherKit needs the capability/entitlement on the App ID and a paid developer
  account to return data at runtime.
