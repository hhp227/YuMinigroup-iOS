//
//  UpdateReplyViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.UpdateReplyViewModel 대응 — 댓글 한 건 수정 화면의 상태. Android는
//  SavedStateHandle로 전달받은 원문에서 "※" 앞부분만 잘라 text를 프리필하지만(공지사항 등 다른
//  화면에서 흘러온 접미사로 보이며, 이 앱의 게시글 댓글 흐름에서는 붙지 않는다), 이 포팅은
//  ArticleView가 그대로 넘겨준 reply.reply를 가공 없이 프리필한다.
//
//  ReplyRepository.setReply(replyId:text:completion:)는 Resource<Bool>(성공 여부)만 돌려준다 —
//  ReplyRemoteDataSource.swift의 setReply 코멘트가 명시하듯 LMS 응답을 댓글 목록으로 재파싱하지
//  않기 때문이다(Android의 actionSend도 동일하게 응답 문자열을 재해석하지 않고 그대로 콜백에 넘긴다).
//  따라서 성공 시 새로 전달받은 목록에서 항목을 찾는 대신, 생성자로 받아둔 원본 reply의
//  uid/key/name/date/timestamp/isAuth는 그대로 유지한 채 reply 텍스트만 바꾼 ReplyItem을 합성해
//  onUpdated로 돌려준다. ArticleView는 article 수정 반영(viewModel.state.article = updated)과 같은
//  패턴으로 viewModel.state.replys 배열에서 같은 id를 찾아 이 값으로 교체한다.
//
//  ArticleViewModel과 같은 DI 관례(articleRepository/replyRepository를 nil이면 컨텍스트로 새로
//  만든다)를 따라, replyRepository를 주입하지 않으면 groupId/articleId/articleKey로 직접 만든다 —
//  ArticleViewModel이 ReplyRepository(groupId:articleId:articleKey:)를 만드는 것과 동일한 컨텍스트를
//  ArticleView가 그대로 넘겨준다.
//

import Foundation

final class UpdateReplyViewModel: ObservableObject {
    struct State {
        var text: String
        var isLoading = false
        var message: String?
        var done = false
    }

    @Published var state: State

    private let reply: ReplyItem
    private let onUpdated: (ReplyItem) -> Void
    private let replyRepository: ReplyRepository

    init(reply: ReplyItem,
         groupId: String,
         articleId: String,
         articleKey: String?,
         onUpdated: @escaping (ReplyItem) -> Void,
         replyRepository: ReplyRepository? = nil) {
        self.reply = reply
        self.onUpdated = onUpdated
        self.state = State(text: reply.reply)
        self.replyRepository = replyRepository ?? ReplyRepository(groupId: groupId, articleId: articleId, articleKey: articleKey)
    }

    // Android actionSend(text) 대응 — 빈 입력은 Android의 setReplyError("내용을 입력하세요.")와 같이
    // 안내 메시지만 띄우고 전송하지 않는다.
    func update() {
        let text = state.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            state.message = "내용을 입력하세요."
            return
        }
        state.isLoading = true
        replyRepository.setReply(replyId: reply.id, text: text) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success:
                self.state.isLoading = false
                var updated = self.reply
                updated.reply = text
                self.onUpdated(updated)
                self.state.done = true
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }
}
