import SwiftUI

// MARK: - Hourly water temperature

/// WASSERTEMPERATUR · 24 STD — the last 24 hours of the 15-minute series as a
/// line chart, with two horizontal reference gridlines and time markers (rounded
/// to the nearest half hour) along the bottom.
struct HourlyTemperatureCard: View {
    let hourly: [Measurement]
    @Environment(\.temperatureUnit) private var unit

    private var bounds: (min: Double, max: Double) {
        let values = hourly.map(\.value)
        let lo = (values.min() ?? 0) - 0.3
        let hi = (values.max() ?? 1) + 0.3
        return (lo, hi > lo ? hi : lo + 1)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("24-STUNDEN-TREND")
                        .font(.system(size: 13, weight: .semibold)).tracking(0.4)
                        .foregroundStyle(.white.opacity(0.62))
                    Spacer()
                    if let now = hourly.last {
                        Text("\(Fmt.temp1(now.value, unit))°")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 12)
                Divider().overlay(Color.white.opacity(0.14))
                if hourly.count >= 2 {
                    chart.padding(.top, 16)
                } else {
                    Text("Keine Verlaufsdaten verfügbar")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 16)
                }
            }
        }
    }

    /// Two reference temperature lines at one-third and two-thirds height.
    private var gridFractions: [Double] { [1.0 / 3.0, 2.0 / 3.0] }

    /// Four time markers across the ~24h span (each rounded to the nearest half
    /// hour), then "Jetzt".
    private var timeLabels: [String] {
        guard let start = hourly.first?.timestamp,
              let end = hourly.last?.timestamp else { return [] }
        let span = end.timeIntervalSince(start)
        let labels = [0.0, 0.25, 0.5, 0.75].map { Fmt.timeHalfHour(start.addingTimeInterval(span * $0)) }
        return labels + ["Jetzt"]
    }

    /// Right inset reserved for the y-axis temperature labels: the line, its end
    /// dot and the "Jetzt" marker stop this far short of the right edge so they
    /// don't collide with those labels (which stay pinned at the edge).
    private let axisInset: CGFloat = 30

    private var chart: some View {
        let pts = hourly
        let (lo, hi) = bounds
        let span = hi - lo
        return VStack(spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let plotW = max(1, w - axisInset)
                let n = pts.count
                let pos: (Int) -> CGPoint = { i in
                    CGPoint(x: n <= 1 ? 0 : CGFloat(i) / CGFloat(n - 1) * plotW,
                            y: h - CGFloat((pts[i].value - lo) / span) * h)
                }
                ZStack {
                    // Reference gridlines (full width) + their temperature labels
                    // (kept at the right edge — these do not move).
                    ForEach(gridFractions, id: \.self) { frac in
                        let y = h * CGFloat(frac)
                        let value = hi - span * frac
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y))
                            p.addLine(to: CGPoint(x: w, y: y))
                        }
                        .stroke(Color.white.opacity(0.16),
                                style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                        Text("\(Fmt.temp0(value, unit))°")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .position(x: w - 12, y: y - 7)
                    }
                    Path { p in
                        p.move(to: CGPoint(x: 0, y: h))
                        for i in pts.indices { p.addLine(to: pos(i)) }
                        p.addLine(to: CGPoint(x: plotW, y: h))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [Color(red: 0.4, green: 0.82, blue: 0.96).opacity(0.32), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: pos(0))
                        for i in pts.indices.dropFirst() { p.addLine(to: pos(i)) }
                    }
                    .stroke(LinearGradient(colors: [Color(red: 0.62, green: 0.91, blue: 1.0),
                                                    Color(red: 0.16, green: 0.65, blue: 0.77)],
                                           startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    Circle().fill(.white).frame(width: 8, height: 8).position(pos(n - 1))
                }
            }
            .frame(height: 92)
            HStack(spacing: 0) {
                ForEach(Array(timeLabels.enumerated()), id: \.offset) { idx, label in
                    Text(label)
                    if idx != timeLabels.count - 1 { Spacer(minLength: 0) }
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.7))
            // Match the chart's right inset so "Jetzt" sits under the line end.
            .padding(.trailing, axisInset)
        }
    }
}

