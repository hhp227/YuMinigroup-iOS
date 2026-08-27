//
//  TimetableView.swift
//  YuMinigroup
//
//  Android fragment.TimetableFragment(fragment_tabs.xml: Toolbar+TabLayout+ViewPager) 대응 — 드로어
//  "시간표" 루트 화면(스펙 §4.2). 이 화면은 더 push할 자식이 없는 리프다(학기시간표 셀 탭은 .alert,
//  모의시간표는 Task 5의 커스텀 오버레이 다이얼로그 — 둘 다 NavigationLink push가 아니다). 그래서
//  UnivNoticeView/SeatView(자신이 로컬 NavigationView 조상을 둬야 하는 화면들)와 달리
//  WebViewScreen/PlaceholderView의 "드로어 루트" 모드처럼 NavigationView 없이 VStack(AppToolbar+본문)
//  으로 충분하다(MainContentRouter 트리에는 NavigationView가 없다는 전제도 동일).
//
//  탭 바: Android TabLayout(fragment_tabs.xml — background=colorPrimary, tabTextColor=#ffffff,
//  tabSelectedTextColor=#ffffff, tabIndicatorColor=colorAccent) 대응. GroupView/CollapsingHeader의
//  탭 킷은 CollapsingToolbar 전용 내부 컴포넌트(HeaderView가 collapsedHeight 계산에 탭 높이를 끼워
//  넣는 식으로 결합돼 있다)라 이 화면처럼 콜랩싱 헤더가 없는 곳엔 재사용할 수 없다 — 브리프 권장대로
//  accentColor(colorPrimary 대응) 배경의 커스텀 HStack 버튼 2개로 직접 짠다. 선택 탭은 굵게+흰 밑줄
//  인디케이터, 비선택 탭은 보통 굵기 흰 텍스트로 tabTextColor=#ffffff를 양쪽에 공통 적용한다.
//  Android colorAccent(#FF4081) 인디케이터색은 이 화면 전용 새 하드코딩 색을 끌어오지 않고 흰 밑줄로
//  근사한다(시각적 의도 — 선택 강조 — 만 유지, 스펙이 인디케이터 색을 못박지 않았다).
//
//  탭 2번째(모의시간표 작성)는 MockTimetableTab(Task 5) — SemesterTimetableTab과 같은 이유로
//  @StateObject를 탭 전환 경계에서 살고 죽게 둔다(모의시간표는 UserDefaults 영속이라 탭을 벗어났다
//  돌아와도 init에서 다시 읽어오면 그대로 복원된다 — 별도 캐시가 필요 없다).
//

import SwiftUI

struct TimetableView: View {
    let onMenuClick: () -> Void

    init(onMenuClick: @escaping () -> Void) {
        self.onMenuClick = onMenuClick
    }

    @State private var selectedTab = 0

    private static let tabTitles = ["학기시간표", "모의시간표 작성"]

    var body: some View {
        VStack(spacing: 0) {
            AppToolbar(title: "시간표", navigationIcon: .menu, onNavigationClick: onMenuClick)

            tabBar

            if selectedTab == 0 {
                SemesterTimetableTab()
            } else {
                MockTimetableTab()
            }
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(TimetableView.tabTitles.enumerated()), id: \.offset) { index, title in
                Button(action: { selectedTab = index }) {
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 14, weight: selectedTab == index ? .bold : .regular))
                            .foregroundColorCompat(Color.white)
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(selectedTab == index ? Color.white : Color.clear)
                            .frame(height: 2)
                    }
                }
                .padding(.top, 12)
            }
        }
        .background(Color.accentColor)
    }
}

// Android MockTimeTableFragment(fragment_mock_timetable.xml) 대응 — 둘째 탭. viewModel은 UserDefaults를
// 소스로 삼으므로 SemesterTimetableTab과 같은 @StateObject 경계를 둬도 데이터 유실이 없다(탭을
// 벗어났다 돌아오면 init이 UserDefaults를 다시 읽어 그대로 복원).
private struct MockTimetableTab: View {
    @StateObject private var viewModel = MockTimetableViewModel()

    var body: some View {
        MockTimetableView(viewModel: viewModel)
    }
}

