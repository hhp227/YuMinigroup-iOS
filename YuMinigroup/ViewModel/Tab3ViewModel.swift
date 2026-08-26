//
//  Tab3ViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.Tab3ViewModel 대응 — 맴버 탭(그룹 멤버 그리드)의 상태+페이지네이션. GroupView가
//  자신의 StateObject로 이 VM을 소유하고 Tab3View에 주입한다(Tab1ViewModel/Tab2ViewModel과 동일 원칙 —
//  GroupViewModel은 탭 전환/collapse 같은 범용 UI 상태만 계속 담당한다).
//
//  offset/페이지 크기는 Android SavedStateHandle 기반 OFFSET(초기 1)/LIMIT(40) 그대로 로컬 프로퍼티로
//  옮겼다. endReached는 Android "setEndReached(memberItemList.isEmpty())"와 동일하게 이번 페이지 응답이
//  비었는지 하나의 신호만 본다(Tab1ViewModel처럼 stopRequestMore를 더 보는 이중 신호가 아니다 — 멤버 목록
//  Repository/Resource에는 그런 신호 자체가 없다).
//

import Foundation

final class Tab3ViewModel: ObservableObject {
    struct State {
        var members: [MemberItem] = []
        var isLoading = false
        var isRefreshing = false
        var endReached = false
        var message: String?
    }

    @Published var state = State()

    private static let initialOffset = 1
    private static let pageSize = 40

    private let groupId: String
    private let groupRepository: GroupRepository
    private var offset = Tab3ViewModel.initialOffset

    init(groupId: String, groupRepository: GroupRepository? = nil) {
        self.groupId = groupId
        self.groupRepository = groupRepository ?? GroupRepository()
        fetchNextPage()
    }

    // Android Tab3Fragment의 RecyclerView 스크롤 리스너(더 이상 스크롤할 수 없을 때 fetchNextPage) 대응.
    // 이미 로딩 중이거나 더 가져올 페이지가 없으면 무시한다.
    func loadMore() {
        guard !state.isLoading, !state.endReached else {
            return
        }
        fetchNextPage()
    }

    // Android Tab3ViewModel.refresh() 대응 — 목록/오프셋/종료 상태를 초기화하고 첫 페이지를 다시 요청한다.
    func refresh() {
        state.isRefreshing = true
        state.members = []
        state.endReached = false
        offset = Tab3ViewModel.initialOffset
        fetchNextPage()
    }

    private func fetchNextPage() {
        state.isLoading = true
        groupRepository.fetchMembers(groupId: groupId, offset: offset) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success(let members):
                self.state.isLoading = false
                self.state.isRefreshing = false
                self.state.members.append(contentsOf: members)
                self.offset += Tab3ViewModel.pageSize
                self.state.endReached = members.isEmpty
            case .error(let message, let members):
                self.state.isLoading = false
                self.state.isRefreshing = false
                self.state.message = message
                // 실패한 페이지(예: 세션 만료)에서 endReached를 그대로 두면 마지막 셀 onAppear가 매번
                // loadMore()를 재호출해 같은 요청을 무한 반복한다 — 실패 시엔 더 이상 다음 페이지를
                // 시도하지 않도록 멈춘다(Tab1ViewModel에는 없는, 리뷰로 추가된 방어).
                self.state.endReached = true
                if let members = members {
                    self.state.members.append(contentsOf: members)
                }
            }
        }
    }
}