// MARK: - 10-day trend

struct DailyTrendCard: View {
    let days: [DayTrend]
    @Environment(\.temperatureUnit) private var unit

    private var bounds: (min: Double, max: Double) {
        let all = days.flatMap { [$0.low, $0.high] }
        let lo = all.min() ?? 0, hi = all.max() ?? 1
        return (lo, hi > lo ? hi : lo + 1)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("7-TAGE-TREND")
                    .font(.system(size: 13, weight: .semibold)).tracking(0.4)
                    .foregroundStyle(.white.opacity(0.62))
                    .padding(.bottom, 6)
                ForEach(days) { day in
                    row(day)
                    if day.id != days.last?.id {
                        Divider().overlay(Color.white.opacity(0.10))
                    }
                }
            }
        }
    }

    private func label(_ day: DayTrend) -> String {
        Fmt.isToday(day.date) ? "Heute" : Fmt.weekdayShort(day.date)
    }

    private func row(_ day: DayTrend) -> some View {
        let (lo, hi) = bounds
        let span = hi - lo
        return HStack(spacing: 12) {
            Text(label(day)).font(.system(size: 17, weight: .semibold)).frame(width: 52, alignment: .leading)
            Text("\(Fmt.temp0(day.low, unit))°").font(.system(size: 16)).opacity(0.6).frame(width: 34, alignment: .trailing)
            GeometryReader { geo in
                let leading = (day.low - lo) / span * geo.size.width
                let width = (day.high - day.low) / span * geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(LinearGradient(
                        colors: [Color(red: 0.37, green: 0.82, blue: 0.90),
                                 Color(red: 0.65, green: 0.95, blue: 0.82)],
                        startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, width))
                        .offset(x: leading)
                }
            }
            .frame(height: 6)
            Text("\(Fmt.temp0(day.high, unit))°").font(.system(size: 16, weight: .medium)).frame(width: 34, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 9)
    }
}

// MARK: - Air vs water

struct AirWaterCard: View {
    let water: Double
    let air: Double?
    @Environment(\.temperatureUnit) private var unit

    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "LUFT & WASSER", systemImage: "thermometer.variable.and.figure")
                VStack(spacing: 9) {
                    valueRow("Wasser", value: "\(Fmt.temp1(water, unit))°")
                    valueRow("Luft", value: air.map { "\(Fmt.temp0($0, unit))°" } ?? "–")
                }
                .padding(.top, 13)
                Text(note).font(.system(size: 12.5)).opacity(0.72).padding(.top, 9)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(.white)
    }

    private var note: String {
        guard let air else { return "Keine Luftdaten verfügbar" }
        let diff = Int(unit.convert(air).rounded()) - Int(unit.convert(water).rounded())
        return diff > 0 ? "Luft \(diff)° wärmer als Wasser" : "Wasser wärmer als die Luft"
    }

    private func valueRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.system(size: 14)).opacity(0.8)
            Spacer()
            Text(value).font(.system(size: 24, weight: .regular))
        }
    }
}

// MARK: - UV index

struct UVCard: View {
    let index: Int
    let category: String

    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "UV-INDEX", systemImage: "sun.max")
                Text("\(index)").font(.system(size: 34, weight: .light)).padding(.top, 8)
                Text(category).font(.system(size: 19, weight: .medium))
                Spacer(minLength: 8)
                GeometryReader { geo in
                    let x = min(1, Double(index) / 11) * geo.size.width
                    ZStack(alignment: .leading) {
                        Capsule().fill(LinearGradient(
                            colors: [Color(red: 0.29, green: 0.87, blue: 0.50),
                                     Color(red: 0.98, green: 0.80, blue: 0.08),
                                     Color(red: 0.98, green: 0.57, blue: 0.24),
                                     Color(red: 0.97, green: 0.44, blue: 0.44),
                                     Color(red: 0.75, green: 0.52, blue: 0.99)],
                            startPoint: .leading, endPoint: .trailing))
                        Circle().fill(.white)
                            .frame(width: 11, height: 11)
                            .overlay(Circle().strokeBorder(.black.opacity(0.15), lineWidth: 2))
                            .offset(x: x - 5.5)
                    }
                }
                .frame(height: 11)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Wind

