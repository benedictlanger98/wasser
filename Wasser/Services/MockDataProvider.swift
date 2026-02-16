import Foundation

struct MockDataProvider: WaterTemperatureServiceProtocol {

    static let waterBodies: [WaterBody] = [
        WaterBody(id: "zurichsee", name: "Zürichsee", type: .lake,
                  latitude: 47.2257, longitude: 8.6832, region: "Zürich",
                  elevation: 406, maxDepth: 136, surfaceArea: 88.66),
        WaterBody(id: "bodensee", name: "Bodensee", type: .lake,
                  latitude: 47.6300, longitude: 9.3700, region: "Thurgau",
                  elevation: 395, maxDepth: 254, surfaceArea: 536),
        WaterBody(id: "genfersee", name: "Lac Léman", type: .lake,
                  latitude: 46.4530, longitude: 6.5800, region: "Vaud",
                  elevation: 372, maxDepth: 310, surfaceArea: 582.4),
        WaterBody(id: "vierwaldstaettersee", name: "Vierwaldstättersee", type: .lake,
                  latitude: 47.0167, longitude: 8.4333, region: "Luzern",
                  elevation: 434, maxDepth: 214, surfaceArea: 113.72),
        WaterBody(id: "thunersee", name: "Thunersee", type: .lake,
                  latitude: 46.6833, longitude: 7.7167, region: "Bern",
                  elevation: 558, maxDepth: 217, surfaceArea: 48.35),
        WaterBody(id: "brienzersee", name: "Brienzersee", type: .lake,
                  latitude: 46.7300, longitude: 7.9667, region: "Bern",
                  elevation: 564, maxDepth: 261, surfaceArea: 29.81),
        WaterBody(id: "walensee", name: "Walensee", type: .lake,
                  latitude: 47.1167, longitude: 9.2167, region: "St. Gallen",
                  elevation: 419, maxDepth: 145, surfaceArea: 24.16),
        WaterBody(id: "zugersee", name: "Zugersee", type: .lake,
                  latitude: 47.1167, longitude: 8.4833, region: "Zug",
                  elevation: 414, maxDepth: 198, surfaceArea: 38.41),
        WaterBody(id: "aare-bern", name: "Aare (Bern)", type: .river,
                  latitude: 46.9480, longitude: 7.4474, region: "Bern",
                  elevation: 510, maxDepth: nil, surfaceArea: nil),
        WaterBody(id: "limmat-zurich", name: "Limmat (Zürich)", type: .river,
                  latitude: 47.3667, longitude: 8.5333, region: "Zürich",
                  elevation: 392, maxDepth: nil, surfaceArea: nil),
        WaterBody(id: "reuss-luzern", name: "Reuss (Luzern)", type: .river,
                  latitude: 47.0500, longitude: 8.3000, region: "Luzern",
                  elevation: 432, maxDepth: nil, surfaceArea: nil),
        WaterBody(id: "rhein-basel", name: "Rhein (Basel)", type: .river,
                  latitude: 47.5596, longitude: 7.5886, region: "Basel",
                  elevation: 244, maxDepth: nil, surfaceArea: nil),
    ]

    func fetchWaterBodies() async throws -> [WaterBody] {
        try await Task.sleep(nanoseconds: 300_000_000) // simulate network
        return Self.waterBodies
    }

    func fetchConditions(for waterBodyId: String) async throws -> WaterConditions {
        try await Task.sleep(nanoseconds: 200_000_000)

        guard let body = Self.waterBodies.first(where: { $0.id == waterBodyId }) else {
            throw WaterServiceError.notFound
        }

        let baseTemp = Self.baseTemperature(for: body)
        let now = Date()

        let current = TemperatureMeasurement(
            id: UUID().uuidString,
            waterBodyId: waterBodyId,
            timestamp: now,
            temperature: baseTemp + Double.random(in: -0.5...0.5),
            depth: 0
        )

        let hourly = (0..<24).map { hoursAgo -> TemperatureMeasurement in
            TemperatureMeasurement(
                id: UUID().uuidString,
                waterBodyId: waterBodyId,
                timestamp: now.addingTimeInterval(-Double(hoursAgo) * 3600),
                temperature: baseTemp + Double.random(in: -1.5...1.5) + sin(Double(hoursAgo) * .pi / 12) * 0.8,
                depth: 0
            )
        }.reversed()

        let forecast = (0..<7).map { daysAhead -> TemperatureForecast in
            let variation = Double.random(in: -1.0...1.5)
            return TemperatureForecast(
                id: UUID().uuidString,
                waterBodyId: waterBodyId,
                date: Calendar.current.date(byAdding: .day, value: daysAhead, to: now)!,
                highTemperature: baseTemp + 1.5 + variation,
                lowTemperature: baseTemp - 1.5 + variation
            )
        }

        return WaterConditions(
            waterBodyId: waterBodyId,
            currentTemperature: current,
            hourlyHistory: Array(hourly),
            dailyForecast: forecast,
            lastUpdated: now
        )
    }

    func fetchAllCurrentTemperatures() async throws -> [String: TemperatureMeasurement] {
        try await Task.sleep(nanoseconds: 300_000_000)
        var result: [String: TemperatureMeasurement] = [:]
        let now = Date()
        for body in Self.waterBodies {
            let temp = Self.baseTemperature(for: body) + Double.random(in: -0.5...0.5)
            result[body.id] = TemperatureMeasurement(
                id: UUID().uuidString,
                waterBodyId: body.id,
                timestamp: now,
                temperature: temp,
                depth: 0
            )
        }
        return result
    }

    // Seasonal base temperatures vary by water body type, elevation, and time of year
    private static func baseTemperature(for body: WaterBody) -> Double {
        let calendar = Calendar.current
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: Date()) ?? 180)
        let seasonalFactor = sin((dayOfYear - 80) * .pi / 182.5) // peaks in summer
        let elevationFactor = Double(body.elevation ?? 400) * -0.005

        switch body.type {
        case .lake:
            return 12.0 + seasonalFactor * 8.0 + elevationFactor
        case .river:
            return 10.0 + seasonalFactor * 7.0 + elevationFactor
        }
    }
}
