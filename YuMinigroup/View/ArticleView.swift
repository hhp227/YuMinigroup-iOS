//
//  ArticleView.swift
//  YuMinigroup
//
//  Android activity/ArticleActivity(activity_article.xml + article_detail.xml) 대응 — 게시글 상세.
//  Android는 ListView(헤더로 article_detail 붙임) 아래 입력 바를 SwipeRefreshLayout과 별도
//  LinearLayout으로 고정하는 구조라(activity_article.xml: srl_article이 weight=1로 스크롤 영역을
//  갖고, 그 아래 구분선+입력 바 LinearLayout이 화면 하단에 고정된다), 이 뷰도 ScrollView(헤더+댓글)를
//  위에, 입력 바를 ScrollView 밖 하단에 고정한 VStack으로 옮긴다(브리프의 "ScrollView: ... + 하단 입력바"
//  문구를 "입력바가 화면 하단에 고정"으로 읽었다 — Android 레이아웃 자체가 그렇게 되어 있다).
//
//  Tab1View가 셀 탭에서 이미 파싱해 둔 article을 그대로 넘겨 받아 화면을 즉시 채우고(빈 화면 없음),
//  ArticleViewModel.fetchAll()이 최신 상세+댓글로 이어서 덮어쓴다. 삭제/댓글 변경은 onDeleted/onUpdated
//  클로저로 Tab1ViewModel.remove(article:)/upsert(_:)에 반영된다(Tab1View가 NavigationLink destination을
//  만들 때 주입).
//
//  이미지 탭은 Task 18부터 PictureView(images:initialIndex:)를, "게시글 수정"은 Task 17부터
//  CreateArticleView(.edit(group:article:))를 각각 풀스크린으로 띄운다. 댓글 수정은 Task 18부터
//  UpdateReplyView(reply:...)를 .sheet(item:)로 띄우고, 성공 시 onUpdated로 돌아온 새 ReplyItem을
//  viewModel.state.replys에서 같은 id를 찾아 직접 교체한다(article 수정 반영과 같은 패턴).
//
//  두 풀스크린 화면(수정/이미지)은 각각 별도의 Bool(showEditArticle/showPicture)로 쓰지 않고 하나의
//  ArticleFullScreen(Identifiable) enum + 단일 .fullScreenCover(item:)로 합쳐 뜬다 — 삭제 확인/댓글
//  삭제 확인을 ConfirmTarget 하나로 합쳐 .alert(item:) 하나만 쓰는 것과 같은 이유다: iOS 15에서
//  같은 뷰에 같은 종류(.fullScreenCover든 .alert든)의 presentation modifier를 여러 개 붙이면 하나만
//  반응하는(다른 하나는 조용히 안 뜨는) 알려진 문제가 있어(iOS 16의 다중 alert/sheet 지원 이전), 여러
//  트리거를 한 modifier로 묶는 쪽이 안전하다. .sheet(item: $editReplyTarget)는 종류가 달라(sheet vs
//  fullScreenCover) 이 문제와 무관하므로 그대로 둔다.
//
//  CreateArticleMode.edit(group:article:)는 GroupItem 전체를 요구하지만, 이 화면은 Tab1View(브리프의
//  "do NOT modify" 대상)가 넘겨주는 groupId/groupKey 문자열만 갖고 있다 — CreateArticleViewModel의 edit
//  모드는 실제로 group.id/group.key만 써서 ArticleRepository를 만들 뿐 나머지 필드는 쓰지 않으므로,
//  editGroupItem에서 그 두 값만 채우고 나머지는 placeholder로 둔 GroupItem을 합성한다(아래 참고).
//  수정 성공 시 viewModel.state.article을 직접 덮어써 헤더를 즉시 갱신하고, ArticleView가 자신의 init
//  파라미터로 받은 onUpdated(ArticleViewModel에 이미 전달한 것과 같은 클로저)를 한 번 더 호출해 Tab1
//  목록도 갱신한다.
//

import SwiftUI
import WebKit

struct ArticleView: View {
    @StateObject private var viewModel: ArticleViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var confirmTarget: ConfirmTarget?
    @State private var editReplyTarget: ReplyItem?   // 댓글 수정 전용(.sheet) — 게시글 수정/이미지는 fullScreen으로 분리
    @State private var fullScreen: ArticleFullScreen?

    private let groupId: String
    private let groupKey: String?
    private let onUpdated: (ArticleItem) -> Void

