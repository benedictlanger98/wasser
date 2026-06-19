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

## Scraper — verified against live GKD (2026-06-19)

The scraper was originally written to GKD's documented/observed structure
without live access. It has now been verified against `www.gkd.bayern.de` and
the wrong assumptions corrected. Findings, in the order they were checked:

1. **Overview table columns** (`GKDParser.parseOverviewTable`) — ✅ confirmed
   five columns: `Messstelle | Gewässer | Lkr. | Datum | Wassertemperatur [°C]`.
   Station name (col 0) and water body (col 1) were right. **Fixed:** the
   current value is now read from the right-most numeric cell (not the first
   numeric cell anywhere in the row), and the `Lkr.` district abbreviation
   (col 2) is captured as the station's `region` instead of `nil`.
2. **Detail / data URLs** (`GKDEndpoints`) — overview links already point
   straight at `.../<place-slug>-<nr>/messwerte?method=tabellen`. **Fixed:**
   `messwerte(for:)` now uses that captured URL as-is (the old code rebuilt the
   path and dropped the `?method=tabellen` query). The CSV download lives at the
   sibling `.../<place-slug>-<nr>/download`, **not** `.../messwerte/download` —
   **fixed**. ⚠️ The download itself is a **POST form gated by mandatory
   terms/privacy checkboxes** (ISO-8859-1 CSV; fixed periods only; custom ranges
   delivered async by e-mail), so the old `GET ?zr&beginn&ende` guess could
   never have worked. `timeSeries` already falls back to scraping the rendered
   table, which is the working path until the POST flow is implemented.
3. **Table / timestamp format** (`GKDParser`) — the messwerte table is two
   columns (`Datum | value`) ordered **newest-first**, with timestamps rendered
   as `dd.MM.yyyy HH:mm **Uhr**`. **Fixed (critical):** `germanDateTime` strips
   the trailing `Uhr` — without it every row failed to parse and was silently
   dropped. **Fixed:** `latestValue` now takes the max-timestamp row, not `.last`
   (which returned the *oldest* visible reading). Separator `;`, German decimal
   comma, and `Europe/Berlin` were correct; the transport already falls back to
   ISO-8859-1 decoding.
4. **Coordinates** — still unverified: the overview table has no lat/lon, so
   scraped stations get `(0,0)` and should be enriched from the detail page or
   matched to the seed catalogue. The seed coordinates are approximate
   town/lake centroids.

`GKDStationCatalog` still guarantees the library is never empty, and
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
- Scraper structure is now live-verified (see above); remaining work is station
  **coordinates** and wiring the GKD **download POST** form for long time series.
