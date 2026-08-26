//
//  CreateArticleViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.CreateArticleViewModel(+ActivityResultLauncher/ArticleRemoteDataSource.addArticle/
//  setArticle) 대응 — 게시글 작성/수정 화면의 상태와 전송 로직. Android는 WriteListAdapter의 혼합
//  contentList(제목+본문 헤더 맵 / String(기존 이미지 URL) / Bitmap(새로 고른 이미지) / YouTubeItem)를
//  순회하며 한 번에 하나씩 업로드→HTML 문단 이어붙이기를 재귀적으로 반복하지만, 이 브리프는 유튜브를
//  범위 밖으로 두고 이미지만 다루므로 State를 title/content/images([UIImage], 새로 고른 것)/
//  existingImageUrls([String], 수정 모드에서 이미 서버에 있는 것)로 단순화했다. 업로드는 순차가 아니라
//  DispatchGroup으로 병렬 발사하되(각 MultipartRequest.upload 콜백은 HttpClient.session이 항상 메인
//  큐로 되돌리므로 hasFailed/uploadedUrls 갱신은 스레드 경합이 없다), 실패가 하나라도 있으면
//  addArticle/setArticle(=LMS 전송)로 넘어가지 않고 그 자리에서 에러 메시지 하나만 표시한다(부분
//  업로드된 상태로 글이 등록/수정되는 것을 막는다 — 브리프의 "abort-on-upload-fail" 요구).
//
//  CreateArticleMode는 create(group:)/edit(group:article:) 두 케이스로, 두 화면 진입점(GroupView의
//  탭0 FAB → 작성, ArticleView의 "수정" 메뉴 → 수정)이 공유한다. edit 모드는 article의 title/content/
//  images로 State를 미리 채우고, 전송 성공 시 원본 article을 베이스로 title/content/images 세 필드만
//  덮어써 resultArticle을 만든다(uid/name/timestamp/replyCount/youtubeId/isAuth는 이번에 건드리지 않은
//  필드이므로 ArticleRemoteDataSource.setArticle이 Firebase에서 되읽어 근사 재구성한 값보다 원본을
//  그대로 보존하는 쪽이 더 정확하다 — 특히 replyCount는 Firebase 스냅샷에 애초에 없는 필드라
//  DataSource 쪽에서 복원할 수 없다).
//

import UIKit

enum CreateArticleMode {
    case create(group: GroupItem)
    case edit(group: GroupItem, article: ArticleItem)

    var isEdit: Bool {
        if case .edit = self {
            return true
        }
        return false
    }
}

final class CreateArticleViewModel: ObservableObject {
    struct State {
        var title: String = ""
        var content: String = ""
        var images: [UIImage] = []           // 새로 고른(아직 업로드 안 된) 이미지
        var existingImageUrls: [String] = []  // 수정 모드: 이미 서버에 있는 이미지 URL(삭제 가능)
        var isLoading = false
        var message: String?
        var resultArticle: ArticleItem?
    }

    @Published var state = State()

    let mode: CreateArticleMode

    private let articleRepository: ArticleRepository

    // Android activity_create_article.xml의 툴바 타이틀/action_send 라벨 대응.
    var navigationTitle: String {
        mode.isEdit ? "게시글 수정" : "게시글 작성"
    }

    var actionTitle: String {
        mode.isEdit ? "수정" : "등록"
    }

    init(mode: CreateArticleMode, articleRepository: ArticleRepository? = nil) {
        self.mode = mode
        switch mode {
        case .create(let group):
            self.articleRepository = articleRepository ?? ArticleRepository(groupId: group.id, groupKey: group.key)
        case .edit(let group, let article):
            self.articleRepository = articleRepository ?? ArticleRepository(groupId: group.id, groupKey: group.key)
            state.title = article.title
            state.content = article.content
            state.existingImageUrls = article.images
        }
    }

    func addImages(_ newImages: [UIImage]) {
        state.images.append(contentsOf: newImages)
    }

    func addImage(_ image: UIImage) {
        state.images.append(image)
    }

    func removeExistingImage(at index: Int) {
        guard state.existingImageUrls.indices.contains(index) else {
            return
        }
        state.existingImageUrls.remove(at: index)
    }

    func removeNewImage(at index: Int) {
        guard state.images.indices.contains(index) else {
            return
        }
        state.images.remove(at: index)
    }

    // Android actionSend(title, content, contentList) 대응 — 제목 필수(title.isEmpty 검사)와 "본문도
    // 없고 이미지도 없으면 막는다"(Android: content.isEmpty && contentList.size() < 2)는 조건을 그대로
    // 옮긴다.
    func send() {
        guard !state.isLoading else {
            return
        }
        let title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = state.content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !title.isEmpty else {
            state.message = "제목을 입력하세요."
            return
        }
        guard !content.isEmpty || !state.images.isEmpty || !state.existingImageUrls.isEmpty else {
            state.message = "내용을 입력하세요."
            return
        }
        state.isLoading = true
        uploadPendingImages(title: title, content: content)
    }

    // 새로 고른 이미지가 없으면 업로드 단계를 건너뛰고 바로 전송한다. 있으면 각각
    // BitmapUtil.resized(maxSize: 1280)로 리사이즈한 뒤 병렬로 업로드하고, 하나라도 실패하면
    // (hasFailed) submit(=writeArticle/modifyArticle POST)을 아예 호출하지 않는다 — 부분 업로드 방지.
    private func uploadPendingImages(title: String, content: String) {
        let pending = state.images

        guard !pending.isEmpty else {
            submit(title: title, content: content, imageUrls: state.existingImageUrls)
            return
        }

        var uploadedUrls = [String?](repeating: nil, count: pending.count)
        var hasFailed = false
        let group = DispatchGroup()

        for (index, image) in pending.enumerated() {
            let resized = BitmapUtil.resized(image, maxSize: 1280)

            group.enter()
            articleRepository.uploadImage(resized) { [weak self] result in
                defer {
                    group.leave()
                }
                guard let self = self, !hasFailed else {
                    return
                }
                switch result {
                case .success(let url):
                    uploadedUrls[index] = url
                case .failure(let error):
                    hasFailed = true
                    self.state.isLoading = false
                    self.state.message = "이미지 업로드 실패: \(error.localizedDescription)"
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, !hasFailed else {
                return
            }
            let finalUrls = self.state.existingImageUrls + uploadedUrls.compactMap { $0 }

            self.submit(title: title, content: content, imageUrls: finalUrls)
        }
    }

    private func submit(title: String, content: String, imageUrls: [String]) {
        switch mode {
        case .create:
            articleRepository.addArticle(title: title, content: content, imageUrls: imageUrls) { [weak self] resource in
                self?.handle(resource: resource, baseArticle: nil)
            }
        case .edit(_, let article):
            articleRepository.setArticle(articleId: article.id, key: article.key, title: title, content: content, imageUrls: imageUrls) { [weak self] resource in
                self?.handle(resource: resource, baseArticle: article)
            }
        }
    }

    private func handle(resource: Resource<ArticleItem>, baseArticle: ArticleItem?) {
        switch resource {
        case .loading:
            break
        case .success(let article):
            state.isLoading = false
            if var base = baseArticle {
                base.title = article.title
                base.content = article.content
                base.images = article.images
                state.resultArticle = base
            } else {
                state.resultArticle = article
            }
            state.message = mode.isEdit ? "수정완료" : "전송완료"
        case .error(let message, _):
            state.isLoading = false
            state.message = message
        }
    }
}
