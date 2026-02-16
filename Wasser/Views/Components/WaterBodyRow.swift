import SwiftUI

struct WaterBodyRow: View {
    let waterBody: WaterBody
    let temperature: TemperatureMeasurement?
    let distance: Double?
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Temperature circle
            ZStack {
                Circle()
                    .fill(temperatureColor.opacity(0.25))
                    .frame(width: 52, height: 52)

                if let temp = temperature {
                    Text(temp.temperatureFormatted)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("--")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(waterBody.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)

                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 8) {
                    Label(waterBody.type.rawValue, systemImage: waterBody.type.icon)

                    if let dist = distance {
                        Text("·")
                        Text(String(format: "%.0f km", dist))
                    }

                    Text("·")
                    Text(waterBody.region)
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private var temperatureColor: Color {
        guard let temp = temperature?.temperature else { return .gray }
        switch temp {
        case ..<8: return .blue
        case 8..<14: return .cyan
        case 14..<20: return .green
        case 20..<24: return .yellow
        default: return .orange
        }
    }
}
