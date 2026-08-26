//
//  Tab4ViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.Tab4ViewModel 대응 — 설정 탭(사용자/소모임/앱 정보) 상태. GroupView가 소유한 별도
//  StateObject로 groupItem 하나만 받는다(Android는 admin/grp_id/grp_img/key 4개를 SavedStateHandle로
//  따로 받지만, 이 포팅은 이미 GroupItem 전체를 들고 있으므로 그 값을 그대로 재사용한다 — Tab1/Tab3
//  ViewModel과 같은 원칙).
//
//  leaveOrClose()는 Android Tab4ViewModel.deleteGroup()의 isAdmin 분기(GroupRepository.removeGroup
//  → Callback)를 GroupRepository.leaveGroup/deleteGroup 페어로 그대로 옮긴다. key는 groupItem.key
//  (Firebase 매핑, nil 가능)를 그대로 전달한다 — GroupRepository.swift(task-10)의
//  leaveGroup(groupId:key:completion:)/deleteGroup(groupId:key:completion:) 시그니처를 그대로 쓴다.
//  성공 메시지는 Android Tab4ViewModel.deleteGroup()의 "소모임 " + (isAdmin ? "폐쇄" : "탈퇴") + " 완료"
//  그대로("소모임 폐쇄 완료"/"소모임 탈퇴 완료" — 공백 포함, content_tab4.xml의 버튼 라벨(공백 없음)과는
//  다른 문구다).
//
//  didExit는 Android의 isSuccess() LiveData 관찰(성공 시 requireActivity().setResult+finish()) 대응 —
//  Tab4View가 이 값이 true로 바뀌는 것을 보고 presentationMode로 GroupView를 pop한다(GroupView는
//  GroupMainView의 NavigationLink로 push되어 있으므로 pop이 곧 Android의 finish()에 해당한다).
//

import Foundation

final class Tab4ViewModel: ObservableObject {
    let groupItem: GroupItem

    @Published var message: String?
    @Published var didExit = false
    @Published var isProcessing = false

    private let groupRepository: GroupRepository

    init(groupItem: GroupItem, groupRepository: GroupRepository? = nil) {
        self.groupItem = groupItem
        self.groupRepository = groupRepository ?? GroupRepository()
    }

    // Android Tab4ViewModel.getUser() 대응 — 사용자 설정 카드(이름/아이디/프로필 사진)가 쓴다.
    var user: User? {
        PreferenceManager.shared.user
    }

    // content_tab4.xml iv_profile_image의 app:userImageUrl 바인딩(EndPoint.USER_IMAGE.replace(UID)) 대응.
    // uid가 없으면(비로그인/미동기화) nil을 돌려줘 RemoteImage가 placeholder를 보여주게 한다.
    var userImageURL: String? {
        guard let uid = user?.uid else {
            return nil
        }
        return EndPoint.userImage(uid: uid)
    }

    // Android content_tab4.xml tv_withdrawal 라벨("소모임" + (mIsAdmin ? "폐쇄" : "탈퇴"), 공백 없음) 그대로.
    var actionLabel: String {
        "소모임" + (groupItem.isAdmin ? "폐쇄" : "탈퇴")
    }

    // Android Tab4Fragment onClick(ll_withdrawal)의 AlertDialog 메시지("(폐쇄|탈퇴)하시겠습니까?") 그대로.
    var confirmMessage: String {
        (groupItem.isAdmin ? "폐쇄" : "탈퇴") + "하시겠습니까?"
    }

    // Android Tab4ViewModel.deleteGroup() 대응 — isAdmin이면 소모임 폐쇄(deleteGroup), 아니면 탈퇴(leaveGroup).
    // completion은 terminal(success/error) 상태에서만 한 번 호출된다(.loading에서는 부르지 않는다) — 확인
    // 다이얼로그를 닫은 뒤 호출부가 후속 동작을 걸 수 있도록 남겨 둔 훅이며, 지금은 아무도 쓰지 않는다.
    func leaveOrClose(completion: (() -> Void)? = nil) {
        let isAdmin = groupItem.isAdmin
        let handleResult: (Resource<Bool>) -> Void = { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.isProcessing = true
            case .success:
                self.isProcessing = false
                self.message = "소모임 " + (isAdmin ? "폐쇄" : "탈퇴") + " 완료"
                self.didExit = true
                completion?()
            case .error(let errorMessage, _):
                self.isProcessing = false
                self.message = errorMessage
                completion?()
            }
        }

        if isAdmin {
            groupRepository.deleteGroup(groupId: groupItem.id, key: groupItem.key, completion: handleResult)
        } else {
            groupRepository.leaveGroup(groupId: groupItem.id, key: groupItem.key, completion: handleResult)
        }
    }
}
