import SwiftUI

struct LocationDetailView: View {
    let waterBody: WaterBody
    @EnvironmentObject var viewModel: WaterTemperatureViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.waterDeep, .waterMid],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    if let conditions = viewModel.selectedConditions {
                        currentTemperatureHeader(conditions)
                        trendCard(conditions)
                        hourlyGraphCard(conditions)
                        dailyForecastCard(conditions)
                        waterBodyInfoCard
                    } else if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                            .padding(.top, 80)
                    }
                }
                .padding()
            }
        }
        .navigationTitle(waterBody.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.toggleFavorite(waterBody.id)
                } label: {
                    Image(systemName: viewModel.isFavorite(waterBody.id) ? "star.fill" : "star")
                        .foregroundStyle(.yellow)
                }
            }
        }
        .task {
            await viewModel.loadConditions(for: waterBody.id)
        }
    }

    private func currentTemperatureHeader(_ conditions: WaterConditions) -> some View {
        VStack(spacing: 4) {
            Text(waterBody.region)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            Text(conditions.currentTemperature.temperatureFormatted)
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(.white)

            HStack(spacing: 6) {
                Image(systemName: waterBody.type.icon)
                Text(waterBody.type.rawValue)
                Text("·")
                Text("Surface")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.vertical, 20)
    }

    private func trendCard(_ conditions: WaterConditions) -> some View {
        TemperatureCardView(title: "TREND") {
            HStack {
                Image(systemName: conditions.temperatureTrend.icon)
                    .font(.title2)
                Text(conditions.temperatureTrend.label)
                    .font(.title3)
                Spacer()
                if let first = conditions.hourlyHistory.first,
                   let last = conditions.hourlyHistory.last {
                    let diff = last.temperature - first.temperature
                    Text(String(format: "%+.1f° in 24h", diff))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func hourlyGraphCard(_ conditions: WaterConditions) -> some View {
        TemperatureCardView(title: "24-HOUR HISTORY") {
            TemperatureGraphView(measurements: conditions.hourlyHistory)
                .frame(height: 150)
        }
    }

    private func dailyForecastCard(_ conditions: WaterConditions) -> some View {
        TemperatureCardView(title: "7-DAY FORECAST") {
            VStack(spacing: 0) {
                ForEach(conditions.dailyForecast) { forecast in
                    HStack {
                        Text(dayLabel(forecast.date))
                            .frame(width: 50, alignment: .leading)
                            .font(.subheadline)

                        Spacer()

                        Text(forecast.lowFormatted)
                            .foregroundStyle(.secondary)
                            .frame(width: 35, alignment: .trailing)

                        temperatureBar(
                            low: forecast.lowTemperature,
                            high: forecast.highTemperature,
                            rangeLow: conditions.dailyForecast.map(\.lowTemperature).min() ?? 0,
                            rangeHigh: conditions.dailyForecast.map(\.highTemperature).max() ?? 30
                        )
                        .frame(width: 100, height: 6)

                        Text(forecast.highFormatted)
                            .frame(width: 35, alignment: .leading)
                    }
                    .padding(.vertical, 6)

                    if forecast.id != conditions.dailyForecast.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var waterBodyInfoCard: some View {
        TemperatureCardView(title: "INFO") {
            VStack(spacing: 8) {
                if let elevation = waterBody.elevation {
                    infoRow("Elevation", value: "\(elevation) m")
                }
                if let depth = waterBody.maxDepth {
                    infoRow("Max Depth", value: String(format: "%.0f m", depth))
                }
                if let area = waterBody.surfaceArea {
                    infoRow("Surface Area", value: String(format: "%.1f km²", area))
                }
                infoRow("Coordinates",
                        value: String(format: "%.4f, %.4f", waterBody.latitude, waterBody.longitude))
            }
        }
    }

    private func infoRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.subheadline)
    }

    private func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func temperatureBar(low: Double, high: Double, rangeLow: Double, rangeHigh: Double) -> some View {
        GeometryReader { geo in
            let totalRange = rangeHigh - rangeLow
            let start = totalRange > 0 ? (low - rangeLow) / totalRange : 0
            let end = totalRange > 0 ? (high - rangeLow) / totalRange : 1

            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [.blue, .cyan, .yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: geo.size.width * (end - start))
                .offset(x: geo.size.width * start)
        }
    }
}
