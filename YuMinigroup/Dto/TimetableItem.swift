//
//  TimetableItem.swift
//  YuMinigroup
//
//  Android dto/TimetableItem.java 대응 — 모의시간표 셀 하나(스펙 §4.2). id는 helper/ui/TimetableView.java
//  (예비 코드, 정답 모델)가 부여하는 좌표 = 교시index×5+(요일index−1), 0~49다. Android는 SQLite
//  (timetable.db, TimetableHelper)에 저장하지만 이 포팅은 MockTimetableViewModel이 UserDefaults 키
//  "mock_timetable_items"에 JSON [TimetableItem] 배열로 저장한다(PreferenceManager 관례의 별도 키).
//  subject/classroom 필드명은 Android 원본 그대로.
//

import Foundation

struct TimetableItem: Codable, Identifiable, Hashable {
    var id: Int
    var subject, classroom: String
}
