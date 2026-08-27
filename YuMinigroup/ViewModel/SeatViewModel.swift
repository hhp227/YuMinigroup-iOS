//
//  SeatViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.SeatViewModel 대응 — State 구조체 하나로 합친 UnivNoticeViewModel 모양을 그대로
//  따른다. 페이징이 없어 offset/hasRequestMore/isEndReached는 불필요하다(스펙 §4.3 "페이징 없음").
//
//  결함 없음 — Android fetchDataTask(boolean isRefresh)의 setLoading(!isRefresh) 그대로: 최초 조회는
//  isLoading을 true로 세워 중앙 스피너를 보이지만, refresh()는 같은 fetch 경로를 isRefresh=true로
//  타면서 .loading 케이스에서 isLoading을 세우지 않는다(스펙 §4.3 "refresh 시 중앙 스피너 억제").
//  SeatRemoteDataSource.fetchSeats가 completion(.loading)을 동기적으로 먼저 쏘고 성공/실패로
//  마감하므로, isRefresh 플래그만 클로저 캡처로 들고 있으면 충분하다.
//

import Foundation

final class SeatViewModel: ObservableObject {
    struct State {
        var items: [SeatItem] = []
        var isLoading = false
        var message: String?
    }

    @Published var state = State()

    private let repository: SeatRepository

    init(repository: SeatRepository = SeatRepository()) {
        self.repository = repository
        fetch(isRefresh: false)
    }

    // Android refresh() 대응 — pull-to-refresh에서만 부른다(isRefresh=true로 fetch).
    func refresh() {
        fetch(isRefresh: true)
    }

    private func fetch(isRefresh: Bool) {
        repository.fetchSeats { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = !isRefresh
            case .success(let items):
                self.state.isLoading = false
                self.state.items = items
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }
}
