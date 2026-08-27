//
//  GroupView.swift
//  YuMinigroup
//
//  Android fragment_tab_host_layout.xml + TabHostLayoutFragment 대응 — 그룹 상세 화면의 핵심.
//  200dp CollapsingToolbar(titleEnabled=false라 그룹명은 접혔을 때도 펼쳐졌을 때도 시스템 네비게이션
//  바 타이틀 하나로 고정 — Android가 SupportActionBar 타이틀에 그룹명을 박아두는 것과 동일 발상)
//  위에 4탭(소식/일정/맴버/설정) + selectedTab == 0일 때만 보이는 FAB을 얹는다.
//
//  구조는 ParallaxTabLayout 키트의 Screen/ParallaxTabScreen.swift(read-only 예제 — CollapsingHeader가
//  Task 2에서 일반화되기 전 버전)를 그대로 미러하되, 일반화되며 늘어난 CollapsingListScaffold
//  파라미터(tabTitles/imageHeight/headerBackground)를 채워 넣는다. imageHeight는 Android 200dp를
//  그대로 포인트로 미러(예제 기본값 256이 아니라 200을 명시 전달) — maxCollapse = 200 - 56(toolbar)
//  - 48(tab) = 96(예제의 152 = 256-56-48과 같은 계산 방식).
//
//  헤더는 Android의 커버 사진/로고 2분기(iv_header vs iv_title, "share_nophoto" 포함 여부)를 그대로
//  옮긴다. 커버 사진이 있으면 RemoteImage + 하단 그라디언트 스크림(Android bg_gradient 상당),
//  없으면(경북대 소모임에는 없는, 영남대 전용 케이스) accentColor 배경 위에 중앙 로고 — 브랜드 로고
//  에셋이 없어 Splash/LoginView가 이미 쓰고 있는 "graduationcap.fill" SF Symbol 자리표시를 그대로
//  재사용한다(별도 로고 에셋을 새로 만들지 않는다).
//
//  탭 0(소식)은 Task 12부터 Tab1View로, 탭 1(일정)은 Task 13부터 Tab2View로, 탭 2(맴버)는 Task 14부터
//  Tab3View로, 탭 3(설정)은 Task 15부터 Tab4View로 교체됐다 — GroupViewModel은 브리프 지시대로 건드리지
//  않으므로 Tab1ViewModel/Tab2ViewModel/Tab3ViewModel/Tab4ViewModel은 이 화면이 직접 소유하는 별도
//  StateObject다(탭 전환/collapse 같은 범용 UI 상태만 계속 GroupViewModel 몫). Tab2ViewModel은
//  Tab1ViewModel/Tab3ViewModel/Tab4ViewModel과 달리 groupId/groupKey가 필요 없다 — Android Tab2Fragment
//  처럼 그룹 데이터가 아니라 YU 학사일정(EndPoint.schedule) 전역 XML을 보여주기 때문에 groupItem과
//  무관하게 인자 없이 생성한다. Tab3ViewModel은 Tab1ViewModel과 같은 groupId만 필요하다(멤버 목록에는
//  Firebase key 매핑이 없어 groupKey는 불필요). Tab4ViewModel은 groupItem 전체(isAdmin/id/key)가
//  필요해 Tab1ViewModel처럼 GroupItem을 그대로 받는다. 네 탭 모두 SecondTabScreen 예제와 동일하게
//  ScrollView + CollapsingHeaderSpacer + coordinateSpace로 구성해, 활성 탭만 자신의 scrollOffset을
//  GroupViewModel에 보고하도록 한다(비활성 탭은 isScrollTrackingEnabled: false라 preference를 아예
//  만들지 않는다 — reduce가 NaN을 무시하는 메커니즘 그대로).
//
//  탭 3(설정)의 Tab4View는 소모임 탈퇴/폐쇄 성공 시 Tab4ViewModel.didExit를 관찰해 자신의
//  @Environment(\.presentationMode)로 이 화면(GroupView) 자체를 pop한다 — GroupView는 GroupMainView의
//  로컬 NavigationView에 NavigationLink로 push되어 있으므로, 자식 뷰의 dismiss() 호출이 그 push
//  컨텍스트를 그대로 pop한다(GroupView 자체를 수정할 필요가 없는 이유 — Task 15 브리프가 검토를 요구한
//  "GroupView가 dismiss를 스레딩해야 하는지" 질문에 대한 답: 아니다, presentationMode가 환경을 타고
//  내려가는 것만으로 충분하다).
//
//  FAB(탭0 전용)은 Task 17부터 CreateArticleView(.create(group:))를 .fullScreenCover로 띄운다 — FAB과
//  fullScreenCover 둘 다 CollapsingListScaffold의 content 클로저 안으로 옮겼는데(예전엔 바깥 ZStack이
//  CollapsingListScaffold 전체를 감쌌다), appBarState(Android appbarLayoutExpand 미러인 setExpanded(true))가
//  그 클로저 인자로만 주어지기 때문이다 — 작성 성공 시 tab1ViewModel.upsert(article)로 소식 탭에
//  반영하고 appBarState.setExpanded(true)로 헤더를 다시 펼친다. 시각적 배치는 그대로다(클로저가
//  반환하는 뷰도 GeometryReader가 내려주는 화면 전체 크기를 그대로 받으므로 우하단 FAB 위치가
//  바뀌지 않는다 — body의 ZStack(alignment: .bottomTrailing) 코멘트 참고).
//
//  이 화면은 GroupMainView가 만든 로컬 NavigationView 안으로 push되며, PlaceholderView와 마찬가지로
//  자체적으로 navigationBarHiddenCompat()를 걸지 않는다 — 시스템 백 버튼이 자연스럽게 나타나고,
//  그 위에 CollapsingListScaffold 전용 배경/틴트 색만 얹는다(예제 ParallaxTabScreen 로직 그대로).
//
//  3차 Task 8 — Tab4View에 onGroupUpdated: { viewModel.applyGroupUpdate(...) }를 넘긴다. SettingsView가
//  모임정보 저장에 성공하면 이 클로저를 거쳐 GroupViewModel.groupItem의 name/description_/joinType
//  (+이미지 변경 시 image)만 표적으로 바뀌고, 위 navigationTitle(viewModel.groupItem.name)과
//  headerBackground(hasCoverPhoto)가 같은 프로퍼티를 읽고 있어 재조회 없이 자동으로 갱신된다.
//  Tab4ViewModel.groupItem은 이 갱신과 별개로 그대로 둔다(건드리지 않음) — GroupView.init에서 딱 한
//  번 스냅샷으로 받은 상수라 이후 GroupViewModel이 바뀌어도 따라 갱신되지 않지만, Tab4ViewModel이
//  groupItem을 쓰는 곳은 actionLabel/confirmMessage(isAdmin 기반, 소모임 설정 저장으로는 안 바뀜)와
//  leaveOrClose(id/key, 역시 안 바뀜)뿐이라 무해하다 — 유일한 예외는 이 화면(Tab4View)이 "설정" 행을
//  다시 탭했을 때 SettingsView(groupItem: viewModel.groupItem, ...)에 넘어가는 groupItem이 GroupView가
//  아니라 Tab4ViewModel의 스냅샷이라는 점인데, SettingsView의 모임정보 탭은 어차피 fetchGroupSetting으로
//  이름/설명/joinType을 서버에서 다시 읽어와 프리필하므로 그 값 자체는 항상 최신이고, 유일하게 stale할
//  수 있는 건 이미지 프리뷰 소스(existingImageURL = groupItem.image, 서버 재조회 대상이 아님)뿐이다
//  (브리프가 이 정도 재사용을 명시적으로 허용했다 — "joinType 무관").
//

