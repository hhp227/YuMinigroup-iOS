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
//  Android의 isAuth()/getCookie()(본인 프로필이면 "메시지 보내기" 버튼을 숨기는 데 쓰임)는 이식하지
//  않는다 — 이 화면의 "메시지 보내기" 버튼은 2차(채팅 연결) 전까지 항상 비활성 상태이므로 본인 여부로
//  가시성을 가를 이유가 없다(브리프 지시: 채팅 미배선, 버튼은 "준비중" 라벨의 비활성 버튼 하나로 고정).
//

import Foundation

final class UserViewModel: ObservableObject {
    let member: MemberItem

    init(member: MemberItem) {
        self.member = member
    }
}