struct WindCard: View {
    let speed: Double
    let gust: Double
    let compass: String
    let degrees: Double

    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "WIND", systemImage: "wind")
                HStack(spacing: 12) {
                    compassDial
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Fmt.f0(speed))").font(.system(size: 24, weight: .regular))
                        Text("km/h \(compass)").font(.system(size: 12)).opacity(0.7)
                        Text("Böen \(Fmt.f0(gust)) km/h").font(.system(size: 12)).opacity(0.7).padding(.top, 4)
                    }
                    Spacer()
                }
                .padding(.top, 10)
            }
        }
        .foregroundStyle(.white)
    }

    private var compassDial: some View {
        ZStack {
            Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
            VStack {
                Text("N").font(.system(size: 8)).opacity(0.6)
                Spacer()
                Text("S").font(.system(size: 8)).opacity(0.45)
            }
            .padding(.vertical, 2)
            Image(systemName: "location.north.fill")
                .font(.system(size: 12))
                .rotationEffect(.degrees(degrees))
        }
        .frame(width: 58, height: 58)
    }
}

// MARK: - Badehinweis (swimming comfort, derived from real water temperature)

struct BadehinweisCard: View {
    let comfort: SwimComfort
    let waterTemperature: Double
    @Environment(\.temperatureUnit) private var unit

    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "BADEHINWEIS", systemImage: comfort.symbolName)
                Text(comfort.rating).font(.system(size: 22, weight: .medium)).padding(.top, 8)
                Text(comfort.note).font(.system(size: 12.5)).opacity(0.72).padding(.top, 4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("Wasser").font(.system(size: 13)).opacity(0.7)
                    Text("\(Fmt.temp1(waterTemperature, unit))°").font(.system(size: 17, weight: .medium))
                }
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Marine (sea only)

struct WaveCard: View {
    let marine: MarineInfo
    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "WELLENHÖHE", systemImage: "water.waves")
                Text("\(Fmt.f1(marine.waveHeightMeters)) m").font(.system(size: 34, weight: .light)).padding(.top, 8)
                Text("Periode \(marine.wavePeriodSeconds) s").font(.system(size: 13)).opacity(0.72).padding(.top, 6)
            }
        }
        .foregroundStyle(.white)
    }
}

struct TideCard: View {
    let marine: MarineInfo
    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "GEZEITEN", systemImage: "water.waves.and.arrow.trianglehead.up")
                TideWave().stroke(Color.white.opacity(0.55), lineWidth: 2)
                    .frame(height: 40).padding(.top, 10)
                Spacer(minLength: 6)
                HStack {
                    Text("Hochw. \(marine.nextHighTide)")
                    Spacer()
                    Text("Niedrigw. \(marine.nextLowTide)")
                }
                .font(.system(size: 12.5)).opacity(0.8)
            }
        }
        .foregroundStyle(.white)
    }

    private struct TideWave: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            let midY = rect.midY
            p.move(to: CGPoint(x: 0, y: rect.maxY * 0.75))
            p.addCurve(to: CGPoint(x: rect.width * 0.33, y: rect.maxY * 0.2),
                       control1: CGPoint(x: rect.width * 0.17, y: rect.maxY * 0.75),
                       control2: CGPoint(x: rect.width * 0.17, y: rect.maxY * 0.2))
            p.addCurve(to: CGPoint(x: rect.width * 0.66, y: rect.maxY * 0.75),
                       control1: CGPoint(x: rect.width * 0.5, y: rect.maxY * 0.2),
                       control2: CGPoint(x: rect.width * 0.5, y: rect.maxY * 0.75))
            p.addCurve(to: CGPoint(x: rect.width, y: rect.maxY * 0.2),
                       control1: CGPoint(x: rect.width * 0.83, y: rect.maxY * 0.75),
                       control2: CGPoint(x: rect.width * 0.83, y: rect.maxY * 0.2))
            _ = midY
            return p
        }
    }
}

// MARK: - Abfluss (river) / Wasserstand (lake + river)

