//
//  UpdateReplyView.swift
//  YuMinigroup
//
//  Android activity/UpdateReplyActivity(activity_update_reply.xml + modify_text.xml) 대응 — 댓글 한 건
//  수정 화면. Android는 RecyclerView(단일 아이템)에 EditText 하나를 얹고 옵션 메뉴("전송")로 저장하지만,
//  이 화면은 ArticleView의 "수정" 컨텍스트 메뉴에서 .sheet로 뜨는 모달이라(ArticleView.swift 참고)
//  CreateArticleView와 같은 자기완결형 구조(로컬 NavigationView + 취소/전송 툴바)를 그대로 따른다.
//
//  ArticleView는 이미 push된 NavigationView 안에 있으므로 이 화면이 별도 NavigationView를 열어야
//  취소/전송 버튼이 달린 툴바를 가질 수 있다(CreateArticleView.swift 코멘트와 동일한 이유).
//
//  성공(viewModel.state.done이 true로 바뀜) 시 자신을 dismiss한다 — 목록 반영은 이 화면이 모르는
//  ArticleView의 상태이므로, UpdateReplyViewModel의 onUpdated 콜백(생성 시 ArticleView가 주입)이
//  전담한다.
//

import SwiftUI

struct UpdateReplyView: View {
    @StateObject private var viewModel: UpdateReplyViewModel
    @Environment(\.presentationMode) private var presentationMode

    init(reply: ReplyItem,
         groupId: String,
         articleId: String,
         articleKey: String?,
         onUpdated: @escaping (ReplyItem) -> Void) {
        _viewModel = StateObject(wrappedValue: UpdateReplyViewModel(
            reply: reply,
            groupId: groupId,
            articleId: articleId,
            articleKey: articleKey,
            onUpdated: onUpdated
        ))
    }

    var body: some View {
        NavigationView {
            contentEditor
                .navigationTitle("댓글 수정")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("취소") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("전송") {
                            viewModel.update()
                        }
                        .disabled(viewModel.state.isLoading)
                    }
                }
                .toast(message: $viewModel.state.message)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: viewModel.state.done) { done in
            if done {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // modify_text.xml의 et_reply(gravity=top, hint="내용을 입력하세요.") 대응 — CreateArticleView의
    // contentEditor와 같은 ZStack 플레이스홀더 관례(SwiftUI TextEditor에 표준 placeholder가 없다).
    private var contentEditor: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.state.text.isEmpty {
                Text("내용을 입력하세요.")
                    .foregroundColor(Color(uiColor: .placeholderText))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
            }
            TextEditor(text: $viewModel.state.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
    }
}
