//
//  Tab3View.swift
//  YuMinigroup
//
//  Android fragment/Tab3Fragment(fragment_tab3.xml, GridLayoutManager spanCount=4 + SwipeRefreshLayout)
//  대응 — 맴버 탭 실제 화면. Tab1View/Tab2View와 같은 탭 바디 계약(viewModel:headerHeight:appBarState:
//  isActive:scrollOffset:)을 채운다.
//
//  RefreshableLazyColumn(Task 2 킷)은 items:[String] 단일 컬럼 리스트 전용이라 4열 그리드에 쓸 수 없고
//  브리프도 "do NOT modify" 대상으로 못 박았다 — 대신 Tab2View와 같은 ScrollView + CollapsingHeaderSpacer
//  뼈대 위에 LazyVGrid(4열)를 얹고, 시스템 .refreshable(iOS 15+)로 당겨서 새로고침을 직접 구현한다.
//  Android Tab3Fragment.onRefresh는 "postDelayed(1000ms) { refresh(); setRefreshing(false) }"로 실제
//  네트워크 완료를 기다리지 않고 1초 뒤 스피너만 내리는 낙관적 UX인데, 여기서도 동일하게 refresh() 호출 +
//  1초 대기 후 closure를 반환해 스피너를 내린다(RefreshableLazyColumn.refreshable{}과 달리 여기서는
//  실제로 viewModel.refresh()를 호출한다 — 그 킷의 "콜백을 안 부른다"는 기존 결함을 새로 만들지 않는다).
//
//  무한 스크롤은 Android의 "canScrollVertically(1)==false → fetchNextPage()" 스크롤 리스너를 Tab1View와
//  같은 onAppear(마지막 셀 노출 시 loadMore) 패턴으로 옮겼다(SwiftUI 그리드에 스크롤-끝 감지 API가
//  따로 없어 이 앱 전역이 이미 쓰는 관례를 그대로 따른다).
//
//  탭하면 Android UserDialogFragment(bottom dialog)에 대응하는 UserDialogView를 .sheet로 띄운다.
//
//  Task 9 — UserDialogView의 "메시지 보내기"가 onSendMessage()를 부르면 시트를 닫고(selectedMember =
//  nil) chatTarget을 잡은 뒤 0.5초 뒤에 isChatActive를 켜 ChatView(1:1)를 push한다 — 시트 dismiss
//  애니메이션과 push 애니메이션이 겹치지 않도록 하는, Task 6 handleCreated와 같은 관례다.
//

import SwiftUI

struct Tab3View: View {
    @ObservedObject var viewModel: Tab3ViewModel
    let headerHeight: CGFloat
    let appBarState: CollapsingAppBarState
    let isActive: Bool
    @Binding var scrollOffset: CGFloat

    @State private var selectedMember: MemberItem?

    // Task 9 — UserDialogView "메시지 보내기" → ChatView(1:1) push 상태.
    @State private var chatTarget: MemberItem?
    @State private var isChatActive = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ZStack {
            ScrollView {
                CollapsingHeaderSpacer(isScrollTrackingEnabled: isActive)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.state.members) { member in
                        memberCell(member)
                    }
                }
                .padding(.top, headerHeight)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .coordinateSpace(name: collapsingScrollCoordinateSpace)
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) {
                if isActive && !$0.isNaN {
                    scrollOffset = $0
                }
            }
            .refreshable {
                guard appBarState.isExpanded else { return }
                viewModel.refresh()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            if viewModel.state.members.isEmpty && viewModel.state.isLoading {
                ProgressView()
                    .padding(.top, headerHeight + 60)
            }

            NavigationLink(isActive: $isChatActive) {
                if let chatTarget = chatTarget {
                    ChatView(receiver: chatTarget.uid, isGroupChat: false, chatName: chatTarget.name)
                }
            } label: { EmptyView() }
            .hidden()
        }
        .toast(message: $viewModel.state.message)
        .sheet(item: $selectedMember) { member in
            UserDialogView(viewModel: UserViewModel(member: member), onSendMessage: {
                selectedMember = nil
                chatTarget = member
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isChatActive = true
                }
            })
        }
    }

    @ViewBuilder
    private func memberCell(_ member: MemberItem) -> some View {
        Button(action: { selectedMember = member }) {
            VStack(spacing: 6) {
                RemoteImage(urlString: EndPoint.userImage(uid: member.uid))
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())

                Text(member.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundColorCompat(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onAppear {
            if !viewModel.state.endReached, member.id == viewModel.state.members.last?.id {
                viewModel.loadMore()
            }
        }
    }
}
