import SwiftUI
import Charts

/// PLACEHOLDER UI — to be replaced by the imported design. Renders current
/// conditions, weather and a Swift Charts time series for the selected
/// parameter and range.
struct StationDetailView: View {
    @EnvironmentObject private var repository: WaterRepository
    @StateObject private var viewModel: StationDetailViewModel

    init(viewModel: StationDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                conditionsHeader
                if viewModel.station.availableParameters.count > 1 {
                    parameterPicker
                }
                rangePicker
                chart
                if let weather = viewModel.conditions?.weather {
                    weatherCard(weather)
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.station.waterBodyName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            Button {
                repository.toggleFavorite(viewModel.station)
            } label: {
                Image(systemName: repository.isFavorite(viewModel.station) ? "star.fill" : "star")
            }
        }
        .task { await viewModel.load() }
        .overlay { if viewModel.isLoading { ProgressView() } }
    }

    private var conditionsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.station.name).font(.title3).foregroundStyle(.secondary)
            if let temp = viewModel.conditions?.waterTemperature {
                Text(temp.formattedValue)
                    .font(.system(size: 56, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.forTemperature(temp.value))
            }
            HStack(spacing: 16) {
                ForEach(viewModel.station.availableParameters.filter { $0 != .waterTemperature }, id: \.self) { param in
                    if let m = viewModel.conditions?.latest[param] {
                        Label(m.formattedValue, systemImage: param.symbolName)
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            if let observed = viewModel.conditions?.observationTime {
                Text("Stand: \(observed.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private var parameterPicker: some View {
        Picker("Parameter", selection: $viewModel.selectedParameter) {
            ForEach(viewModel.station.availableParameters, id: \.self) { param in
                Text(param.displayName).tag(param)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedParameter) { Task { await viewModel.reloadSeries() } }
    }

    private var rangePicker: some View {
        Picker("Zeitraum", selection: $viewModel.selectedRange) {
            ForEach(TimeRange.allCases) { range in Text(range.rawValue).tag(range) }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedRange) { Task { await viewModel.reloadSeries() } }
    }

    @ViewBuilder
    private var chart: some View {
        if let series = viewModel.series, !series.isEmpty {
            Chart(series.points) { point in
                LineMark(x: .value("Zeit", point.timestamp),
                         y: .value(series.parameter.displayName, point.value))
                .interpolationMethod(.catmullRom)
                AreaMark(x: .value("Zeit", point.timestamp),
                         y: .value(series.parameter.displayName, point.value))
                .opacity(0.15)
            }
            .frame(height: 220)
        } else if !viewModel.isLoading {
            ContentUnavailableView("Keine Messwerte",
                                   systemImage: "chart.xyaxis.line",
                                   description: Text("Für diesen Zeitraum liegen keine Daten vor."))
                .frame(height: 220)
        }
    }

    private func weatherCard(_ weather: WeatherSnapshot) -> some View {
        HStack {
            Image(systemName: weather.symbolName).font(.title)
            VStack(alignment: .leading) {
                Text("Wetter").font(.caption).foregroundStyle(.secondary)
                Text("\(weather.temperatureFormatted) · \(weather.conditionDescription)")
            }
            Spacer()
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
