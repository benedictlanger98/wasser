import Foundation

/// A bundled seed catalogue of well-known Bavarian lakes and rivers.
///
/// Purpose:
///   1. The app shows a usable library immediately, offline, before any scrape.
///   2. It documents the shape the live scraper produces.
///
/// The live `GKDBayernDataSource.fetchStations()` scrapes the GKD overview
/// tables and *replaces/augments* these entries with real Messstellennummern
/// and detail URLs. Seed entries intentionally carry no `externalID`-backed
/// detail URL, so their live data is loaded only once matched against the
/// scraped catalogue. Coordinates are approximate (lake/town centroids).
enum GKDStationCatalog {
    static let dataSourceID = "gkd-bayern"

    private struct Seed {
        let name: String
        let water: String
        let type: WaterBodyType
        let region: String
        let lat: Double
        let lon: Double
        let params: [MeasurementParameter]
    }

    private static let seeds: [Seed] = [
        // MARK: Lakes (Seen) — water temperature
        Seed(name: "Starnberger See", water: "Starnberger See", type: .lake, region: "Oberbayern", lat: 47.9000, lon: 11.3167, params: [.waterTemperature]),
        Seed(name: "Ammersee", water: "Ammersee", type: .lake, region: "Oberbayern", lat: 48.0000, lon: 11.1333, params: [.waterTemperature]),
        Seed(name: "Chiemsee", water: "Chiemsee", type: .lake, region: "Oberbayern", lat: 47.8667, lon: 12.4333, params: [.waterTemperature]),
        Seed(name: "Tegernsee", water: "Tegernsee", type: .lake, region: "Oberbayern", lat: 47.7167, lon: 11.7500, params: [.waterTemperature]),
        Seed(name: "Walchensee", water: "Walchensee", type: .lake, region: "Oberbayern", lat: 47.5833, lon: 11.3333, params: [.waterTemperature]),
        Seed(name: "Kochelsee", water: "Kochelsee", type: .lake, region: "Oberbayern", lat: 47.6500, lon: 11.3333, params: [.waterTemperature]),
        Seed(name: "Schliersee", water: "Schliersee", type: .lake, region: "Oberbayern", lat: 47.7333, lon: 11.8667, params: [.waterTemperature]),
        Seed(name: "Staffelsee", water: "Staffelsee", type: .lake, region: "Oberbayern", lat: 47.7000, lon: 11.1833, params: [.waterTemperature]),
        Seed(name: "Königssee", water: "Königssee", type: .lake, region: "Oberbayern", lat: 47.5500, lon: 12.9833, params: [.waterTemperature]),
        Seed(name: "Forggensee", water: "Forggensee", type: .lake, region: "Schwaben", lat: 47.6167, lon: 10.7000, params: [.waterTemperature]),
        Seed(name: "Großer Brombachsee", water: "Großer Brombachsee", type: .lake, region: "Mittelfranken", lat: 49.1333, lon: 10.9667, params: [.waterTemperature]),

        // MARK: Rivers (Flüsse) — temperature, level, discharge
        Seed(name: "München", water: "Isar", type: .river, region: "Oberbayern", lat: 48.1351, lon: 11.5820, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Passau", water: "Donau", type: .river, region: "Niederbayern", lat: 48.5667, lon: 13.4667, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Würzburg", water: "Main", type: .river, region: "Unterfranken", lat: 49.7913, lon: 9.9534, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Wasserburg", water: "Inn", type: .river, region: "Oberbayern", lat: 48.0589, lon: 12.2300, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Landsberg", water: "Lech", type: .river, region: "Oberbayern", lat: 48.0500, lon: 10.8667, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Kempten", water: "Iller", type: .river, region: "Schwaben", lat: 47.7333, lon: 10.3167, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Bamberg", water: "Regnitz", type: .river, region: "Oberfranken", lat: 49.8917, lon: 10.8917, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Regensburg", water: "Naab", type: .river, region: "Oberpfalz", lat: 49.0167, lon: 12.0833, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Fürstenfeldbruck", water: "Amper", type: .river, region: "Oberbayern", lat: 48.1781, lon: 11.2556, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Eichstätt", water: "Altmühl", type: .river, region: "Oberbayern", lat: 48.8917, lon: 11.1833, params: [.waterTemperature, .waterLevel, .discharge]),
        Seed(name: "Regen", water: "Regen", type: .river, region: "Niederbayern", lat: 48.9667, lon: 13.1333, params: [.waterTemperature, .waterLevel, .discharge])
    ]

    /// Seed stations as domain objects. `externalID` is a deterministic slug so
    /// IDs are stable across launches; the live scraper overwrites entries that
    /// it can match by name.
    static func stations() -> [MeasurementStation] {
        seeds.map { seed in
            let external = slug("\(seed.water)-\(seed.name)")
            return MeasurementStation(
                id: MeasurementStation.makeID(dataSourceID: dataSourceID, externalID: external),
                externalID: external,
                dataSourceID: dataSourceID,
                name: seed.name,
                waterBodyName: seed.water,
                waterBodyType: seed.type,
                region: seed.region,
                latitude: seed.lat,
                longitude: seed.lon,
                elevation: nil,
                operatorName: "Bayerisches Landesamt für Umwelt",
                availableParameters: seed.params,
                detailURL: nil
            )
        }
    }

    private static func slug(_ string: String) -> String {
        let lower = string.lowercased()
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        return String(lower.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
            .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
