//
//  GroupInfoViewModel.swift
//  YuMinigroup
//
//  Android viewmodel/GroupInfoViewModel.java 대응 — GroupInfoDialogView(그룹찾기 셀 탭 시 뜨는 커스텀
//  중앙 다이얼로그)의 가입신청/신청취소 상태. Android는 SavedStateHandle에 그룹 필드(grp_id/grp_nm/
//  img/info/desc/type/key)와 btn_type(TYPE_REQUEST=0/TYPE_CANCEL=1)을 Bundle로 나눠 받는데, 여기서는
//  group: GroupItem 하나로 필드를 합치고 버튼 종류는 Swift enum(ButtonType)으로 표현한다.
//
//  Task 1 이연 방어: share_group_list.acl 파싱이 menu_list 스코프를 못 찾으면 GroupItem.joinType이
//  nil일 수 있다 — registerGroup에 넘기는 joinType은 Android 삼항식(mJoinType.equals("0"))과 동일한
//  안전 방향으로 nil을 "1"(운영자 승인, 더 보수적인 기본값)로 취급한다.
//
//  sendRequest()의 성공/실패 처리는 GroupMainViewModel과 같은 관례로 Resource<Bool>의 .loading
//  케이스에서 isProcessing = true를 세팅한다(GroupRemoteDataSource.performRemoval이
//  completion(.loading)을 동기적으로 먼저 쏘므로 sendRequest() 호출과 동시에 true가 된다).
//
//  state.message는 이 VM 자신이 화면에 그리지 않는다(브리프 Step4 목록엔 토스트 언급이 없지만, §5
//  일반 에러 정책 — 실패 시 토스트/스낵바로 안내 — 을 지키려면 어떤 형태로든 보여줘야 한다). 리뷰
//  수정(Finding 1): GroupInfoDialogView가 이 값을 자신의 .toast로 직접 그리면 다이얼로그 카드
//  하단(=버튼 바로 위)에 뜨는데, 화면 전체 기준 하단이어야 한다 — 그래서 GroupInfoDialogView는 이
//  값이 바뀌는 것을 onMessage(String) 콜백으로 부모(FindGroupView)에게 넘기고, 부모가 자기 자신의
//  화면 최상위 토스트에 실어 화면 하단에 띄운다(GroupInfoDialogView.swift 헤더 코멘트 참고).
//

import Foundation

final class GroupInfoViewModel: ObservableObject {
    enum ButtonType: Equatable {
        case request
        case cancel
    }

    struct State {
        var isProcessing = false
        var message: String?
        var completed: ButtonType?
    }

    @Published var state = State()

    let group: GroupItem
    let buttonType: ButtonType

    private let repository: GroupRepository

    init(group: GroupItem, buttonType: ButtonType, repository: GroupRepository = GroupRepository()) {
        self.group = group
        self.buttonType = buttonType
        self.repository = repository
    }

    func sendRequest() {
        guard !state.isProcessing else {
            return
        }
        switch buttonType {
        case .request:
            repository.registerGroup(groupId: group.id, key: group.key, joinType: group.joinType ?? "1", fallback: group) { [weak self] resource in
                self?.handle(resource, successMessage: "신청완료", completed: .request)
            }
        case .cancel:
            repository.cancelJoinRequest(groupId: group.id, key: group.key) { [weak self] resource in
                self?.handle(resource, successMessage: "신청취소", completed: .cancel)
            }
        }
    }

    private func handle(_ resource: Resource<Bool>, successMessage: String, completed: ButtonType) {
        switch resource {
        case .loading:
            state.isProcessing = true
        case .success:
            state.isProcessing = false
            state.message = successMessage
            state.completed = completed
        case .error(let message, _):
            state.isProcessing = false
            state.message = message
        }
    }
}
