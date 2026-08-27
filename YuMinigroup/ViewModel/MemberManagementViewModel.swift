//
//  MemberManagementViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.MemberManagementViewModel 대응 — 그룹 설정 "회원관리" 탭의 상태. init에서 즉시
//  로드하는 것도 Android(SavedStateHandle 생성자에서 곧장 fetchMemberList() 호출)와 동일하다.
//
//  refresh()는 Android MemberManagementFragment.onRefresh(:69)의 결함(스펙 §2 결함 3 — Toast만 띄우고
//  실제 재조회는 하지 않음)을 수정해 fetchMembers()를 다시 호출한다 — MemberManagementView의
//  .refreshable이 SeatView.swift와 동일한 관례(진짜 콜백을 부르는 것으로 "실제 재조회" 계약을
//  만족한다, 스피너를 인위적으로 붙잡아두는 낙관적 1초 대기는 Tab3View 전용 사유라 여기엔 없다)로
//  이 메소드를 그대로 부른다.
//

import Foundation

final class MemberManagementViewModel: ObservableObject {
    struct State {
        var members: [MemberItem] = []
        var isLoading = false
        var message: String?
    }

    @Published var state = State()

    private let groupId: String
    private let userRepository: UserRepository

    init(groupId: String, userRepository: UserRepository = UserRepository()) {
        self.groupId = groupId
        self.userRepository = userRepository
        fetchMembers()
    }

    // Android SwipeRefreshLayout onRefresh 대응 진입점 — 실제 재조회(브리프 지시).
    func refresh() {
        fetchMembers()
    }

    private func fetchMembers() {
        userRepository.fetchManagedMembers(groupId: groupId) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let members):
                self.state.isLoading = false
                self.state.members = members
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }
}
