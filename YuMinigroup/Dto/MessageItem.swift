//
//  MessageItem.swift
//  YuMinigroup
//
//  Android dto/MessageItem.java 대응 — Firebase Realtime Database "Messages" 노드 한 메시지.
//  Android는 Firebase POJO 매핑(@PropertyName)으로 스냅샷을 디코드하지만, 이 포팅은 다른 Dto들처럼
//  수동 디코드(ChatRemoteDataSource.decode)를 쓴다 — 키 이름은 verbatim으로 동일: from/name/message/
//  type("text" 고정)/seen(항상 false 기록, 읽음 처리 없음)/timestamp(클라이언트 epoch millis).
//  key는 Firebase 노드 자체의 키(pushId)라 스키마 필드가 아니고, id는 그 key를 그대로 반환하는 계산
//  프로퍼티라 저장 프로퍼티가 아니므로 Hashable 합성에서 자동 제외된다(MemberItem과 동일 관례).
//

import Foundation

struct MessageItem: Identifiable, Hashable {
    var id: String { key }
    var key: String            // Firebase pushId — 낙관적 추가도 push 선발급 key 사용(개선 2)
    var from, name, message, type: String
    var seen: Bool             // 항상 false 기록(Android 미러 — 읽음 처리 없음)
    var timestamp: Int64       // epoch millis(클라이언트 시각, Android 미러)
}