// Android SemesterTimeTableFragment(fragment_timetable.xml: ll_timetable + pb_group) 대응 — 첫 탭.
// VM은 이 탭이 화면에 있을 때만 살아있다: 탭을 벗어나면(selectedTab이 1로 바뀌면) 이 뷰 자체가 트리에서
// 빠져 @StateObject가 해제되고, 다시 돌아오면 새로 생성돼 init에서 재조회한다 — 스펙 §4.2 "영속성
// 없음(매번 조회)"과 자연히 맞아떨어진다(별도 캐시/didAppear 배선이 필요 없다).
private struct SemesterTimetableTab: View {
    @StateObject private var viewModel = SemesterTimetableViewModel()

    var body: some View {
        ZStack {
            SemesterTimetableGrid(table: viewModel.state.table)

            if viewModel.state.isLoading {
                ProgressView()
            }
        }
        .toast(message: $viewModel.state.message)
    }
}

// Android helper/ui/SemesterTimetableView.java(submitTable) 대응 — [[String]]을 6열 그리드로 세로
// 스택한다(행 0=요일 헤더). 셀 폭은 frame(maxWidth: .infinity)로 6열 균등 분배, 마진 1은 배경색을
// 칠한 뒤 바깥에 padding(1)을 둬서 만든다(패딩을 먼저 주면 색이 패딩까지 덮어 마진처럼 안 보인다).
//
// 높이(화면/20, 화면/14): 브리프가 GeometryReader/UIScreen.main.bounds 중 기존 관례를 확인 후 택하라고
// 지시했는데, 이 리포에서 GeometryReader는 전부 "스크롤 오프셋 추적"이나 "콜랩싱 헤더 크기" 용도로만
// 쓰이고(CollapsingHeader.swift, GroupView.swift) "화면 치수를 상수처럼 읽어 셀 높이를 정하는" 용도의
// 선례가 없다. Android 원본도 DisplayMetrics(디바이스 전체 해상도, 컨테이너 크기가 아니다)를 그대로
// 쓰므로, GeometryReader로 ScrollView 컨테이너 크기를 매 행마다 얻어오는 번거로운 배선보다
// UIScreen.main.bounds.height를 직접 쓰는 쪽이 Android 의도(디바이스 화면 치수 기준 비율)에 더 가깝다
// — 이 화면의 새 전례로 채택한다.
private struct SemesterTimetableGrid: View {
    let table: [[String]]

    @State private var selectedCellText: String?

    private static let columns = 6
    private static let headerColor = Color(red: 0.980, green: 0.957, blue: 0.753) // #FAF4C0
    private static let dataColor = Color(red: 0.945, green: 0.945, blue: 0.945)   // #F1F1F1

    private var headerHeight: CGFloat {
        UIScreen.main.bounds.height / 20
    }

    private var dataHeight: CGFloat {
        UIScreen.main.bounds.height / 14
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(table.enumerated()), id: \.offset) { rowIndex, row in
                    HStack(spacing: 0) {
                        ForEach(0..<SemesterTimetableGrid.columns, id: \.self) { columnIndex in
                            cell(text: columnIndex < row.count ? row[columnIndex] : "", isHeader: rowIndex == 0)
                        }
                    }
                }
            }
        }
        .alert(isPresented: Binding(
            get: { selectedCellText != nil },
            set: { isPresented in
                if !isPresented {
                    selectedCellText = nil
                }
            }
        )) {
            Alert(title: Text(selectedCellText ?? ""), dismissButton: .default(Text("닫기")))
        }
    }

    // Android textView.setOnClickListener(빈 텍스트는 리스너 자체를 안 붙임) 대응 — 빈 셀은 탭해도
    // 아무 반응이 없어야 하므로 onTapGesture를 조건부로만 건다.
    private func cell(text: String, isHeader: Bool) -> some View {
        Text(text)
            .font(.system(size: 10))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: isHeader ? headerHeight : dataHeight)
            .background(isHeader ? SemesterTimetableGrid.headerColor : SemesterTimetableGrid.dataColor)
            .padding(1)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !text.isEmpty else {
                    return
                }
                selectedCellText = text
            }
    }
}
