//
//  SemesterTimetableViewModel.swift
//  YuMinigroup
//
//  Android SemesterTimeTableFragment의 인라인 StringRequest 콜백 대응 — SeatViewModel과 동일한 State
//  구조체 모양이되, 이 화면엔 페이징/refresh 스피너 억제 요구가 없다(스펙 §4.2 "영속성 없음(매번 조회)").
//  init에서 즉시 조회하고 refresh()는 같은 fetch()를 다시 부르기만 한다 — 매번 조회이므로 isRefresh
//  플래그로 로딩 스피너를 가릴 이유가 없다(SeatViewModel과 달리 항상 isLoading을 세운다).
//
//  Android 원본은 실패를 VolleyLog로만 남기고 UI 피드백이 없지만(무피드백), 스펙 §4.2가 "실패 시
//  토스트(Android는 무피드백 — 관례상 토스트 추가)"를 명시하므로 message에 담아 TimetableView가
//  .toast로 띄운다.
//

import Foundation

final class SemesterTimetableViewModel: ObservableObject {
    struct State {
        var table: [[String]] = []
        var isLoading = false
        var message: String?
    }

    @Published var state = State()

    private let repository: TimetableRepository

    init(repository: TimetableRepository = TimetableRepository()) {
        self.repository = repository
        fetch()
    }

    // 영속성이 없어 refresh도 최초 조회와 같은 fetch() 경로를 재사용한다(스펙 §4.2).
    func refresh() {
        fetch()
    }

    private func fetch() {
        repository.fetchSemesterTable { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let table):
                self.state.isLoading = false
                self.state.table = table
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }
}
