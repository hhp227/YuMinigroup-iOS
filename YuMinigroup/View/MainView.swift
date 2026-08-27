//
//  MainView.swift
//  YuMinigroup
//
//  Android activity.MainActivity + res/menu/activity_main_drawer.xml + layout/nav_header_main 대응 —
//  DrawerScaffold 셸(Task 2 포팅분, 이 태스크에서 원본 키트의 샘플 전용 라우트 열거형 하드코딩을
//  제거하고 DrawerMenuItem 배열 + 헤더 뷰 빌더로 일반화했다) 위에 드로어 메뉴(메인화면/영대소식/시간표/도서관 좌석/
//  순환버스 시간표/로그아웃, Android 순서 그대로 — 2차 Task 10이 "채팅"을 메인화면 다음에 추가해 7행)를
//  얹는다. groupMain 라우트는 Task 10(1차)에서 GroupMainView로 교체됐고, 나머지 라우트는 각자의
//  태스크(12~14 등)가 실제 화면으로 교체하기 전까지 PlaceholderView를 보여준다.
//  드로어 헤더(아바타/이름/이메일) 탭 → ProfileView(Task 19) 이동. DrawerScaffold(Task 2)의 header
//  클로저는 openDrawer 같은 "드로어 닫기" 콜백을 받지 않으므로(수정 범위 밖), ProfileView를
//  .fullScreenCover로 띄우기만 하고 드로어 자체는 열린 채로 둔다 — 모달을 닫으면 드로어가 열린
//  상태로 다시 보이는 정도는 DrawerScaffold를 건드리지 않기 위한 트레이드오프로 수용한다.
//
//  Task 10(1차): groupMain 라우트를 GroupMainView로 교체한다. DrawerScaffold.content 클로저는
//  @ViewBuilder가 아니라(DrawerScaffold.swift 수정 범위 밖) 단일 표현식만 반환할 수 있으므로,
//  분기 자체는 body가 암묵적으로 @ViewBuilder인 별도 View(MainContentRouter)로 옮겨 처리한다.
//
//  Task 10(2차, 이 태스크): chatList 라우트를 groupMain 바로 다음에 추가하고 ChatListView로 배선한다
//  (Android 드로어에는 없는 신설 메뉴 — 스펙 §4.5). 위 1차 Task 10과 번호가 같지만 별개 태스크다.
//
//  Task 1(3차): shuttleBus 라우트를 WebViewScreen(EndPoint.shuttleBus, 드로어 루트 모드)으로 교체한다
//  (스펙 §4.4) — VM 없이 URL/타이틀만 넘긴다.
//
//  Task 2(3차): univNotice 라우트를 UnivNoticeView로 교체한다(스펙 §4.1). 나머지(시간표/도서관 좌석)는
//  3차 후속 태스크가 교체하기 전까지 여전히 PlaceholderView다.
//
//  Task 3(3차): librarySeat 라우트를 SeatView로 교체한다(스펙 §4.3). 나머지(시간표)는 3차 후속 태스크가
//  교체하기 전까지 여전히 PlaceholderView다.
//
//  Task 4(3차): timetable 라우트를 TimetableView로 교체한다(스펙 §4.2). 이걸로 3차 대학유틸 4종 드로어
//  스텁이 모두 해소된다.
//

import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = MainViewModel()

    @State private var showProfile = false

    var body: some View {
        DrawerScaffold(
            menuItems: menuItems,
            header: { DrawerProfileHeader(user: viewModel.user, onTap: { showProfile = true }) },
            content: { openDrawer in
                MainContentRouter(route: viewModel.route, onMenuClick: openDrawer)
            }
        )
        .fullScreenCover(isPresented: $showProfile) {
            ProfileView()
        }
    }

    private var menuItems: [DrawerMenuItem] {
        MainRoute.allCases.map { route in
            DrawerMenuItem(
                id: String(describing: route),
                title: MainView.title(for: route),
                systemImage: MainView.systemImage(for: route),
                isSelected: viewModel.route == route,
                onSelect: { viewModel.route = route }
            )
        } + [
            DrawerMenuItem(
                id: "logout",
                title: "로그아웃",
                systemImage: "rectangle.portrait.and.arrow.right",
                isSelected: false,
                onSelect: viewModel.logout
            )
        ]
    }

    // MainContentRouter(같은 파일의 별도 타입)에서도 참조하므로 fileprivate — private으로는
    // 같은 파일이라도 다른 타입에서 접근할 수 없다.
    fileprivate static func title(for route: MainRoute) -> String {
        switch route {
        case .groupMain:
            return "메인화면"
        case .chatList:
            return "채팅"
        case .univNotice:
            return "영대소식"
        case .timetable:
            return "시간표"
        case .librarySeat:
            return "도서관 좌석"
        case .shuttleBus:
            return "순환버스 시간표"
        }
    }

    private static func systemImage(for route: MainRoute) -> String {
        switch route {
        case .groupMain:
            return "house.fill"
        case .chatList:
            return "bubble.left.and.bubble.right.fill"
        case .univNotice:
            return "newspaper.fill"
        case .timetable:
            return "calendar"
        case .librarySeat:
            return "building.columns.fill"
        case .shuttleBus:
            return "bus.fill"
        }
    }
}

// groupMain은 GroupMainView(Task 10)로, chatList는 ChatListView(2차 Task 10)로, shuttleBus는
// WebViewScreen(3차 Task 1)로, univNotice는 UnivNoticeView(3차 Task 2)로, librarySeat는
// SeatView(3차 Task 3)로, timetable은 TimetableView(3차 Task 4)로 라우팅한다 — 이걸로 3차 대학유틸
// 드로어 스텁(옛 default 분기의 PlaceholderView)이 전부 해소돼 MainRoute 전 케이스가 명시적으로
// 갈린다(default 분기 제거 — PlaceholderView는 여전히 Tab4View "공지사항" 스텁이 쓴다).
private struct MainContentRouter: View {
    let route: MainRoute
    let onMenuClick: () -> Void

    var body: some View {
        switch route {
        case .groupMain:
            GroupMainView(onMenuClick: onMenuClick)
        case .chatList:
            ChatListView(onMenuClick: onMenuClick)
        case .univNotice:
            UnivNoticeView(onMenuClick: onMenuClick)
        case .timetable:
            TimetableView(onMenuClick: onMenuClick)
        case .librarySeat:
            SeatView(onMenuClick: onMenuClick)
        case .shuttleBus:
            WebViewScreen(urlString: EndPoint.shuttleBus, title: "순환버스 시간표", onMenuClick: onMenuClick)
        }
    }
}

private struct DrawerProfileHeader: View {
    let user: User?
    let onTap: () -> Void

    var body: some View {
        ZStack {
            Color.gray

            RemoteImage(
                urlString: user?.uid.map(EndPoint.userImage(uid:)),
                placeholder: Image(systemName: "person.crop.circle.fill")
            )
            .frame(width: 90, height: 90)
            .clipShape(Circle())
            .foregroundColorCompat(Color.white)

            VStack(alignment: .leading, spacing: 3) {
                Spacer()
                Text(user?.name ?? "")
                    .font(.title2)
                Text(user?.email ?? "")
                    .font(.caption)
                    .padding(.bottom, 7)
            }
            .foregroundColorCompat(Color.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
        }
        .frame(height: 230)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
