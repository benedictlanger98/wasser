import SwiftUI

/// The SEARCH screen: a focused text field with an "Abbrechen" action and a
/// results list of all catalogue stations filtered by the query. Selecting a
/// result saves it and opens its detail. Uses the system keyboard (the mock's
/// drawn keyboard is a web-prototype artifact).
struct SearchView: View {
    @EnvironmentObject private var repository: WaterRepository
    @EnvironmentObject private var router: AppRouter
    @FocusState private var focused: Bool

    private var results: [MeasurementStation] {
        repository.stations(matching: router.query)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if results.isEmpty {
                Spacer()
                Text("Keine Treffer")
                    .font(.system(size: 15)).foregroundStyle(Color(white: 0.92).opacity(0.5))
                Spacer()
            } else {
                List(results) { station in
                    ResultRow(station: station)
                        .listRowBackground(Color.black)
                        .listRowSeparatorTint(.white.opacity(0.1))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            repository.addFavorite(station)
                            router.showDetail(station.id)
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear { focused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(white: 0.92).opacity(0.6))
                TextField("", text: $router.query, prompt:
                            Text("Gewässer oder Ort suchen")
                                .foregroundColor(Color(white: 0.92).opacity(0.6)))
                    .focused($focused)
                    .foregroundStyle(.white)
                    .autocorrectionDisabled()
            }
            .padding(.vertical, 9).padding(.horizontal, 12)
            .background(Color(red: 0.46, green: 0.46, blue: 0.50).opacity(0.24),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Button("Abbrechen") { router.closeSearch() }
                .font(.system(size: 17))
                .foregroundStyle(Color(red: 0.04, green: 0.52, blue: 1.0))
        }
        .padding(.horizontal, 16)
        .padding(.top, 62).padding(.bottom, 10)
    }
}

private struct ResultRow: View {
    let station: MeasurementStation
    private var theme: WaterTheme { WaterTheme.forType(station.waterBodyType) }

    var body: some View {
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(theme.cardGradient)
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(station.waterBodyName).font(.system(size: 17)).foregroundStyle(.white)
                Text(station.locationSubtitle.isEmpty
                     ? station.waterBodyType.displayName
                     : "\(station.locationSubtitle) · \(station.waterBodyType.displayName)")
                    .font(.system(size: 13)).foregroundStyle(Color(white: 0.92).opacity(0.6))
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
