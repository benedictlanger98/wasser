import SwiftUI
import Charts

// MARK: - Hourly water temperature

/// WASSERTEMPERATUR HEUTE — current-day 15-minute series as a Swift Charts
/// line + area chart (smooth interpolation, hourly grid).
struct HourlyTemperatureCard: View {
    let hourly: [Measurement]

    private let line = Color(red: 0.46, green: 0.86, blue: 1.0)

    private var yDomain: ClosedRange<Double> {
        let values = hourly.map(\.value)
        let lo = (values.min() ?? 0) - 0.3
        let hi = (values.max() ?? 1) + 0.3
        return lo...(hi > lo ? hi : lo + 1)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("WASSERTEMPERATUR HEUTE")
                        .font(.system(size: 13, weight: .semibold)).tracking(0.4)
                        .foregroundStyle(.white.opacity(0.62))
                    Spacer()
                    if let now = hourly.last {
                        Text("\(Fmt.f1(now.value))°")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 12)
                Divider().overlay(Color.white.opacity(0.14))
                chart.padding(.top, 14)
            }
        }
    }

    private var chart: some View {
        Chart(hourly) { m in
            AreaMark(x: .value("Zeit", m.timestamp),
                     y: .value("Temperatur", m.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(LinearGradient(colors: [line.opacity(0.30), .clear],
                                                startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Zeit", m.timestamp),
                     y: .value("Temperatur", m.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(line)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) {
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel().foregroundStyle(.white.opacity(0.5)).font(.system(size: 11))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) {
                AxisGridLine().foregroundStyle(.white.opacity(0.06))
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)))
                    .foregroundStyle(.white.opacity(0.5)).font(.system(size: 11))
            }
        }
        .frame(height: 124)
    }
}

// MARK: - 10-day trend

struct DailyTrendCard: View {
    let days: [DayTrend]

    private var bounds: (min: Double, max: Double) {
        let all = days.flatMap { [$0.low, $0.high] }
        let lo = all.min() ?? 0, hi = all.max() ?? 1
        return (lo, hi > lo ? hi : lo + 1)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                Text("10-TAGE-TREND")
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

    private func row(_ day: DayTrend) -> some View {
        let (lo, hi) = bounds
        let span = hi - lo
        return HStack(spacing: 12) {
            Text(day.label).font(.system(size: 17, weight: .semibold)).frame(width: 42, alignment: .leading)
            Text("\(Fmt.f0(day.low))°").font(.system(size: 16)).opacity(0.6).frame(width: 34, alignment: .trailing)
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
            Text("\(Fmt.f0(day.high))°").font(.system(size: 16, weight: .medium)).frame(width: 34, alignment: .trailing)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 9)
    }
}

// MARK: - Air vs water

struct AirWaterCard: View {
    let water: Double
    let air: Double?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "LUFT & WASSER", systemImage: "thermometer.variable.and.figure")
                VStack(spacing: 9) {
                    valueRow("Wasser", value: "\(Fmt.f1(water))°")
                    valueRow("Luft", value: air.map { "\(Fmt.f0($0))°" } ?? "–")
                }
                .padding(.top, 13)
                Text(note).font(.system(size: 12.5)).opacity(0.72).padding(.top, 9)
            }
        }
        .foregroundStyle(.white)
    }

    private var note: String {
        guard let air else { return "Keine Luftdaten verfügbar" }
        let diff = Int(air.rounded()) - Int(water.rounded())
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
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "UV-INDEX", systemImage: "sun.max")
                Text("\(index)").font(.system(size: 34, weight: .light)).padding(.top, 8)
                Text(category).font(.system(size: 19, weight: .medium))
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
                .padding(.top, 12)
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
        GlassCard {
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

// MARK: - Water quality

struct QualityCard: View {
    let quality: WaterQualityInfo

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "WASSERQUALITÄT", systemImage: "drop.fill")
                Text(quality.rating).font(.system(size: 22, weight: .medium)).padding(.top, 8)
                Text(quality.note).font(.system(size: 12.5)).opacity(0.72).padding(.top, 4)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("Sichttiefe").font(.system(size: 13)).opacity(0.7)
                    Text("\(Fmt.f1(quality.clarityMeters)) m").font(.system(size: 17, weight: .medium))
                }
                .padding(.top, 10)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Marine (sea only)

struct WaveCard: View {
    let marine: MarineInfo
    var body: some View {
        GlassCard {
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
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "GEZEITEN", systemImage: "water.waves.and.arrow.trianglehead.up")
                TideWave().stroke(Color.white.opacity(0.55), lineWidth: 2)
                    .frame(height: 40).padding(.top, 10)
                HStack {
                    Text("Hochw. \(marine.nextHighTide)")
                    Spacer()
                    Text("Niedrigw. \(marine.nextLowTide)")
                }
                .font(.system(size: 12.5)).opacity(0.8).padding(.top, 6)
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

// MARK: - Abfluss (river) / Wasserstand (lake)

struct AbflussCard: View {
    let discharge: Measurement
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "ABFLUSS", systemImage: "water.waves.and.arrow.trianglehead.up")
                Text(Fmt.f1(discharge.value)).font(.system(size: 34, weight: .light)).padding(.top, 8)
                Text("m³/s").font(.system(size: 13)).opacity(0.72)
                Text("Stand \(Fmt.time(discharge.timestamp))")
                    .font(.system(size: 12)).opacity(0.6).padding(.top, 6)
            }
        }
        .foregroundStyle(.white)
    }
}

struct WasserstandCard: View {
    let level: Measurement
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "WASSERSTAND", systemImage: "ruler")
                Text("\(Fmt.f0(level.value))").font(.system(size: 34, weight: .light)).padding(.top, 8)
                Text("cm").font(.system(size: 13)).opacity(0.72)
                Text("Stand \(Fmt.time(level.timestamp))")
                    .font(.system(size: 12)).opacity(0.6).padding(.top, 6)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Flow (river only)

struct FlowCard: View {
    let flow: FlowInfo
    var body: some View {
        GlassCard {
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
        GlassCard {
            VStack(alignment: .leading, spacing: 0) {
                CardHeader(title: "SONNENAUFGANG", systemImage: "sunrise")
                Text(sunrise.map(Fmt.time) ?? "–")
                    .font(.system(size: 30, weight: .light)).padding(.top, 8)
                SunArc().stroke(Color.white.opacity(0.3),
                                style: StrokeStyle(lineWidth: 1.5, dash: [2, 3]))
                    .frame(height: 34).padding(.top, 8)
                    .overlay(alignment: .bottom) {
                        GeometryReader { geo in
                            let frac = 0.66
                            let x = frac * geo.size.width
                            let y = geo.size.height - sin(.pi * frac) * geo.size.height
                            Circle().fill(Color(red: 1.0, green: 0.88, blue: 0.54))
                                .frame(width: 8, height: 8)
                                .position(x: x, y: y)
                        }
                        .frame(height: 34)
                    }
                Text("Sonnenuntergang: \(sunset.map(Fmt.time) ?? "–")")
                    .font(.system(size: 12.5)).opacity(0.78)
            }
        }
        .foregroundStyle(.white)
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
