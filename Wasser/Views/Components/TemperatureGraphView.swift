import SwiftUI

struct TemperatureGraphView: View {
    let measurements: [TemperatureMeasurement]

    var body: some View {
        GeometryReader { geo in
            let temps = measurements.map(\.temperature)
            let minTemp = (temps.min() ?? 0) - 0.5
            let maxTemp = (temps.max() ?? 20) + 0.5
            let range = maxTemp - minTemp

            ZStack(alignment: .leading) {
                // Grid lines
                ForEach(0..<4) { i in
                    let y = geo.size.height * CGFloat(i) / 3
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(.secondary.opacity(0.2), lineWidth: 0.5)

                    let tempAtLine = maxTemp - (Double(i) / 3.0) * range
                    Text(String(format: "%.0f°", tempAtLine))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .position(x: 16, y: y)
                }

                // Temperature line
                if measurements.count > 1 {
                    Path { path in
                        for (index, measurement) in measurements.enumerated() {
                            let x = geo.size.width * CGFloat(index) / CGFloat(measurements.count - 1)
                            let y = geo.size.height * (1 - CGFloat((measurement.temperature - minTemp) / range))

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                    // Gradient fill under the line
                    Path { path in
                        for (index, measurement) in measurements.enumerated() {
                            let x = geo.size.width * CGFloat(index) / CGFloat(measurements.count - 1)
                            let y = geo.size.height * (1 - CGFloat((measurement.temperature - minTemp) / range))

                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.3), .blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Time labels
                HStack {
                    Text("24h ago")
                    Spacer()
                    Text("Now")
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .offset(y: geo.size.height + 8)
            }
        }
    }
}