struct AbflussCard: View {
    let discharge: Measurement
    let annualMean: Double?
    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "ABFLUSS", systemImage: "water.waves.and.arrow.trianglehead.up")
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(Fmt.f1(discharge.value)).font(.system(size: 34, weight: .light))
                    Text("m³/s").font(.system(size: 15, weight: .medium)).opacity(0.72)
                }
                .padding(.top, 8)
                if let delta = AnnualDelta.text(value: discharge.value, mean: annualMean,
                                                unit: "m³/s", oneDecimal: true) {
                    Text(delta).font(.system(size: 12)).opacity(0.72).padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Text("Stand \(Fmt.time(discharge.timestamp))")
                    .font(.system(size: 12)).opacity(0.6)
            }
        }
        .foregroundStyle(.white)
    }
}

struct WasserstandCard: View {
    let level: Measurement
    let annualMean: Double?
    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "WASSERSTAND", systemImage: "ruler")
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(Fmt.f0(level.value))").font(.system(size: 34, weight: .light))
                    Text("cm").font(.system(size: 15, weight: .medium)).opacity(0.72)
                }
                .padding(.top, 8)
                if let delta = AnnualDelta.text(value: level.value, mean: annualMean,
                                                unit: "cm", oneDecimal: false) {
                    Text(delta).font(.system(size: 12)).opacity(0.72).padding(.top, 6)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Text("Stand \(Fmt.time(level.timestamp))")
                    .font(.system(size: 12)).opacity(0.6)
            }
        }
        .foregroundStyle(.white)
    }
}

/// Formats a "± vs. annual mean" caption shared by the level/discharge cards.
enum AnnualDelta {
    static func text(value: Double, mean: Double?, unit: String, oneDecimal: Bool) -> String? {
        guard let mean else { return nil }
        let delta = value - mean
        let magnitude = oneDecimal ? Fmt.f1(abs(delta)) : Fmt.f0(abs(delta))
        let sign = delta >= 0 ? "+" : "−"
        return "\(sign)\(magnitude) \(unit) ggü. Jahresmittel"
    }
}

// MARK: - Flow (river only)

struct FlowCard: View {
    let flow: FlowInfo
    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "STRÖMUNG", systemImage: "arrow.right.to.line")
                Text(Fmt.f1(flow.speedMetersPerSecond)).font(.system(size: 34, weight: .light)).padding(.top, 8)
                Text("m/s · \(flow.direction)").font(.system(size: 13)).opacity(0.72)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Sunrise / sunset

struct SunriseCard: View {
    let sunrise: Date?
    let sunset: Date?

    var body: some View {
        GlassCard(minHeight: smallCardMinHeight) {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "SONNENAUFGANG", systemImage: "sunrise")
                Text(sunrise.map(Fmt.time) ?? "–")
                    .font(.system(size: 30, weight: .light)).padding(.top, 8)
                Spacer(minLength: 12)
                arc
                Spacer(minLength: 12)
                Text("Sonnenuntergang: \(sunset.map(Fmt.time) ?? "–")")
                    .font(.system(size: 12.5)).opacity(0.78)
            }
        }
        .foregroundStyle(.white)
    }

    private var arc: some View {
        SunArc().stroke(Color.white.opacity(0.3),
                        style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
            .frame(height: 28)
            .overlay {
                GeometryReader { geo in
                    let frac = 0.66
                    let x = frac * geo.size.width
                    let y = geo.size.height - sin(.pi * frac) * geo.size.height
                    Circle().fill(Color(red: 1.0, green: 0.88, blue: 0.54))
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }
            }
    }

    private struct SunArc: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 4, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - 4, y: rect.maxY),
                           control: CGPoint(x: rect.midX, y: -rect.maxY))
            return p
        }
    }
}

// MARK: - Severe-weather warning banner

struct WeatherAlertBanner: View {
    let alert: WeatherAlertInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.symbolName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.82, blue: 0.3))
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.summary)
                    .font(.system(size: 15, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                let detail = [alert.region, alert.severity].compactMap { $0 }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail).font(.system(size: 12.5)).opacity(0.8)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.85),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(Color(red: 0.55, green: 0.32, blue: 0.05).opacity(0.55),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color(red: 1.0, green: 0.82, blue: 0.3).opacity(0.4), lineWidth: 0.5))
    }
}
