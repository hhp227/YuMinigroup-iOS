//
//  GroupItem.swift
//  YuMinigroup
//
//  Android dto/GroupItem.java 대응 — 그룹 목록/상세 카드. Codable은 로컬 캐시/Firebase 스냅샷용이며
//  엄격한 JSON 키 매칭 목적이 아니다. id는 LMS grp_id, key는 Firebase 키로 별도 보관한다.
//  description은 Swift 예약어 충돌을 피하려고 description_로 선언하고 CodingKeys에서 "description"
//  키로 매핑한다. author/authorUid/memberCount/timestamp/members는 Android 원본에는 있지만 최초
//  브리프 스니펫에는 빠져 있던 필드라 대조 후 추가했다(Android naming 그대로 미러).
//

import Foundation

struct GroupItem: Codable, Identifiable, Hashable {
    var id: String            // LMS grp_id
    var key: String?          // Firebase key
    var name, image: String
    var info, description_, joinType: String?
    var isAdmin: Bool
    var author: String?           // Android GroupItem.author 미러(그룹 생성자 이름)
    var authorUid: String?        // Android GroupItem.authorUid 미러(그룹 생성자 uid)
    var memberCount: Int          // Android GroupItem.memberCount 미러
    var timestamp: Date?          // Android GroupItem.timestamp(long) 미러
    var members: [String: Bool]?  // Android GroupItem.members 미러(Firebase 멤버 맵)

    // Codable 키: description_ ↔ "description"
    private enum CodingKeys: String, CodingKey {
        case id, key, name, image, info, joinType, isAdmin
        case description_ = "description"
        case author, authorUid, memberCount, timestamp, members
    }
}
