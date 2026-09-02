//
//  SeatView.swift
//  YuMinigroup
//
//  Android fragment.SeatFragment(fragment_seat.xml: CollapsingToolbarLayout 240dp + yu_library_seat01
//  이미지 + bg_gradient_seat + RecyclerView) 대응 — 드로어 "도서관 좌석" 루트 화면(스펙 §4.3).
//
//  CollapsingListScaffold 판단 근거: CollapsingHeader.swift의 navigationIcon 파라미터는
//  AppToolbar.NavigationIcon(.menu/.back) 그대로를 받고, HeaderView가 매 케이스를 AppToolbar에
//  그대로 넘긴다(AppToolbar.swift의 `if navigationIcon == .menu` 분기가 실제로 햄버거 버튼을 그린다) —
//  즉 킷이 "탭 없는 드로어 루트(.menu)" 모드를 이미 지원하므로 GroupMainView식 폴백은 불필요하다.
//  showTabs: false를 주면 HeaderView가 탭 바 자체를 건너뛰고(collapsedHeight도 tabHeight를 더하지
//  않는다), GroupView처럼 tabTitles/selectedTab/onTabSelected는 각각 빈 배열/.constant(0)/no-op으로
//  채워 넣기만 하면 된다.
//
//  탭 → WebViewScreen push가 있으므로 UnivNoticeView/GroupMainView 관례대로 이 화면 자신이 로컬
//  NavigationView 조상을 둔다(MainContentRouter 트리에는 NavigationView가 없음). 드로어 루트이므로
//  시스템 네비게이션 바는 navigationBarHiddenCompat()로 숨기고, CollapsingListScaffold 내부
//  AppToolbar(.menu)가 유일한 상단 바가 된다 — GroupView(그룹 상세, push 모드라 시스템 백 버튼과
//  틴트/배경 블렌딩이 필요)와 달리 이 화면은 실제 시스템 바를 숨기므로 별도 블렌딩 모디파이어가
//  불필요하다.
//
//  콘텐츠는 RefreshableLazyColumn(Task 12 킷, GroupView 4탭 전용 "do NOT modify" 대상 — refreshable{}
//  본문이 실제로 아무 콜백도 안 부르는 가짜 1초 대기라 Tab1View들은 pull-to-refresh가 체감상 동작하지
//  않는다는 한계가 있다) 대신, UnivNoticeView처럼 평범한 ScrollView + CollapsingHeaderSpacer +
//  .refreshable { viewModel.refresh() }를 직접 구성한다 — 이 화면은 스펙이 "refresh 시 중앙 스피너
//  억제"를 요구하는데(SeatViewModel.fetch(isRefresh:)), 그 콜백이 실제로 호출돼야 그 요구가 의미
//  있으므로 킷의 가짜 refreshable로는 이 계약을 만족할 수 없다.
//

import SwiftUI

struct SeatView: View {
    @StateObject private var viewModel = SeatViewModel()

    let onMenuClick: () -> Void

    // CollapsingListScaffold 필수 파라미터지만 이 화면엔 탭이 없다(showTabs: false) — selectedTab은
    // 항상 0, onTabSelected는 no-op.
    @State private var selectedTab = 0
    @State private var collapseOffset: CGFloat = 0

    var body: some View {
        NavigationView {
            CollapsingListScaffold(
                title: "도서관 좌석",
                navigationIcon: .menu,
                onNavigationClick: onMenuClick,
                showTabs: false,
                tabTitles: [],
                selectedTab: $selectedTab,
                collapseOffset: $collapseOffset,
                onTabSelected: { _ in },
                imageHeight: 240,
                headerBackground: { headerBackground }
            ) { headerHeight, _ in
                ZStack {
                    ScrollView {
                        CollapsingHeaderSpacer()

                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.state.items) { item in
                                NavigationLink(destination: WebViewScreen(
                                    urlString: EndPoint.librarySeatDetail(id: item.id),
                                    title: "도서관 좌석"
                                )) {
                                    SeatItemCell(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, headerHeight)
                    }
                    .coordinateSpace(name: collapsingScrollCoordinateSpace)
                    .refreshable {
                        viewModel.refresh()
                    }

                    if viewModel.state.isLoading && viewModel.state.items.isEmpty {
                        ProgressView()
                            .padding(.top, headerHeight + 60)
                    }
                }
            }
            .navigationBarHiddenCompat()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .toast(message: $viewModel.state.message)
    }

    // Android CollapsingToolbarLayout의 ImageView(yu_library_seat01, centerCrop) + bg_gradient_seat
    // View 대응 — GroupView.headerBackground(커버 사진 분기)와 동일한 하단 그라디언트 스크림.
    private var headerBackground: some View {
        ZStack(alignment: .bottom) {
            Image("yu_library_seat01")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                .frame(height: 100)
        }
    }
}

// Android res/layout/seat_item.xml(CardView) 대응 — 이름 18pt singleLine / 가로 ProgressView /
// 상태 15pt + 우측 "[사용중/총]" 12pt. UnivNoticeView.BbsItemCell과 동일한 카드 스타일.
private struct SeatItemCell: View {
    let item: SeatItem

    // Android ProgressBar android:progress="@{BindingUtils.parseInt(item.percentageInteger)}" 대응 —
    // 파싱 실패 시 0(Android Integer.parseInt 실패 시 BindingUtils.parseInt도 0을 반환).
    private var percentage: Double {
        Double(item.percentageInteger) ?? 0
    }

    // Android BindingUtils.getSeatCountText: "[" + parseInt(occupied) + "/" + count(원문) + "]" —
    // occupied만 정수화하고 count는 원문 그대로 이어붙인다.
    private var occupiedText: String {
        "[\(Int(item.occupied) ?? 0)/\(item.count)]"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.system(size: 18))
                .lineLimit(1)
                .foregroundColorCompat(.primary)

            ProgressView(value: percentage, total: 100)

            HStack {
                Text(item.status)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                Spacer()

                Text(occupiedText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
