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
//  를 그대로 미러해 이 화면 자신을 pop하고 onJoined()로 GroupMain 새로고침을 호출부(Task 4)에
//  위임한다 — 단, 리뷰 수정(Finding 2)으로 즉시 pop하지 않는다: Android의 Toast는 윈도우 레벨이라
//  Activity가 finish()된 뒤에도 잠깐 화면에 남아 있는데, 이 화면의 .toast는 뷰 트리에 묶여 있어서
//  pop과 동시에 사라진다. 그래서 dismiss()+onJoined()를 DispatchQueue.main.asyncAfter(1.2s)로
//  늦춰 "신청완료" 토스트(Toast.swift 표시 시간 2초)가 최소한 일부라도 보일 시간을 확보한다
//  (Android 생존 시간의 근사 미러). 다이얼로그 자체(selectedInfoViewModel = nil)는 그 지연과
//  무관하게 즉시 닫는다.
//
//  .toast(message: $viewModel.state.message)를 ZStack 바깥(최상위)에 두는 이유: 딤 배경+다이얼로그가
//  ZStack 안에서 그려지는 동안에도(뒤 목록에서 온) 이 화면 자체의 메시지가 다이얼로그에 가려지지
//  않고 그 위에 보이도록 하기 위해서다. 리뷰 수정(Finding 1): GroupInfoViewModel 자신의 성공/실패
//  메시지도 GroupInfoDialogView의 onMessage 콜백을 거쳐 바로 이 같은 state.message에 실어 보낸다 —
//  다이얼로그 카드에 자체 토스트를 붙이면 화면 하단이 아니라 카드 하단(버튼 바로 위)에 뜨기
//  때문이다(GroupInfoDialogView.swift 헤더 코멘트 참고). 화면 전체에 토스트 표면이 이 하나뿐이라
//  두 출처(목록 자체 에러 / 다이얼로그 완료·실패)가 겹쳐도 한 번에 하나씩만 보이므로 문제 없다.
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
                    onMessage: { message in viewModel.state.message = message },
                    onCompleted: { completed in
                        selectedInfoViewModel = nil
                        if completed == .request {
                            // Finding 2: 위 헤더 코멘트 참고 — Android Toast(윈도우 레벨)는 Activity
                            // finish() 후에도 남아 있지만, 이 화면의 토스트는 뷰 트리에 묶여 있어서
                            // 즉시 pop하면 방금 onMessage로 실어 보낸 "신청완료" 토스트가 뜨기도 전에
                            // 함께 사라진다 — 1.2초 지연해 최소한의 노출 시간을 확보한다.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                presentationMode.wrappedValue.dismiss()
                                onJoined()
                            }
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