import SwiftUI

struct GroupView: View {
    @StateObject private var viewModel: GroupViewModel

    // 탭 0(소식) 전용 — GroupViewModel과 분리된 별도 StateObject(위 헤더 코멘트 참고).
    @StateObject private var tab1ViewModel: Tab1ViewModel

    // 탭 1(일정) 전용 — groupItem 의존이 없어 커스텀 init(groupItem:) 밖에서 바로 기본값으로 생성한다.
    @StateObject private var tab2ViewModel = Tab2ViewModel()

    // 탭 2(맴버) 전용 — groupId만 필요하다(Android Tab3Fragment.newInstance(grpId)와 동일. groupKey는
    // Firebase 매핑이 없는 이 화면에 불필요).
    @StateObject private var tab3ViewModel: Tab3ViewModel

    // 탭 3(설정) 전용 — groupItem 전체(isAdmin/id/key)가 필요하다(Android Tab4Fragment.newInstance의
    // admin/grp_id/key 인자 3개를 GroupItem 하나로 대신 받는다).
    @StateObject private var tab4ViewModel: Tab4ViewModel

    // Task 17 — 탭0 FAB이 여는 게시글 작성 모달의 표시 여부. content 클로저 안(headerHeight/appBarState가
    // 실제로 잡히는 스코프)에서 fullScreenCover를 달기 때문에, 이 Bool 자체는 outer body 어디서든 접근
    // 가능한 평범한 @State로 둔다.
    @State private var showCreateArticle = false

