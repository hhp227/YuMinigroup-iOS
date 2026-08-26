//
//  GroupMainViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.GroupMainViewModel 대응 — 가입한 그룹 목록 + 로딩/메시지 상태. Android는 목록이
//  비면 인기 그룹 슬라이더(fetchPopularGroupList)로 대체하지만, 이번 태스크 범위는 브리프가 명시한
//  "빈 상태 배너"까지만이라 인기 그룹 캐러셀은 이식하지 않는다(GroupMainFragment/GroupGridAdapter의
//  광고·슬라이더·헤더 로직 전체가 범위 밖 — task-10-report.md 참고).
//
//  fetchGroups()는 GroupRemoteDataSource.fetchJoinedGroups(offset:)를 Android GroupMainViewModel과
//  동일하게 offset=1 한 번만 호출한다(Android 홈 화면은 실제로 스크롤 더보기를 구현하지 않는다).
//

import Foundation

final class GroupMainViewModel: ObservableObject {
    struct State {
        var groups: [GroupItem] = []
        var isLoading = false
        var message: String?
    }

    @Published var state = State()

    private static let initialOffset = 1

    private let groupRepository: GroupRepository

    init(groupRepository: GroupRepository = GroupRepository()) {
        self.groupRepository = groupRepository
        fetchGroups()
    }

    // Android GroupMainViewModel.fetchDataTask()/refresh() 대응(둘 다 동일 호출이라 하나로 합쳤다).
    func fetchGroups() {
        groupRepository.fetchJoinedGroups(offset: GroupMainViewModel.initialOffset) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let groups):
                self.state.isLoading = false
                self.state.groups = groups
            case .error(let message, let groups):
                self.state.isLoading = false
                self.state.message = message
                if let groups = groups {
                    self.state.groups = groups
                }
            }
        }
    }
}
