//
//  FindGroupViewModel.swift
//  YuMinigroup
//
//  Android viewmodel/FindGroupViewModel.java + ListViewModel<Map.Entry<String, GroupItem>> 대응 —
//  그룹찾기 화면의 페이징 상태. Android는 부모 클래스 ListViewModel이 offset/loading/requestMore/
//  endReached/message 5개 LiveData를 따로 들고 있는데, 여기서는 1차 관례(GroupMainViewModel 등)를
//  따라 State 구조체 하나로 합쳤다. LIMIT=15는 Android와 동일, offset은 1부터 시작해 페이지마다
//  Android(offset += LIMIT)와 동일하게 15씩 더한다.
//
//  hasRequestMore는 Android의 "fetchGroupList.onLoading { setRequestMore(offset > 1) }"을 그대로
//  옮긴 것이다 — GroupRemoteDataSource는 completion(.loading)을 동기적으로 먼저 쏘고 성공/실패로
//  마감하므로(Resource.swift 헤더 코멘트), 그 .loading 케이스에서 "지금 요청 중인 offset이 1보다
//  큰가"로 판단한다. 성공/실패 이후에는 Android처럼 별도로 false로 되돌리지 않는다 — 그 결과
//  GroupListContent의 푸터 조건(hasRequestMore && !isEndReached)이 "두 번째 페이지를 처음 요청한
//  순간부터 끝에 도달하기 전까지 계속 true"가 되어 Android의 실제 체감(페이지 2부터는 진행바 자리가
//  끝에 도달할 때까지 계속 보인다)과 일치한다.
//
//  isInitialLoading(스켈레톤 조건)은 이 VM이 계산하지 않는다 — FindGroupView가
//  "state.isLoading && !state.hasRequestMore"로 계산해 GroupListContent에 내려준다(브리프 인터페이스).
//

import Foundation

final class FindGroupViewModel: ObservableObject {
    struct State {
        var items: [GroupItem] = []
        var isLoading = false
        var hasRequestMore = false
        var isEndReached = false
        var message: String?
    }

    @Published var state = State()

    private static let limit = 15

    private var offset = 1

    private let repository: GroupRepository

    init(repository: GroupRepository = GroupRepository()) {
        self.repository = repository
        fetchNextPage()
    }

    // Android "setRequestMore(!isStopRequestMore); if (!isStopRequestMore) fetch"를 옮기되, 화면 쪽
    // 중복 페이징 방지를 위해 isLoading/isEndReached도 함께 가드한다(브리프 지시).
    func fetchNextPage() {
        guard !state.isLoading, !state.isEndReached, !repository.isGroupPagingStopped else {
            return
        }
        repository.fetchNotJoinedGroups(offset: offset, limit: FindGroupViewModel.limit) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
                self.state.hasRequestMore = self.offset > 1
            case .success(let newItems):
                self.state.isLoading = false
                self.state.items += newItems
                self.offset += FindGroupViewModel.limit
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