    init(article: ArticleItem,
         groupId: String,
         groupKey: String?,
         onDeleted: @escaping (ArticleItem) -> Void,
         onUpdated: @escaping (ArticleItem) -> Void) {
        self.groupId = groupId
        self.groupKey = groupKey
        self.onUpdated = onUpdated
        _viewModel = StateObject(wrappedValue: ArticleViewModel(
            article: article,
            groupId: groupId,
            groupKey: groupKey,
            onDeleted: onDeleted,
            onUpdated: onUpdated
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                header

                Divider()

                replyList
            }

            Divider()

            composer
        }
        .navigationTitle(viewModel.state.article.title)
        .navigationBarTitleDisplayMode(.inline)
        .toast(message: $viewModel.state.message)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Android onCreateOptionsMenu의 mIsAuthorized 분기 — 본인 글일 때만 수정/삭제 메뉴를 보인다.
                if viewModel.isOwner {
                    Menu {
                        Button("수정") {
                            fullScreen = .edit
                        }
                        Button("삭제", role: .destructive) {
                            confirmTarget = .deleteArticle
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .fullScreenCover(item: $fullScreen) { target in
            switch target {
            case .edit:
                CreateArticleView(mode: .edit(group: editGroupItem, article: viewModel.state.article)) { updated in
                    viewModel.state.article = updated
                    onUpdated(updated)
                }
            case .picture(let startIndex):
                PictureView(images: viewModel.state.article.images, initialIndex: startIndex)
            }
        }
        .sheet(item: $editReplyTarget) { reply in
            UpdateReplyView(
                reply: reply,
                groupId: groupId,
                articleId: viewModel.state.article.id,
                articleKey: viewModel.state.article.key,
                onUpdated: { updated in
                    if let index = viewModel.state.replys.firstIndex(where: { $0.id == updated.id }) {
                        viewModel.state.replys[index] = updated
                    }
                }
            )
        }
        .alert(item: $confirmTarget) { target in
            alert(for: target)
        }
        .onChange(of: viewModel.state.didDelete) { didDelete in
            if didDelete {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // MARK: - 풀스크린 화면 (게시글 수정/이미지 뷰어 공용, 위 헤더 코멘트 참고)

    // "수정" 메뉴와 이미지 탭 각각을 별도 Bool로 두지 않고 이 enum 하나로 합쳐, 단일
    // .fullScreenCover(item:)로만 뜨게 한다(iOS 15 다중 같은-종류 presentation modifier 문제 회피).
    private enum ArticleFullScreen: Identifiable {
        case edit
        case picture(startIndex: Int)

        var id: String {
            switch self {
            case .edit:
                return "edit"
            case .picture(let startIndex):
                return "picture-\(startIndex)"
            }
        }
    }

    // CreateArticleMode.edit이 요구하는 GroupItem을 groupId/groupKey만으로 합성한다 — 위 헤더 코멘트 참고.
    private var editGroupItem: GroupItem {
        GroupItem(
            id: groupId,
            key: groupKey,
            name: "",
            image: "",
            info: nil,
            description_: nil,
            joinType: nil,
            isAdmin: false,
            author: nil,
            authorUid: nil,
            memberCount: 0,
            timestamp: nil,
            members: nil
        )
    }

    // MARK: - 게시글 헤더 (article_detail.xml 대응)

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RemoteImage(urlString: EndPoint.userImage(uid: viewModel.state.article.uid), placeholder: Image(systemName: "person.crop.circle.fill"))
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 45, height: 45)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.state.article.title) - \(viewModel.state.article.name)")
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)

                    if let timestamp = viewModel.state.article.timestamp {
                        Text(DateUtil.relative(timestamp))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }

            if !viewModel.state.article.content.isEmpty {
                Text(viewModel.state.article.content)
                    .font(.subheadline)
            }

            if !viewModel.state.article.images.isEmpty || viewModel.state.article.youtubeId != nil {
                contentList
            }
        }
        .padding(16)
    }

    // images 스택에 youtubePosition(Task 10/11) 인덱스로 유튜브 embed를 끼워 넣은 통합 표시 순서(브리프
    // Step 4) — PictureView의 startIndex는 이 리스트의 표시 순서가 아니라 원본 article.images 배열
    // 인덱스를 그대로 받으므로, .image case에 그 인덱스를 별도로 담아 이미지 인덱스 매핑이 어긋나지
    // 않게 한다. youtubePosition이 nil이면(옛 데이터 등) 맨 끝에 붙인다.
    private enum ArticleContentEntry: Identifiable {
        case image(index: Int, url: String)
        case youtube(videoId: String)

        var id: String {
            switch self {
            case .image(let index, _):
                return "image-\(index)"
            case .youtube(let videoId):
                return "youtube-\(videoId)"
            }
        }
    }

    private var contentEntries: [ArticleContentEntry] {
        let images = viewModel.state.article.images
        var entries = images.enumerated().map { ArticleContentEntry.image(index: $0.offset, url: $0.element) }

        if let youtubeId = viewModel.state.article.youtubeId {
            let position = viewModel.state.article.youtubePosition ?? entries.count
            let insertIndex = min(max(position, 0), entries.count)
            entries.insert(.youtube(videoId: youtubeId), at: insertIndex)
        }
        return entries
    }

    // Android ll_image의 imageList+youtube 바인딩을 하나로 합친 대응 — 이미지는 탭하면 PictureView를
    // 탭한 인덱스로 열고, 유튜브는 인앱 embed(youtubeEmbed)를 그 자리에 렌더한다.
    private var contentList: some View {
        VStack(spacing: 8) {
            ForEach(contentEntries) { entry in
                switch entry {
                case .image(let index, let url):
                    Button(action: {
                        fullScreen = .picture(startIndex: index)
                    }) {
                        RemoteImage(urlString: url)
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                case .youtube(let videoId):
                    youtubeEmbed(videoId: videoId)
                }
            }
        }
    }

    // Android ll_image의 youtube 바인딩(BindingAdapters.bindImageList의 YouTubePlayerView SDK 재생)
    // 대응 — SDK 의존 없이 WKWebView로 유튜브 iframe embed를 인앱 재생한다(WebViewScreen은 화면 단위
    // 컴포넌트라 재사용하지 않음, 브리프 지시). embed가 재생되지 않는 상황을 대비해 아래에 항상
    // "YouTube에서 열기" 폴백 버튼을 둔다(기존 openYoutube 재사용).
    private func youtubeEmbed(videoId: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            YoutubeEmbedView(videoId: videoId)
                .aspectRatio(CGFloat(16) / CGFloat(9), contentMode: .fit)
                .cornerRadius(6)

            Button(action: { openYoutube(videoId) }) {
                Label("YouTube에서 열기", systemImage: "arrow.up.forward.app")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }

    private func openYoutube(_ videoId: String) {
        guard let url = URL(string: "https://www.youtube.com/watch?v=\(videoId)") else {
            return
        }
        UIApplication.shared.open(url)
    }

    // MARK: - 댓글 목록 (reply_item.xml 대응)

    private var replyList: some View {
        LazyVStack(spacing: 0) {
            ForEach(viewModel.state.replys) { reply in
                ReplyListCell(
                    reply: reply,
                    onCopy: { copy(reply) },
                    onEdit: { editReplyTarget = reply },
                    onDelete: { confirmTarget = .deleteReply(reply) }
                )

                Divider()
            }
        }
    }

    // Android onContextItemSelected의 "내용 복사"(position != 0, 댓글) 대응.
    private func copy(_ reply: ReplyItem) {
        UIPasteboard.general.string = reply.reply
        viewModel.state.message = "클립보드에 복사되었습니다!"
    }

    // MARK: - 하단 입력 바 (activity_article.xml et_reply/cv_btn_send 대응)

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("댓글을 입력하세요.", text: $viewModel.state.inputText)
                .textFieldStyle(.plain)

            Button("전송") {
                viewModel.sendReply()
            }
            .disabled(viewModel.state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - 삭제 확인 (게시글/댓글 공용)

    private enum ConfirmTarget: Identifiable {
        case deleteArticle
        case deleteReply(ReplyItem)

        var id: String {
            switch self {
            case .deleteArticle:
                return "article"
            case .deleteReply(let reply):
                return "reply-\(reply.id)"
            }
        }
    }

    private func alert(for target: ConfirmTarget) -> Alert {
        switch target {
        case .deleteArticle:
            return Alert(
                title: Text("게시글을 삭제하시겠습니까?"),
                primaryButton: .destructive(Text("확인")) { viewModel.deleteArticle() },
                secondaryButton: .cancel(Text("취소"))
            )
        case .deleteReply(let reply):
            return Alert(
                title: Text("댓글을 삭제하시겠습니까?"),
                primaryButton: .destructive(Text("확인")) { viewModel.deleteReply(reply) },
                secondaryButton: .cancel(Text("취소"))
            )
        }
    }
}

// MARK: - 유튜브 인앱 재생 (WebViewScreen.WebView와 별개의, 이 파일 전용 소형 representable — 브리프 지시)

// updateUIView는 SwiftUI가 header를 재평가할 때마다(댓글 입력 등 이 embed와 무관한 State 변경에도)
// 다시 불릴 수 있으므로, WebViewScreen.WebView의 lastLoadedURLString 가드와 같은 이유로 Coordinator에
// 마지막으로 로드한 videoId를 남겨 같은 영상을 반복 load하는 재요청 루프를 막는다.
private struct YoutubeEmbedView: UIViewRepresentable {
    let videoId: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedVideoId != videoId else { return }
        guard let url = URL(string: "https://www.youtube.com/embed/\(videoId)?playsinline=1") else {
            return
        }
        context.coordinator.lastLoadedVideoId = videoId
        webView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var lastLoadedVideoId: String?
    }
}