    // Task 9 — 툴바 채팅 아이콘이 여는 그룹 채팅방(숨김 NavigationLink) 표시 여부.
    @State private var showChat = false

    // imageHeight(200) - toolbarHeight(56) - tabHeight(48). CollapsingListScaffold 내부 계산과
    // 반드시 같은 값이어야 한다.
    private let maxCollapse: CGFloat = 96

    private var isCollapsed: Bool {
        viewModel.collapseOffset >= maxCollapse
    }

    init(groupItem: GroupItem) {
        _viewModel = StateObject(wrappedValue: GroupViewModel(groupItem: groupItem))
        _tab1ViewModel = StateObject(wrappedValue: Tab1ViewModel(groupId: groupItem.id, groupKey: groupItem.key))
        _tab3ViewModel = StateObject(wrappedValue: Tab3ViewModel(groupId: groupItem.id))
        _tab4ViewModel = StateObject(wrappedValue: Tab4ViewModel(groupItem: groupItem))
    }

    var body: some View {
        CollapsingListScaffold(
            title: viewModel.groupItem.name,
            navigationIcon: .back,
            onNavigationClick: {},
            showTabs: true,
            tabTitles: viewModel.tabTitles,
            selectedTab: $viewModel.selectedTab,
            collapseOffset: $viewModel.collapseOffset,
            onTabSelected: onTabSelected,
            imageHeight: 200,
            headerBackground: { headerBackground }
        ) { headerHeight, appBarState in
            // FAB+작성 모달을 이 클로저 안에 두는 이유: appBarState(CollapsingAppBarState)는 이
            // 스코프에서만 살아있다(CollapsingListScaffold.body 참고) — 작성 성공 시 Android
            // appbarLayoutExpand 미러인 appBarState.setExpanded(true)를 부르려면 여기서 fullScreenCover를
            // 달아야 한다. ZStack(alignment: .bottomTrailing)이 이 클로저가 반환하는 뷰 전체(탭 콘텐츠와
            // 같은 크기 — GeometryReader가 화면 전체를 내려주므로 이전에 바깥 ZStack이 감쌌을 때와
            // 시각적으로 동일한 우하단 배치)를 감싸므로 FAB 위치는 바뀌지 않는다.
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Tab1View(
                        viewModel: tab1ViewModel,
                        headerHeight: headerHeight,
                        appBarState: appBarState,
                        isActive: viewModel.selectedTab == 0,
                        scrollOffset: $viewModel.tab1ScrollOffset
                    )
                    .opacity(viewModel.selectedTab == 0 ? 1 : 0)
                    .allowsHitTesting(viewModel.selectedTab == 0)

                    Tab2View(
                        viewModel: tab2ViewModel,
                        headerHeight: headerHeight,
                        appBarState: appBarState,
                        isActive: viewModel.selectedTab == 1,
                        scrollOffset: $viewModel.tab2ScrollOffset
                    )
                    .opacity(viewModel.selectedTab == 1 ? 1 : 0)
                    .allowsHitTesting(viewModel.selectedTab == 1)

                    Tab3View(
                        viewModel: tab3ViewModel,
                        headerHeight: headerHeight,
                        appBarState: appBarState,
                        isActive: viewModel.selectedTab == 2,
                        scrollOffset: $viewModel.tab3ScrollOffset
                    )
                    .opacity(viewModel.selectedTab == 2 ? 1 : 0)
                    .allowsHitTesting(viewModel.selectedTab == 2)

                    Tab4View(
                        viewModel: tab4ViewModel,
                        headerHeight: headerHeight,
                        appBarState: appBarState,
                        isActive: viewModel.selectedTab == 3,
                        scrollOffset: $viewModel.tab4ScrollOffset,
                        onGroupUpdated: { name, description, joinType, imageURL in
                            viewModel.applyGroupUpdate(name: name, description: description, joinType: joinType, imageURL: imageURL)
                        }
                    )
                    .opacity(viewModel.selectedTab == 3 ? 1 : 0)
                    .allowsHitTesting(viewModel.selectedTab == 3)
                }

                if viewModel.selectedTab == 0 {
                    FloatingActionButton(action: { showCreateArticle = true })
                        .padding(16)
                }
            }
            .fullScreenCover(isPresented: $showCreateArticle) {
                CreateArticleView(mode: .create(group: viewModel.groupItem)) { article in
                    tab1ViewModel.upsert(article)
                    appBarState.setExpanded(true)
                }
            }
        }
        .navigationTitle(viewModel.groupItem.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackgroundColorCompat(isCollapsed ? UIColor(Color.accentColor) : .clear)
        .navigationBarTintColorCompat(isCollapsed ? .white : UIColor(Color.accentColor))
        // Task 9 — 툴바 채팅 아이콘. 틴트는 위 navigationBarTintColorCompat를 그대로 따르므로
        // 접힘/펼침 색 전환이 자동 적용된다.
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showChat = true }) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")   // Android action_chat("채팅방") 대응
                }
            }
        }
        .background(
            NavigationLink(isActive: $showChat) {
                ChatView(receiver: viewModel.groupItem.key,   // 그룹 Firebase key — nil이면 ChatView가 안내 표시
                         isGroupChat: true,
                         chatName: viewModel.groupItem.name)
            } label: { EmptyView() }
            .hidden()
        )
    }

    // 탭 전환 시 목적 탭이 이미 최상단이 아니면(Android가 접힌 채로 페이지만 바뀌는 것과 동일한
    // 체감) 헤더를 강제로 접은 채 유지한다 — 예제 ParallaxTabScreen의
    // "offset < -0.5 ⇒ collapseOffset = .greatestFiniteMagnitude" 분기를 4탭으로 확장한 것.
    private func onTabSelected(_ newTab: Int) {
        let offset: CGFloat

        switch newTab {
        case 0:
            offset = viewModel.tab1ScrollOffset
        case 1:
            offset = viewModel.tab2ScrollOffset
        case 2:
            offset = viewModel.tab3ScrollOffset
        default:
            offset = viewModel.tab4ScrollOffset
        }
        if offset < -0.5 {
            viewModel.collapseOffset = .greatestFiniteMagnitude
        }
    }

    @ViewBuilder
    private var headerBackground: some View {
        if viewModel.hasCoverPhoto {
            ZStack(alignment: .bottom) {
                RemoteImage(urlString: viewModel.groupItem.image)
                    .aspectRatio(contentMode: .fill)
                    .clipped()

                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 100)
            }
        } else {
            ZStack {
                Color.accentColor

                Image(systemName: "graduationcap.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 66)
                    .foregroundColorCompat(Color.white)
            }
        }
    }
}
