//
//  ArticleViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.ArticleViewModel 대응 — 게시글 상세(본문+댓글+작성) 화면의 상태. ArticleView가
//  자신의 @StateObject로 소유하며, article은 Tab1View가 셀 탭에서 넘겨준 값으로 즉시 채운 뒤(빈 화면
//  없이 바로 보여줄 수 있도록) fetchAll()이 곧바로 최신 상세+댓글로 덮어쓴다.
//
//  onDeleted/onUpdated는 Tab1ViewModel의 remove(article:)/upsert(_:)를 직접 부르지 않고 클로저로
//  주입받는다(Tab1ViewModel을 이 ViewModel이 소유/참조하지 않기 위함 — ArticleView는 GroupView의
//  NavigationLink 아래로 push되므로 두 화면이 서로 다른 StateObject 인스턴스를 갖는다). 삭제 성공 시
//  onDeleted를, 상세 재조회/댓글 작성으로 replyCount가 바뀔 때마다 onUpdated를 호출해 Tab1 목록이
//  뒤로가기 후에도 최신 상태를 보여주게 한다.
//
//  fetchAll()은 Android ArticleViewModel 생성자의 fetchArticleData(mArticleId, false) 호출과 대응하되,
//  Android가 한 번의 HTTP 응답에서 상세+댓글을 함께 얻는 것과 달리(파일 상단 ReplyRemoteDataSource.swift
//  코멘트 참고) 이 포팅은 ArticleRepository.fetchArticle과 ReplyRepository.fetchReplys를 각각 독립
//  호출한다.
//

import Foundation

final class ArticleViewModel: ObservableObject {
    struct State {
        var article: ArticleItem
        var replys: [ReplyItem] = []
        var inputText: String = ""
        var isLoading = false
        var message: String?
        var didDelete = false
    }

    @Published var state: State

    private let onDeleted: (ArticleItem) -> Void
    private let onUpdated: (ArticleItem) -> Void

    private let articleRepository: ArticleRepository
    private let replyRepository: ReplyRepository

    init(article: ArticleItem,
         groupId: String,
         groupKey: String?,
         onDeleted: @escaping (ArticleItem) -> Void,
         onUpdated: @escaping (ArticleItem) -> Void,
         articleRepository: ArticleRepository? = nil,
         replyRepository: ReplyRepository? = nil) {
        self.state = State(article: article)
        self.onDeleted = onDeleted
        self.onUpdated = onUpdated
        self.articleRepository = articleRepository ?? ArticleRepository(groupId: groupId, groupKey: groupKey)
        self.replyRepository = replyRepository ?? ReplyRepository(groupId: groupId, articleId: article.id, articleKey: article.key)
        fetchAll()
    }

    // Android ArticleActivity.onCreateOptionsMenu의 mIsAuthorized 대응 — 본인 글일 때만 수정/삭제
    // 메뉴를 노출한다.
    var isOwner: Bool {
        state.article.isAuth
    }

    // Android ArticleViewModel.refresh()(초기 로드 포함) 대응 — 상세+댓글을 각각 다시 불러온다.
    func fetchAll() {
        fetchArticle()
        fetchReplys()
    }

    func fetchArticle() {
        state.isLoading = true
        articleRepository.fetchArticle(articleId: state.article.id) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success(let article):
                self.state.isLoading = false
                self.state.article = article
            case .error(let message, let article):
                self.state.isLoading = false
                self.state.message = message
                if let article = article {
                    self.state.article = article
                }
            }
        }
    }

    func fetchReplys() {
        replyRepository.fetchReplys { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success(let replys):
                self.state.replys = replys
            case .error(let message, let replys):
                self.state.message = message
                if let replys = replys {
                    self.state.replys = replys
                }
            }
        }
    }

    // Android ArticleViewModel.actionSend(text) 대응 — 빈 입력은 Android의 setReplyError("댓글을
    // 입력하세요.")와 같은 안내만 띄우고 전송하지 않는다. 성공하면 입력창을 비우고(Android
    // reply.postValue("")) 최신 댓글 목록 + 늘어난 replyCount를 반영해 Tab1에도 알린다.
    func sendReply() {
        let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            state.message = "댓글을 입력하세요."
            return
        }
        state.inputText = ""
        replyRepository.addReply(text: text) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success(let replys):
                self.state.replys = replys
                self.state.article.replyCount = replys.count
                self.onUpdated(self.state.article)
            case .error(let message, let replys):
                self.state.message = message
                if let replys = replys {
                    self.state.replys = replys
                }
            }
        }
    }

    // Android ArticleViewModel.deleteArticle() 대응 — 성공 시 onDeleted로 Tab1 목록에서 제거를 알리고
    // didDelete를 true로 바꿔 ArticleView가 자신을 pop하도록 신호한다(Tab4View의 didExit와 같은 패턴).
    func deleteArticle() {
        state.isLoading = true
        articleRepository.deleteArticle(articleId: state.article.id, articleKey: state.article.key) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success:
                self.state.isLoading = false
                self.onDeleted(self.state.article)
                self.state.didDelete = true
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }

    // Android ArticleViewModel.deleteReply(replyId:replyKey:) 대응.
    func deleteReply(_ reply: ReplyItem) {
        replyRepository.removeReply(replyId: reply.id, replyKey: reply.key) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success(let replys):
                self.state.replys = replys
                self.state.article.replyCount = replys.count
                self.onUpdated(self.state.article)
            case .error(let message, let replys):
                self.state.message = message
                if let replys = replys {
                    self.state.replys = replys
                }
            }
        }
    }
}
