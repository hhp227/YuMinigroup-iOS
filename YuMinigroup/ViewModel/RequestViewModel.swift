//
//  RequestViewModel.swift
//  YuMinigroup
//
//  Android viewmodel/RequestViewModel.java + ListViewModel<Map.Entry<String, GroupItem>> 대응 —
//  가입신청중 화면의 페이징 상태. FindGroupViewModel과 필드가 동일한 State 구조체를 자체 선언한다
//  (화면당 VM 독립이라는 1차 관례 — 공유하지 않는다). LIMIT=100은 Android와 동일, offset은 1부터
//  시작해 100씩 더한다.
//
//  Android RequestViewModel.fetchGroupList는 "새로 받아온 페이지 크기가 기존 리스트 크기와 다르면
//  누적, 같으면 리스트를 통째로 새 페이지로 교체하고 offset을 1로 되돌린다"는 결함성 병합을 쓴다 —
//  가입신청중 목록이 실제 필터링 없이 LMS 전체 그룹을 노출하던 시절(스펙 §2 결함 1)의 임시방편으로
//  보인다. GroupRemoteDataSource가 이미 UserGroupList 교차 필터링을 마쳤으므로(결함 1 수정), 여기서는
//  브리프가 지시한 단순형을 쓴다: 첫 페이지(offset==1)는 신규로 교체, 그 외에는 누적한다. 이 판단은
//  merge 직전 offset(다음 페이지 오프셋으로 갱신되기 전 값)으로 하므로 refresh() 직후 첫 호출에서도
//  offset==1이 성립한다.
//
//  hasRequestMore/isInitialLoading 계산은 FindGroupViewModel과 동일한 근거(GroupRemoteDataSource가
//  completion(.loading)을 동기적으로 먼저 쏜다, Resource.swift 헤더 코멘트)를 따른다.
//

import Foundation

final class RequestViewModel: ObservableObject {
    struct State {
        var items: [GroupItem] = []
        var isLoading = false
        var hasRequestMore = false
        var isEndReached = false
        var message: String?
    }

    @Published var state = State()

    private static let limit = 100

    private var offset = 1

    private let repository: GroupRepository

    init(repository: GroupRepository = GroupRepository()) {
        self.repository = repository
        fetchNextPage()
    }

    // Android "setRequestMore(!isStopRequestMore); if (!isStopRequestMore) fetch"를 옮기되, 화면 쪽
    // 중복 페이징 방지를 위해 isLoading/isEndReached도 함께 가드한다(FindGroupViewModel과 동일 관례).
    func fetchNextPage() {
        guard !state.isLoading, !state.isEndReached, !repository.isGroupPagingStopped else {
            return
        }
        repository.fetchJoinRequestGroups(offset: offset, limit: RequestViewModel.limit) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
                self.state.hasRequestMore = self.offset > 1
            case .success(let newItems):
                self.state.isLoading = false
                self.state.items = self.offset == 1 ? newItems : self.state.items + newItems
                self.offset += RequestViewModel.limit
                self.state.isEndReached = newItems.isEmpty
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }

    // Android refresh(): setMinId(0) 후 offset=1/빈 리스트/endReached=false로 되돌리고 재조회.
    // resetGroupPaging()이 minId와 stopRequestMore를 함께 리셋하므로(결함 3 수정,
    // GroupRemoteDataSource 헤더 코멘트) 곧바로 이어지는 fetchNextPage()의 isGroupPagingStopped
    // 가드를 그대로 통과한다.
    func refresh() {
        repository.resetGroupPaging()
        offset = 1
        state.items = []
        state.isEndReached = false
        fetchNextPage()
    }
}
