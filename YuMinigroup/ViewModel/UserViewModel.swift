//
//  UserViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.UserViewModel 대응 — UserDialogView(맴버 미니 프로필)가 보여줄 MemberItem 하나를
//  들고 있는 최소 VM. Android는 SavedStateHandle에서 uid/name/value 세 필드만 꺼내 쓰지만(맴버 그리드가
//  넘긴 것도 그 세 필드뿐), 여기서는 Tab3View가 이미 들고 있는 MemberItem 값을 그대로 물려받으므로
//  Android처럼 필드를 다시 분해하지 않고 member 전체를 보관한다(stuNum/dept는 Android 원본 경로에서도
//  채워지지 않아 nil인 채로 넘어오지만, UserDialogView가 nil-safe하게 조건부로만 그린다).
//
//  Android의 isAuth()(본인 프로필이면 "메시지 보내기" 버튼을 숨기는 데 쓰임)를 isSelf로 미러한다 —
//  Task 9부터 "메시지 보내기"가 실제 ChatView로 연결되므로, 본인 프로필에서는 자기 자신과의 1:1
//  채팅을 여는 것을 막기 위해 버튼 자체를 숨긴다(UserDialogView.actionBar 참고).
//

import Foundation

final class UserViewModel: ObservableObject {
    let member: MemberItem

    // Android UserViewModel.isAuth() 미러 — 현재 로그인 사용자와 이 카드의 대상이 같은 사람인지.
    var isSelf: Bool {
        PreferenceManager.shared.user?.uid == member.uid
    }

    init(member: MemberItem) {
        self.member = member
    }
}
