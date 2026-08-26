import SwiftUI

struct RefreshableLazyColumn<Row: View>: View {
    let items: [String]
    let headerHeight: CGFloat
    let isRefreshEnabled: Bool
    let isScrollTrackingEnabled: Bool
    let row: (String) -> Row

    @State private var isRefreshing = false

    var body: some View {
        content
            .refreshable {
                guard isRefreshEnabled else { return }
                isRefreshing = true
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                isRefreshing = false
            }
    }

    private var content: some View {
        ScrollView {
            CollapsingHeaderSpacer(
                isScrollTrackingEnabled: isScrollTrackingEnabled
            )
            LazyVStack(spacing: 0) {
                ForEach(items, id: \.self) { item in
                    row(item)
                }
            }
            .padding(.top, headerHeight)
        }
        .coordinateSpace(name: collapsingScrollCoordinateSpace)
    }

    init(
        items: [String],
        headerHeight: CGFloat,
        isRefreshEnabled: Bool,
        isScrollTrackingEnabled: Bool = true,
        @ViewBuilder content row: @escaping (String) -> Row
    ) {
        self.items = items
        self.headerHeight = headerHeight
        self.isRefreshEnabled = isRefreshEnabled
        self.isScrollTrackingEnabled = isScrollTrackingEnabled
        self.row = row
    }
}
