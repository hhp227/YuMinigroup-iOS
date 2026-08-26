import SwiftUI

let collapsingScrollCoordinateSpace = "collapsing-scroll"

struct CollapsingAppBarState {
    let isExpanded: Bool
    let setExpanded: (Bool) -> Void
}

struct CollapsingListScaffold<HeaderBG: View, Content: View>: View {
    let title: String
    let navigationIcon: NavigationIcon
    let onNavigationClick: () -> Void
    let showTabs: Bool
    let tabTitles: [String]
    @Binding var selectedTab: Int
    @Binding var collapseOffset: CGFloat
    let onTabSelected: (Int) -> Void
    let imageHeight: CGFloat
    let headerBackground: () -> HeaderBG
    let content: (_ headerHeight: CGFloat, _ appBarState: CollapsingAppBarState) -> Content

    @State private var ignoresNextExpansion = false
    @State private var scrollOffset: CGFloat = 0
    @State private var prevRawOffset: CGFloat = 0

    private let toolbarHeight: CGFloat = 56
    private let tabHeight: CGFloat = 48

    init(
        title: String,
        navigationIcon: NavigationIcon,
        onNavigationClick: @escaping () -> Void,
        showTabs: Bool,
        tabTitles: [String],
        selectedTab: Binding<Int>,
        collapseOffset: Binding<CGFloat>,
        onTabSelected: @escaping (Int) -> Void,
        imageHeight: CGFloat = 256,
        @ViewBuilder headerBackground: @escaping () -> HeaderBG,
        content: @escaping (_ headerHeight: CGFloat, _ appBarState: CollapsingAppBarState) -> Content
    ) {
        self.title = title
        self.navigationIcon = navigationIcon
        self.onNavigationClick = onNavigationClick
        self.showTabs = showTabs
        self.tabTitles = tabTitles
        self._selectedTab = selectedTab
        self._collapseOffset = collapseOffset
        self.onTabSelected = onTabSelected
        self.imageHeight = imageHeight
        self.headerBackground = headerBackground
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            let expandedHeight = topInset + imageHeight
            let collapsedHeight = topInset + toolbarHeight + (showTabs ? tabHeight : 0)
            let maxCollapse = max(0, expandedHeight - collapsedHeight)
            let currentOffset = min(max(collapseOffset, 0), maxCollapse)
            let headerHeight = expandedHeight - currentOffset
            let contentTopPadding = expandedHeight - max(currentOffset - scrollOffset, 0)
            let fraction = maxCollapse == 0 ? 1 : currentOffset / maxCollapse
            let appBarState = CollapsingAppBarState(
                isExpanded: currentOffset <= 0.5,
                setExpanded: { expanded in
                    collapseOffset = expanded ? 0 : maxCollapse
                }
            )

            ZStack(alignment: .top) {
                content(contentTopPadding, appBarState)
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { contentOffset in
                        guard !contentOffset.isNaN else { return }

                        // rawOffset: positive = scrolled up, negative = bouncing past top
                        let rawOffset = -contentOffset
                        let newScrollOffset = min(max(rawOffset, 0), maxCollapse)

                        if ignoresNextExpansion {
                            scrollOffset = newScrollOffset
                            prevRawOffset = rawOffset
                            ignoresNextExpansion = false
                            // Normalize collapseOffset from infinity to maxCollapse
                            if collapseOffset > maxCollapse {
                                collapseOffset = maxCollapse
                            }
                            return
                        }

                        let delta = newScrollOffset - scrollOffset
                        // Bounce delta: change in the bounce amount only (not mixed with scroll)
                        let bounceDelta = min(rawOffset, 0) - min(prevRawOffset, 0)

                        scrollOffset = newScrollOffset
                        prevRawOffset = rawOffset

                        if delta > 0 {
                            // Scrolled further up: collapse header by delta
                            collapseOffset = min(collapseOffset + delta, maxCollapse)
                        } else if rawOffset < 0 && bounceDelta < 0 {
                            // Bouncing past top and pulling harder: expand header
                            collapseOffset = max(min(collapseOffset, maxCollapse) + bounceDelta, 0)
                        }
                        // delta <= 0 and not bouncing: list scrolling down, header stays collapsed
                    }

                HeaderView(
                    title: title,
                    navigationIcon: navigationIcon,
                    onNavigationClick: onNavigationClick,
                    showTabs: showTabs,
                    tabTitles: tabTitles,
                    selectedTab: $selectedTab,
                    onTabSelected: onTabSelected,
                    headerHeight: headerHeight,
                    imageOpacity: 1 - fraction,
                    topInset: topInset,
                    headerBackground: headerBackground
                )
            }
            .ignoresSafeArea(edges: .top)
            .onChange(of: selectedTab) { _ in
                ignoresNextExpansion = true
                prevRawOffset = 0
            }
        }
    }
}

private struct HeaderView<HeaderBG: View>: View {
    let title: String
    let navigationIcon: NavigationIcon
    let onNavigationClick: () -> Void
    let showTabs: Bool
    let tabTitles: [String]
    @Binding var selectedTab: Int
    let onTabSelected: (Int) -> Void
    let headerHeight: CGFloat
    let imageOpacity: CGFloat
    let topInset: CGFloat
    let headerBackground: () -> HeaderBG

    var body: some View {
        ZStack(alignment: .top) {
            Color.accentColor
            headerBackground()
                .opacity(imageOpacity)

            VStack(spacing: 0) {
                Color.clear.frame(height: topInset)
                AppToolbar(
                    title: title,
                    navigationIcon: navigationIcon,
                    onNavigationClick: onNavigationClick,
                    transparent: true
                )
                Spacer(minLength: 0)
                if showTabs {
                    HStack(spacing: 0) {
                        ForEach(tabTitles.indices, id: \.self) { index in
                            TabButton(title: tabTitles[index], isSelected: selectedTab == index) {
                                selectedTab = index
                                onTabSelected(index)
                            }
                        }
                    }
                    .frame(height: 48)
                }
            }
        }
        .frame(height: headerHeight)
        .clipped()
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VStack(spacing: 0) {
                Spacer()
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColorCompat(isSelected ? Color.white : Color.white.opacity(0.82))
                Spacer()
                Rectangle()
                    .fill(isSelected ? Color.black.opacity(0.7) : Color.clear)
                    .frame(height: 2)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .nan

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if !next.isNaN {
            value = next
        }
    }
}

struct CollapsingHeaderSpacer: View {
    var isScrollTrackingEnabled = true

    var body: some View {
        Group {
            if isScrollTrackingEnabled {
                Color.clear
                    .frame(height: 0)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: proxy.frame(in: .named(collapsingScrollCoordinateSpace)).minY
                            )
                        }
                    )
            } else {
                Color.clear
                    .frame(height: 0)
            }
        }
    }
}
