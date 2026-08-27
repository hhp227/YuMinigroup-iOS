//
//  MockTimetableViewModel.swift
//  YuMinigroup
//
//  Android MockTimeTableFragment + helper/TimetableHelper(SQLite, timetable.db) 대응 — 로컬 전용
//  모의시간표(스펙 §4.2). Android는 SQLite에 저장하지만 이 포팅은 UserDefaults 키
//  "mock_timetable_items"에 JSON [TimetableItem] 배열로 저장한다(init에서 로드).
//
//  items를 id(0~49)를 키로 하는 딕셔너리로 노출하는 것이 핵심이다 — Android 원본(MockTimeTableFragment
//  .onViewCreated의 셀 클릭 리스너)은 매 클릭마다 커서를 처음부터 순회하며 "루트 뷰(view.getId())와
//  데이터 배열 항목의 id를 비교"하는 방식으로 짜여 있어 결함(스펙 §2 결함 2)이 있다. 이식 기준으로
//  지정된 예비 코드 helper/ui/TimetableView.java(submitList)는 애초에 그 비교 없이 "id → TimetableItem"
//  매핑만으로 동작하므로, 이 VM이 딕셔너리를 직접 노출하면 그 정답 모델을 그대로 잇는 셈이 되고 원본
//  결함은 애초에 재현할 여지가 없다(미러 금지 대상이기도 하다).
//
//  디코딩 실패(저장된 JSON이 스키마와 안 맞는 등)는 크래시 대신 빈 상태로 강등한다(try!/fatalError
//  금지). Dictionary 구성도 uniquingKeysWith로 중복 id를 방어해 표준 라이브러리의 fatal trap을 피한다.
//

import Foundation

final class MockTimetableViewModel: ObservableObject {
    private static let storageKey = "mock_timetable_items"

    @Published private(set) var items: [Int: TimetableItem] = [:]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.items = MockTimetableViewModel.load(from: defaults)
    }

    // Android add_timetable_dig/update_timetable_dig의 저장(positive) 버튼 대응 — 신규/기존 모두
    // upsert 한 경로로 처리한다(helper.add/helper.update가 이 VM에서는 딕셔너리 대입 하나로 합쳐진다).
    func save(id: Int, subject: String, classroom: String) {
        items[id] = TimetableItem(id: id, subject: subject, classroom: classroom)
        persist()
    }

    // Android update_timetable_dig의 삭제(negative) 버튼 대응 — helper.delete(id) + 셀 텍스트 초기화.
    func delete(id: Int) {
        items.removeValue(forKey: id)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Array(items.values)) else {
            return
        }
        defaults.set(data, forKey: MockTimetableViewModel.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [Int: TimetableItem] {
        guard let data = defaults.data(forKey: storageKey),
              let array = try? JSONDecoder().decode([TimetableItem].self, from: data) else {
            return [:]
        }
        return Dictionary(array.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
    }
}
