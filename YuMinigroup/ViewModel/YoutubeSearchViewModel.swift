//
//  YoutubeSearchViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.YoutubeSearchViewModel(ListViewModel<YouTubeItem>) 대응 — items/isLoading/
//  message를 하나의 State로 합친 SeatViewModel 모양을 그대로 따른다.
//
//  Android는 mQuery LiveData 초기값 ""를 observeViewModelData()의 getQuery().observe(this,
//  mViewModel::requestData)가 그대로 흘려보내 화면 진입 즉시 빈 쿼리로 API를 호출한다(빈 쿼리 요청은
//  YouTube API가 오류를 돌려줘 사실상 항상 실패로 끝난다). 스펙 §6.2는 이 동작을 미러하지 않기로
//  했으므로, 이 VM은 init에서 아무 것도 요청하지 않는다 — submitSearch()가 trim 후 빈 문자열이면
//  조용히 반환한다(요청 자체를 보내지 않아 실패 토스트도 뜨지 않는다).
//

import Foundation

final class YoutubeSearchViewModel: ObservableObject {
    struct State {
        var items: [YouTubeItem] = []
        var isLoading = false
        var message: String?
    }

    @Published var state = State()
    @Published var query = ""

    private let repository: YouTubeRepository

    init(repository: YouTubeRepository = YouTubeRepository()) {
        self.repository = repository
    }

    // Android SearchView.onQueryTextSubmit → setQuery(query) 대응 — 검색바 제출(onSubmit)과 돋보기
    // 버튼 양쪽에서 호출한다. query가 비어있거나 공백뿐이면 요청하지 않는다(스펙 §6.2, 클래스 헤더
    // 코멘트 참고).
    func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return
        }
        repository.searchVideos(query: trimmed) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
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
