//
//  FindGroupView.swift
//  YuMinigroup
//
//  Android activity/FindGroupActivity(activity_list.xml) 대응 — 그룹찾기 화면. GroupMainView가 로컬
//  NavigationView를 이미 열어 두었으므로 이 화면은 그 안으로 push되는 자식일 뿐이라 시스템 네비바를
//  숨기지 않는다(navigationBarHiddenCompat 걸지 않음 — 브리프 지시, back은 시스템 백 버튼이 처리).
//
//  GroupInfoDialogView는 부모가 만들어 내려주는 GroupInfoViewModel을 그대로 들고 있어야 한다 — 만약
//  "if let group = selectedGroup { GroupInfoDialogView(viewModel: GroupInfoViewModel(group: group,
//  buttonType: .request), ...) }"처럼 body 안에서 매번 새로 생성하면, FindGroupViewModel.state.message
//  같은 이 화면의 다른 상태가 바뀌어 body가 재평가될 때마다(다이얼로그와 무관한 이유로도) 새
//  GroupInfoViewModel이 새로 만들어져 처리 중이던 isProcessing/completed가 통째로 날아간다. 그래서
//  selectedInfoViewModel: GroupInfoViewModel?를 이벤트 핸들러(onItemTap) 안에서 딱 한 번만 생성해
//  @State로 들고 있는다 — body 재평가는 이미 만들어진 같은 인스턴스를 계속 참조할 뿐이다.
//
//  가입신청 성공(onCompleted(.request)) 시 Android FindGroupActivity의 "setResult(RESULT_OK); finish()"
//  를 그대로 미러해 이 화면 자신을 pop한 뒤 onJoined()로 GroupMain 새로고침을 호출부(Task 4)에
//  위임한다.
//
//  .toast(message: $viewModel.state.message)를 ZStack 바깥(최상위)에 두는 이유: 딤 배경+다이얼로그가
//  ZStack 안에서 그려지는 동안에도(뒤 목록에서 온) 이 화면 자체의 메시지가 다이얼로그에 가려지지
//  않고 그 위에 보이도록 하기 위해서다(GroupInfoViewModel 자신의 성공/실패 메시지는
//  GroupInfoDialogView가 별도로 자신의 .toast로 보여준다 — GroupInfoDialogView.swift 헤더 코멘트
//  참고, 서로 다른 ViewModel의 message라 겹치지 않는다).
//

import SwiftUI

struct FindGroupView: View {
    @StateObject private var viewModel = FindGroupViewModel()
    @Environment(\.presentationMode) private var presentationMode

    @State private var selectedInfoViewModel: GroupInfoViewModel?

    let onJoined: () -> Void

    var body: some View {
        ZStack {
            GroupListContent(
                items: viewModel.state.items,
                isInitialLoading: viewModel.state.isLoading && !viewModel.state.hasRequestMore,
                hasRequestMore: viewModel.state.hasRequestMore,
                isEndReached: viewModel.state.isEndReached,
                emptyMessage: "가입할 수 있는 그룹이 없습니다.",
                onItemTap: { group in
                    selectedInfoViewModel = GroupInfoViewModel(group: group, buttonType: .request)
                },
                onLoadMore: { viewModel.fetchNextPage() },
                onRefresh: { viewModel.refresh() }
            )

            if let infoViewModel = selectedInfoViewModel {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { selectedInfoViewModel = nil }

                GroupInfoDialogView(
                    viewModel: infoViewModel,
                    onClose: { selectedInfoViewModel = nil },
                    onCompleted: { completed in
                        selectedInfoViewModel = nil
                        if completed == .request {
                            presentationMode.wrappedValue.dismiss()
                            onJoined()
                        }
                    }
                )
                .padding(.horizontal, 32)
            }
        }
        .navigationTitle("그룹 찾기")
        .navigationBarTitleDisplayMode(.inline)
        .toast(message: $viewModel.state.message)
    }
}
