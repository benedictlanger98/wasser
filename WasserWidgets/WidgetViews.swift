import WidgetKit
import SwiftUI

// MARK: - Shared helpers

extension Color {
    /// Builds a colour from a 0–1 RGB triple stored in the snapshot, with a
    /// sensible fallback if the array is malformed.
    init(triple: [Double], fallback: Color = .blue) {
        guard triple.count == 3 else { self = fallback; return }
        self = Color(red: triple[0], green: triple[1], blue: triple[2])
    }
}

/// Rounded temperature string in the snapshot's unit (°C stored, °F optional).
func tempString(_ celsius: Double, fahrenheit: Bool) -> String {
    let value = fahrenheit ? celsius * 9 / 5 + 32 : celsius
    return String(Int(value.rounded()))
}

extension WidgetStation {
    /// Sample data for placeholders and the widget gallery.
    static let preview = WidgetStation(
        id: "preview", name: "Tegernsee", subtitle: "Gmund",
        currentTemp: 20, todayHigh: 20, todayLow: 17,
        windSpeedKmh: 9, windCompass: "NW", waterLevelCm: 132,
        conditionText: "Erfrischend · steigend",
        hourly: (0..<24).map { i in
            WidgetPoint(t: Date().addingTimeInterval(Double(i - 23) * 3600),
                        v: 17 + 3 * sin(Double(i) / 6))
        },
        deepRGB: [0.02, 0.12, 0.20], shallowRGB: [0.10, 0.46, 0.56],
        updatedAt: Date())
}

/// Applies the water gradient as the widget's container background (required on
/// iOS 17+), using the station's theme colours.
private struct WaterContainerBackground: ViewModifier {
    let station: WidgetStation?

    func body(content: Content) -> some View {
        let deep = Color(triple: station?.deepRGB ?? [0.02, 0.12, 0.20])
        let shallow = Color(triple: station?.shallowRGB ?? [0.10, 0.46, 0.56])
        content.containerBackground(for: .widget) {
            LinearGradient(colors: [shallow, deep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(LinearGradient(colors: [.black.opacity(0.22), .clear, .black.opacity(0.12)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }
}

extension View {
    func waterContainerBackground(_ station: WidgetStation?) -> some View {
        modifier(WaterContainerBackground(station: station))
    }
}

/// Shown when no saved water body is available yet (app not opened / none saved).
private struct EmptyWidgetView: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "water.waves").font(.title2)
            Text("Wasser öffnen,\num ein Gewässer zu wählen")
                .font(.caption).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}

private func highLow(_ s: WidgetStation, fahrenheit: Bool) -> String {
    let hi = s.todayHigh.map { tempString($0, fahrenheit: fahrenheit) } ?? "–"
    let lo = s.todayLow.map { tempString($0, fahrenheit: fahrenheit) } ?? "–"
    return "H:\(hi)°  T:\(lo)°"
}

// MARK: - 1) Current temperature (small)

struct CurrentTemperatureView: View {
    let entry: WaterEntry

    var body: some View {
        if let s = entry.station {
            VStack(alignment: .leading, spacing: 0) {
                Text(s.name).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                if !s.subtitle.isEmpty {
                    Text(s.subtitle).font(.system(size: 11)).opacity(0.8).lineLimit(1)
                }
                Spacer(minLength: 2)
                Text("\(tempString(s.currentTemp, fahrenheit: entry.useFahrenheit))°")
                    .font(.system(size: 44, weight: .light))
                Spacer(minLength: 2)
                Text(highLow(s, fahrenheit: entry.useFahrenheit))
                    .font(.system(size: 12, weight: .semibold)).opacity(0.92)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            EmptyWidgetView()
        }
    }
}

// MARK: - 2) Detail conditions (medium)

struct DetailConditionsView: View {
    let entry: WaterEntry

    var body: some View {
        if let s = entry.station {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.name).font(.system(size: 17, weight: .semibold)).lineLimit(1)
                    if !s.subtitle.isEmpty {
                        Text(s.subtitle).font(.system(size: 11)).opacity(0.8).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text("\(tempString(s.currentTemp, fahrenheit: entry.useFahrenheit))°")
                        .font(.system(size: 46, weight: .light))
                    Text(highLow(s, fahrenheit: entry.useFahrenheit))
                        .font(.system(size: 12, weight: .semibold)).opacity(0.92)
                }
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 10) {
                    if !s.conditionText.isEmpty {
                        metric(icon: "drop.fill", text: s.conditionText)
                    }
                    if let wind = s.windSpeedKmh {
                        metric(icon: "wind",
                               text: "\(Int(wind.rounded())) km/h" + (s.windCompass.map { " \($0)" } ?? ""))
                    }
                    if let level = s.waterLevelCm {
                        metric(icon: "ruler", text: "\(Int(level.rounded())) cm")
                    }
                    Spacer(minLength: 0)
                }
                .font(.system(size: 13))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            EmptyWidgetView()
        }
    }

    private func metric(icon: String, text: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 13)).frame(width: 16)
            Text(text).lineLimit(1)
        }
    }
}

// MARK: - 3) Chart (medium & large)

struct ChartWidgetView: View {
    let entry: WaterEntry

    var body: some View {
        if let s = entry.station {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(s.name).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                        Text(highLow(s, fahrenheit: entry.useFahrenheit))
                            .font(.system(size: 12, weight: .semibold)).opacity(0.9)
                    }
                    Spacer()
                    Text("\(tempString(s.currentTemp, fahrenheit: entry.useFahrenheit))°")
                        .font(.system(size: 30, weight: .light))
                }
                if s.hourly.count >= 2 {
                    TemperatureChart(points: s.hourly)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Kein Verlauf verfügbar")
                        .font(.system(size: 12)).opacity(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            EmptyWidgetView()
        }
    }
}

/// A compact line + area chart of the last 24h, matching the app's Tagestrend.
private struct TemperatureChart: View {
    let points: [WidgetPoint]

    var body: some View {
        GeometryReader { geo in
            let values = points.map(\.v)
            let lo = (values.min() ?? 0) - 0.3
            let hiRaw = (values.max() ?? 1) + 0.3
            let hi = hiRaw > lo ? hiRaw : lo + 1
            let span = hi - lo
            let w = geo.size.width, h = geo.size.height
            let n = points.count
            let pos: (Int) -> CGPoint = { i in
                CGPoint(x: n <= 1 ? 0 : CGFloat(i) / CGFloat(n - 1) * w,
                        y: h - CGFloat((points[i].v - lo) / span) * h)
            }
            ZStack {
                // Filled area under the line.
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    for i in points.indices { p.addLine(to: pos(i)) }
                    p.addLine(to: CGPoint(x: w, y: h))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [Color(red: 0.4, green: 0.82, blue: 0.96).opacity(0.35), .clear],
                                     startPoint: .top, endPoint: .bottom))
                // The line.
                Path { p in
                    p.move(to: pos(0))
                    for i in points.indices.dropFirst() { p.addLine(to: pos(i)) }
                }
                .stroke(LinearGradient(colors: [Color(red: 0.62, green: 0.91, blue: 1.0),
                                                Color(red: 0.16, green: 0.65, blue: 0.77)],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                // Current-value dot.
                Circle().fill(.white).frame(width: 7, height: 7).position(pos(n - 1))
            }
        }
    }
}
