//
//  RequestView.swift
//  YuMinigroup
//
//  Android activity/RequestActivity(activity_list.xml) 대응 — 가입신청중 그룹 화면. FindGroupView와
//  같은 뼈대(GroupListContent + GroupInfoDialogView 오버레이)를 쓰되 다음 세 지점만 다르다:
//  navigationTitle, emptyMessage, 다이얼로그 buttonType(.cancel).
//
//  onCompleted(.cancel) 처리는 스펙 §4.2 그대로 — Android는 신청취소 성공 후에도 Activity를
//  finish()하지 않고 목록만 새로고침한다(RequestActivity에는 애초에 finish() 호출 자체가 없다). 그래서
//  FindGroupView의 onCompleted(.request)처럼 pop을 지연시키는 1.2초 트릭이 필요 없다 — 다이얼로그만
//  즉시 닫고(selectedInfoViewModel = nil) viewModel.refresh()를 호출한다. "신청취소" 토스트는 이 화면의
//  최상위 .toast 표면에 실려 화면이 pop되지 않으므로 자연스럽게 전체 2초를 다 보여준다.
//
//  이 화면은 GroupMainView가 로컬 NavigationView 안에서 push하는 자식이라(FindGroupView와 동일 이유),
//  시스템 네비바를 숨기지 않는다 — back은 시스템 백 버튼이 처리한다.
//

import SwiftUI

struct RequestView: View {
    @StateObject private var viewModel = RequestViewModel()

    @State private var selectedInfoViewModel: GroupInfoViewModel?

    var body: some View {
        ZStack {
            GroupListContent(
                items: viewModel.state.items,
                isInitialLoading: viewModel.state.isLoading && !viewModel.state.hasRequestMore,
                hasRequestMore: viewModel.state.hasRequestMore,
                isEndReached: viewModel.state.isEndReached,
                emptyMessage: "가입신청중인 그룹이 없습니다.",
                onItemTap: { group in
                    selectedInfoViewModel = GroupInfoViewModel(group: group, buttonType: .cancel)
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
                        if completed == .cancel {
                            viewModel.refresh()
                        }
                    }
                )
                .padding(.horizontal, 32)
            }
        }
        .navigationTitle("가입신청중 그룹")
        .navigationBarTitleDisplayMode(.inline)
        .toast(message: $viewModel.state.message)
    }
}
