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
//  state.message를 GroupInfoDialogView 자신의 .toast로 보여주는 것은 CreateArticleView +
//  CreateArticleViewModel과 동일한 관례다(브리프 Step4 목록엔 토스트 언급이 없지만, §5 일반 에러
//  정책 — 실패 시 토스트/스낵바로 안내 — 을 지키려면 필요하다: 실패하면 completed가 nil로 남아
//  다이얼로그가 계속 열려 있으므로 토스트가 정상적으로 보인다. 성공 시에는 onCompleted가 화면을
//  곧장 닫으므로 Android의 OS 레벨 Toast와 달리 체감 노출 시간이 짧을 수 있다 — SwiftUI 뷰 트리에
//  묶인 토스트의 알려진 한계).
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
