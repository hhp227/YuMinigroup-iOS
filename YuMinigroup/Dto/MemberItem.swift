//
//  MemberItem.swift
//  YuMinigroup
//
//  Android dto/MemberItem.java 대응 — 그룹 멤버 카드. value는 프로필 이미지 식별자다. Android의
//  7-인자 생성자가 쓰는 stuNum/dept/div/regDate(학번/학과/구분/등록일)도 대조 후 추가로 미러링했다.
//  id는 uid를 그대로 반환하는 계산 프로퍼티라 저장 프로퍼티가 아니므로, Codable/Hashable 합성 시
//  자동으로 제외되고 uid/name/value/stuNum/dept/div/regDate 7개 저장 프로퍼티만 대상이 된다.
//

import Foundation

struct MemberItem: Codable, Identifiable, Hashable {
    var id: String { uid }
    var uid, name, value: String     // value = 프로필 이미지 식별자(Android 미러)
    var stuNum, dept, div, regDate: String?  // Android MemberItem 확장 필드 미러
}
