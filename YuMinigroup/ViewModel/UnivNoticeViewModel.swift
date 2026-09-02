//
//  UnivNoticeViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.UnivNoticeViewModel(ListViewModel<BbsItem>) 대응 — State 구조체 하나로 합친
//  2차 FindGroupViewModel 모양을 그대로 따른다.
//
//  결함 1 수정(스펙 §2): Android는 ListViewModel의 필드 기본값(offset=1)으로 첫 페이지를 조회하고,
//  refresh()에서만 offset=0으로 되돌려 이후 페이지가 0,10,20,…으로 흐른다 — 최초 진입과 새로고침
//  이후의 오프셋 계열이 어긋난다. 이 포팅은 offset을 0으로 통일해 최초 진입부터 0,10,20,…,90으로
//  일관되게 흐르게 한다(MAX 100건, Android MAX_PAGE와 동일).
//
//  hasRequestMore는 FindGroupViewModel과 동일하게 ".loading" 케이스에서 "지금 요청 중인 offset이
//  0보다 큰가"로 판단한다(UnivNoticeRemoteDataSource가 completion(.loading)을 동기적으로 먼저 쏘고
//  성공/실패로 마감하므로) — Android의 "setRequestMore(offset > 1)"을 0-기준으로 옮긴 대응이다.
//

import Foundation

final class UnivNoticeViewModel: ObservableObject {
    struct State {
        var items: [BbsItem] = []
        var isLoading = false
        var hasRequestMore = false
        var isEndReached = false
        var message: String?
    }

    @Published var state = State()

    private static let pageSize = 10
    private static let maxOffset = 100

    private var offset = 0

    private let repository: UnivNoticeRepository

    init(repository: UnivNoticeRepository = UnivNoticeRepository()) {
        self.repository = repository
        fetchNextPage()
    }

    // Android fetchNextPage()(offset < MAX_PAGE 가드) 대응 + 화면 쪽 중복 페이징 방지를 위해
    // isLoading/isEndReached도 함께 가드한다(FindGroupViewModel과 동일 관례).
    func fetchNextPage() {
        guard !state.isLoading, !state.isEndReached, offset < UnivNoticeViewModel.maxOffset else {
            return
        }
        repository.fetchNotices(offset: offset) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
                self.state.hasRequestMore = self.offset > 0
            case .success(let newItems):
                self.state.isLoading = false
                self.state.items += newItems
                self.offset += UnivNoticeViewModel.pageSize
                self.state.isEndReached = newItems.isEmpty || self.offset >= UnivNoticeViewModel.maxOffset
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }

    // Android refresh(): offset=0/빈 리스트/endReached=false로 되돌리고 재조회 — 결함 1 수정 후에는
    // 최초 진입 오프셋 계열과 동일하다(둘 다 0부터 시작).
    func refresh() {
        offset = 0
        state.items = []
        state.isEndReached = false
        fetchNextPage()
    }
}
