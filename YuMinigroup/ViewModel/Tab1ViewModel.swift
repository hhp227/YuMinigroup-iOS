//
//  Tab1ViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.Tab1ViewModel 대응 — 소식 탭(게시글 목록)의 상태+페이지네이션. GroupView가
//  자신의 StateObject로 이 VM을 소유하고 Tab1View에 주입한다(GroupViewModel은 브리프 지시대로
//  건드리지 않는다 — 탭 전환/collapse 같은 범용 UI 상태만 계속 GroupViewModel 몫이다).
//
//  offset은 Android Tab1ViewModel의 SavedStateHandle OFFSET(startL=1부터 시작, LIMIT=10씩 증가) 그대로
//  로컬 프로퍼티로 옮겼다(SavedStateHandle 자체는 프로세스 종료 후 복원용이라 이번 마이그레이션 범위 밖).
//  ArticleRemoteDataSource.fetchArticles(offset:)가 offset<=1일 때 내부적으로 minId/stopRequestMore를
//  리셋하므로, refresh()는 Android의 명시적 setMinId(0) 호출 없이 offset을 1로 되돌리는 것만으로 충분하다.
//
//  endReached는 Android의 "articleItemList.isEmpty()"와 "articleRepository.isStopRequestMore()" 두
//  신호를 합친 것이다 — 둘 중 하나만 봐서는 안 되는 이유: 마지막 페이지가 정확히 10개로 끝나면 그
//  응답 자체는 비어있지 않지만 다음 페이지 요청은 빈 배열을 돌려주므로 isEmpty만으로는 한 번의 헛된
//  추가 요청이 남는다(Android도 이 한계를 그대로 갖고 있다 — 실질적 체감 차이는 없지만, stopRequestMore도
//  함께 보면 중복 감지가 걸린 마지막 응답에서 한 템포 더 빨리 멈출 수 있어 함께 반영했다).
//

import Foundation

final class Tab1ViewModel: ObservableObject {
    struct State {
        var articles: [ArticleItem] = []
        var isLoading = false
        var isRefreshing = false
        var endReached = false
        var message: String?
    }

    @Published var state = State()

    // Task 16 추가 — Tab1View가 셀 탭에서 ArticleView(article:groupId:groupKey:...)를 만들 때 필요하다.
    // GroupView.swift(브리프 "do NOT modify" 대상)는 그대로 두고 이미 전달받은 값을 읽기 전용으로만
    // 노출한다(Tab1View의 init 시그니처 자체는 바뀌지 않으므로 GroupView의 호출부도 안 바뀐다).
    let groupId: String
    let groupKey: String?

    private static let initialOffset = 1
    private static let pageSize = 10

    private let articleRepository: ArticleRepository
    private var offset = Tab1ViewModel.initialOffset

    init(groupId: String, groupKey: String?, articleRepository: ArticleRepository? = nil) {
        self.groupId = groupId
        self.groupKey = groupKey
        self.articleRepository = articleRepository ?? ArticleRepository(groupId: groupId, groupKey: groupKey)
        fetchNextPage()
    }

    // Android Tab1Fragment의 RecyclerView 스크롤 리스너(마지막 아이템 노출 시 fetchNextPage) 대응.
    // 이미 로딩 중이거나 더 가져올 페이지가 없으면 무시한다.
    func loadMore() {
        guard !state.isLoading, !state.endReached else {
            return
        }
        fetchNextPage()
    }

    // Android Tab1ViewModel.refresh() 대응 — 목록/오프셋/종료 상태를 초기화하고 첫 페이지를 다시 요청한다.
    func refresh() {
        state.isRefreshing = true
        state.articles = []
        state.endReached = false
        offset = Tab1ViewModel.initialOffset
        fetchNextPage()
    }

    // Android Tab1Fragment.mArticleActivityResultLauncher의 removeArticle 결과 반영 대응 — 이름 그대로
    // "결과 반영"만 한다. Task 16 전까지는 아무도 호출하지 않았는데(Tab1View가 PlaceholderView만 push),
    // Task 16의 ArticleView가 이 메소드의 첫 실제 호출부가 되면서 예전 구현(articleRepository.
    // deleteArticle을 여기서 다시 호출)의 문제가 드러났다: ArticleViewModel.deleteArticle()이 자신의
    // ArticleRepository로 이미 삭제 네트워크 호출을 완료한 뒤 onDeleted(article) → 이 메소드를 부르므로,
    // 예전처럼 여기서 다시 deleteArticle을 호출하면 이미 지워진 글을 또 지우려는 중복 호출이 된다.
    // 그래서 순수 로컬 상태 반영(articles 배열에서 제거)만 하도록 고쳤다 — Android
    // ActivityResultLauncher 콜백도 어댑터에서 로컬로만 제거하고 다시 삭제 API를 부르지 않는다.
    func remove(article: ArticleItem) {
        state.articles.removeAll { $0.id == article.id }
    }

    // 게시글 작성/수정 결과 반영용. Android는 수정은 updateArticleItem(position:)으로 제자리 교체하고
    // 새 글 작성은 refresh()를 다시 호출하는 두 갈래인데, 여기서는 position 대신 id로 매칭해 있으면
    // 교체·없으면 맨 앞에 삽입하는 단일 메소드로 합쳤다(Task 16/17이 작성/수정 어느 결과든 이 하나로
    // 반영할 수 있도록 하기 위함 — 물론 Task 17이 Android처럼 refresh()를 대신 호출해도 무방하다).
    func upsert(_ article: ArticleItem) {
        if let index = state.articles.firstIndex(where: { $0.id == article.id }) {
            state.articles[index] = article
        } else {
            state.articles.insert(article, at: 0)
        }
    }

    private func fetchNextPage() {
        state.isLoading = true
        articleRepository.fetchArticles(offset: offset) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success(let articles):
                self.state.isLoading = false
                self.state.isRefreshing = false
                self.state.articles.append(contentsOf: articles)
                self.offset += Tab1ViewModel.pageSize
                self.state.endReached = articles.isEmpty || self.articleRepository.stopRequestMore
            case .error(let message, let articles):
                self.state.isLoading = false
                self.state.isRefreshing = false
                self.state.message = message
                if let articles = articles {
                    self.state.articles.append(contentsOf: articles)
                }
            }
        }
    }
}
