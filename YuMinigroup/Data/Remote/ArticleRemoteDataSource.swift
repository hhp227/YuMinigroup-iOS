//
//  ArticleRemoteDataSource.swift
//  YuMinigroup
//
//  Android data.remote.ArticleRemoteDataSource 대응 — 1차분(Task 12)은 getArticleList(share_list.acl
//  목록 파싱+Firebase 병합)와 removeArticle(삭제+Firebase 정리)만 이식했다. getArticleData(단건 상세
//  조회)는 이 파일 하단 "MARK: - 상세 조회"에서 Task 16이 fetchArticle(articleId:completion:)로
//  이식했다 — 그 섹션 코멘트에 Android 원본의 position(startL) 기반 조회를 ARTL_NUM 기반으로 바꾼
//  이유를 적었다. addArticle/setArticle/addArticleImage(uploadImage로 개명)는 Task 17이 "MARK: - 작성",
//  "MARK: - 수정", "MARK: - 이미지 업로드" 세 섹션으로 추가했다 — 각 섹션 코멘트에 Android 흐름과의
//  대응/차이를 적었다.
//
//  요청은 브리프 지시대로 POST+formParams로 보낸다(Android 원본 getArticleList는 GET+쿼리스트링이지만,
//  Task 10의 GroupRemoteDataSource도 이미 이 앱의 다른 LMS 목록 조회를 POST로 통일했다 — 레거시 JSP
//  백엔드는 GET/POST 어느 쪽이든 request.getParameter()로 동일하게 읽으므로 관측 가능한 차이는 없다).
//  파라미터 이름/값(CLUB_GRP_ID, startL=offset, displayL=10)은 Android 원본 그대로.
//
//  HTML 파싱은 jericho의 getAllElementsByClass/getFirstElementByClass 대응을 정규식으로 미러한다.
//  Jericho는 완전한 DOM 트리라 각 요소가 정확히 자신의 닫는 태그까지 균형 잡히지만, 이 파일은
//  HtmlUtil.elementById가 이미 인정한 것과 같은 한계(정규식은 동일 태그 중첩을 완전히 맞추지 못함)를
//  안고 있다. 대신 "listbox2"(게시글 한 건)과 그 안의 "view_art"(본문 정보)/"comment_wrap"(댓글수+
//  artl_num)이 서로 형제로 반복되는 구조라는 점을 이용해, "다음 형제 블록이 시작하는 지점 직전까지"를
//  현재 블록의 끝으로 삼는다(닫는 태그를 찾을 필요가 없어 중첩 문제를 원천적으로 피한다). list_title/
//  list_cont처럼 내부에 같은 태그가 중첩되지 않는 단일 요소는 태그명 백레퍼런스(\1)로 첫 닫는 태그까지
//  안전하게 잡는다(HtmlUtil.attributeExact의 따옴표 백레퍼런스와 같은 기법).
//
//  본문(list_cont) 추출은 Android의 getChildElements()(임의 태그의 모든 직계 자식) 대신, 이미 공개된
//  HtmlUtil.cells(in:tag:)로 <p> 태그만 순회한다 — imageExtract/youtubeExtract가 detail 뷰에서
//  <p> 단위로 이미지/유튜브를 순회하는 것과 같은 전제(본문 문단은 <p>로 감싸인다)이며, 정규식만으로
//  "임의 태그의 직계 자식"을 정확히 열거할 수 없어서 택한 근사치다.
//
//  페이지네이션 종료 감지(mMinId/mStopRequestMore)는 Android 원본을 그대로 옮긴다: 이미 본 적 있는
//  (=지금까지의 최소값보다 큰) id를 다시 만나면 그 항목은 버리고 그 응답의 나머지 항목 처리도 멈춘다
//  (오프셋 계산이 어긋나 이전 페이지와 겹칠 때의 안전장치). Android는 Tab1ViewModel.refresh()가 명시적으로
//  setMinId(0)을 호출해야 하지만, 이 브리프의 ArticleRemoteDataSource는 setMinId를 별도로 노출하지
//  않으므로 대신 fetchArticles(offset:)가 offset<=1(첫 페이지 = 새로고침)일 때 내부에서 자동으로
//  minId/stopRequestMore를 리셋한다 — Android가 그룹에 글이 하나도 없을 때 mStopRequestMore가 리셋되지
//  않고 남는 엣지 케이스까지 함께 고친 의도적 개선이다.
//
//  Firebase 병합은 브리프 지시대로 images/youtubeId/timestamp/uid 네 필드를 "보강"한다(Firebase 값이
//  있을 때만 덮어쓰고, 없으면 HTML 파싱 결과를 그대로 둔다) — Android의 getArticleList는 uid만 병합하지만,
//  Firebase가 수정 화면에서 쓴 최신 내용을 담고 있으므로(반면 LMS HTML은 수정 후에도 옛 내용을 보여줄 수
//  있다) 목록에서도 네 필드를 함께 보강하는 쪽이 더 정확하다. 매칭은 Firebase 자식의 "id" 필드(=artl_num)로
//  parsed 배열의 id와 대조한다. FirebaseRef.database()가 nil이거나 groupKey가 없으면 병합을 생략한다.
//
//  completion은 호출당 정확히 한 번만 최종 상태(.success 또는 .error)로 불린다: LMS 실패 시 그 자리에서
//  바로 .error, 성공 시엔 파싱 후 Firebase 병합 콜백(단일 이벤트 리스너의 with/withCancel 중 정확히 하나)
//  안에서만 최종 completion을 호출한다 — LMS와 Firebase 두 비동기 콜백이 얽혀 이중/누락 호출이 나기 쉬운
//  지점이라 특히 주의했다(.loading은 매 fetchArticles(offset:) 호출 시작에 한 번 더 불리지만, 이는
//  GroupRemoteDataSource와 동일하게 "로딩 신호"로 취급되고 "최종 결과"로 세지 않는다).
//

import UIKit
import FirebaseDatabase

final class ArticleRemoteDataSource {
    private let groupId: String
    private let groupKey: String?

    // Android mMinId(0=미설정) 대응. Optional로 표현해 "0"이라는 실제 id 값과 "아직 없음"을 명확히 구분한다.
    private var minId: Int64?

    private(set) var stopRequestMore = false

    init(groupId: String, groupKey: String?) {
        self.groupId = groupId
        self.groupKey = groupKey
    }

    // MARK: - 목록 조회

    func fetchArticles(offset: Int, completion: @escaping (Resource<[ArticleItem]>) -> Void) {
        completion(.loading)

        // 첫 페이지 요청(초기 로드 또는 새로고침)은 페이지네이션 중복 감지 상태를 리셋한다
        // (Android Tab1ViewModel.refresh()의 articleRepository.setMinId(0) 대응).
        if offset <= 1 {
            minId = nil
            stopRequestMore = false
        }
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "CLUB_GRP_ID": groupId,
            "startL": String(offset),
            "displayL": "10"
        ]

        HttpClient.request(EndPoint.groupArticleList, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                let parsed = self.parseArticles(from: html)

                self.mergeFirebase(parsed, completion: completion)
            }
        }
    }

    // MARK: - 삭제

    func deleteArticle(articleId: String, articleKey: String?, completion: @escaping (Resource<Bool>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "CLUB_GRP_ID": groupId,
            "ARTL_NUM": articleId
        ]

        HttpClient.request(EndPoint.deleteArticle, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let body):
                guard let data = body.data(using: .utf8),
                      let response = try? JSONDecoder().decode(RemovalResponse.self, from: data),
                      !response.isError else {
                    completion(.error("삭제에 실패했습니다."))
                    return
                }
                self?.cleanupFirebase(articleKey: articleKey)
                completion(.success(true))
            }
        }
    }

    private struct RemovalResponse: Decodable {
        let isError: Bool
    }

    private func cleanupFirebase(articleKey: String?) {
        guard let groupKey = groupKey, let articleKey = articleKey, let root = FirebaseRef.database() else {
            return
        }
        root.child("Articles").child(groupKey).child(articleKey).removeValue()
        root.child("Replys").child(articleKey).removeValue()
    }

    // MARK: - 작성 (Task 17)

    // Android CreateArticleViewModel.actionCreate → ArticleRemoteDataSource.addArticle 미러. Android는
    // 이미지 태그가 이미 박힌 완성 HTML(content)과 URL 목록(imageList)을 둘 다 CreateArticleViewModel이
    // 미리 만들어 넘기지만, 이 브리프의 시그니처는 content를 "본문 평문"으로 받으므로 여기서
    // buildContentHtml로 <p> 문단(+이미지 <p><img></p>) HTML을 직접 조립한다 — share_list.acl 파싱
    // (parseArticles/parseArticleDetail)이 list_cont 안의 <p> 태그를 전제하므로, 평문을 그대로 TXT에
    // 넣으면 재조회 시 content가 빈 문자열로 보이는 회귀가 생긴다(이 파일 상단 파서 코멘트 참고).
    //
    // 흐름: POST writeArticle(SBJT/CLUB_GRP_ID/TXT) → isError 확인 → 목록 재조회(Android getArticleId와
    // 동일하게 CLUB_GRP_ID+displayL=1만으로 GET, 첫 comment_wrap의 num 속성이 방금 쓴 글) → Firebase
    // Articles/{groupKey}에 push. 각 단계 실패 시 그 자리에서 바로 completion(.error)하고 다음 단계로
    // 진행하지 않는다(중간 상태 없음) — completion은 세 단계 중 정확히 한 지점에서만 최종 호출된다.
    func addArticle(title: String, content: String, imageUrls: [String], completion: @escaping (Resource<ArticleItem>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let htmlContent = ArticleRemoteDataSource.buildContentHtml(text: content, imageUrls: imageUrls)
        let formParams = [
            "SBJT": title,
            "CLUB_GRP_ID": groupId,
            "TXT": htmlContent
        ]

        HttpClient.request(EndPoint.writeArticle, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let body):
                guard let data = body.data(using: .utf8),
                      let response = try? JSONDecoder().decode(RemovalResponse.self, from: data),
                      !response.isError else {
                    completion(.error("게시글 등록에 실패했습니다."))
                    return
                }
                self.fetchNewArticleId(title: title, content: content, imageUrls: imageUrls, completion: completion)
            }
        }
    }

    // Android getArticleId(cookie:user:title:content:imageList:youTubeItem:callback:) 미러 — 방금 쓴 글의
    // artl_num을 얻으려고 목록을 필터 없이(CLUB_GRP_ID+displayL=1만) 재조회해 "가장 최근 글"인 첫
    // comment_wrap의 num 속성을 그대로 쓴다(Android도 동일하게 필터 없는 첫 블록을 신뢰한다 — 방금
    // 작성한 글이 항상 최신순 목록의 맨 앞에 온다는 전제).
    private func fetchNewArticleId(title: String, content: String, imageUrls: [String], completion: @escaping (Resource<ArticleItem>) -> Void) {
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "CLUB_GRP_ID": groupId,
            "displayL": "1"
        ]

        HttpClient.request(EndPoint.groupArticleList, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                guard let openTag = ArticleRemoteDataSource.openTag(class: "comment_wrap", in: html),
                      let artlNum = HtmlUtil.attribute("num", in: openTag)?.trimmingCharacters(in: .whitespaces),
                      !artlNum.isEmpty else {
                    completion(.error("게시글을 등록했지만 번호를 확인하지 못했습니다."))
                    return
                }
                self.writeFirebaseArticle(articleId: artlNum, title: title, content: content, imageUrls: imageUrls, completion: completion)
            }
        }
    }

    // Android insertArticleToFirebase 미러 — Articles/{groupKey}에 새 자식을 push한다. Android는
    // push().setValue(map) 직후(쓰기 완료를 기다리지 않고) callback.onSuccess(artlNum)을 부르는
    // fire-and-forget이라, 여기도 동일하게 ref.setValue 호출 직후 곧바로 completion(.success)한다
    // (ReplyRemoteDataSource.addReply와 같은 방침). groupKey/database가 없으면(Firebase 미설정) 그 보강만
    // 생략하고 LMS 결과(articleId/title/content/imageUrls)만으로 성공 처리한다 — completion은 두 분기
    // 중 정확히 한 곳에서만 불린다.
    private func writeFirebaseArticle(articleId: String, title: String, content: String, imageUrls: [String], completion: @escaping (Resource<ArticleItem>) -> Void) {
        let user = PreferenceManager.shared.user
        let timestamp = Date()
        var item = ArticleItem(
            id: articleId,
            key: nil,
            uid: user?.uid ?? "",
            name: user?.name ?? "",
            title: title,
            content: content,
            images: imageUrls,
            youtubeId: nil,
            replyCount: 0,
            timestamp: timestamp,
            isAuth: true
        )

        guard let groupKey = groupKey, let root = FirebaseRef.database() else {
            completion(.success(item))
            return
        }
        let ref = root.child("Articles").child(groupKey).childByAutoId()
        let map: [String: Any] = [
            "id": articleId,
            "uid": item.uid,
            "name": item.name,
            "title": title,
            "timestamp": Int64(timestamp.timeIntervalSince1970 * 1000),
            "content": content,
            "images": imageUrls
        ]

        item.key = ref.key
        ref.setValue(map)
        completion(.success(item))
    }

    // MARK: - 수정 (Task 17)

    // Android CreateArticleViewModel.actionUpdate → ArticleRemoteDataSource.setArticle 미러. Android는
    // MODIFY_ARTICLE 응답 자체의 isError를 확인하지 않고(WRITE_ARTICLE/DELETE_ARTICLE과 달리) 전송
    // 성공(HTTP 2xx)이면 곧바로 Firebase 갱신으로 넘어가므로 여기서도 동일하게 처리한다.
    func setArticle(articleId: String, key: String?, title: String, content: String, imageUrls: [String], completion: @escaping (Resource<ArticleItem>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let htmlContent = ArticleRemoteDataSource.buildContentHtml(text: content, imageUrls: imageUrls)
        let formParams = [
            "CLUB_GRP_ID": groupId,
            "ARTL_NUM": articleId,
            "SBJT": title,
            "TXT": htmlContent
        ]

        HttpClient.request(EndPoint.modifyArticle, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success:
                self.updateFirebaseArticle(articleId: articleId, key: key, title: title, content: content, imageUrls: imageUrls, completion: completion)
            }
        }
    }

    // Android updateArticleDataToFirebase 미러 — read(기존 Firebase 항목 조회) → modify(title/content/
    // images만 교체, uid/name/timestamp는 보존) → write. 원본은 못 찾으면 callback.onSuccess(null)로
    // 조용히 아무 것도 안 하는 Android 특유의 edge case가 있는데(CreateArticleViewModel.actionUpdate가
    // data==null이면 setArticleId/setMessage를 아예 안 불러 화면이 멈춘 것처럼 보임), 이 포팅은 그 결함을
    // 새로 만들지 않기 위해 못 찾아도 LMS 결과 기반 fallback으로 항상 성공 처리한다(Firebase nil-skip
    // 원칙 — ArticleRemoteDataSource.mergeFirebase 등 이 파일의 다른 보강 실패 처리와 동일). completion은
    // guard-else 분기와 with/withCancel 중 정확히 한 곳에서만 불린다.
    private func updateFirebaseArticle(articleId: String, key: String?, title: String, content: String, imageUrls: [String], completion: @escaping (Resource<ArticleItem>) -> Void) {
        let fallback = ArticleItem(
            id: articleId,
            key: key,
            uid: PreferenceManager.shared.user?.uid ?? "",
            name: PreferenceManager.shared.user?.name ?? "",
            title: title,
            content: content,
            images: imageUrls,
            youtubeId: nil,
            replyCount: 0,
            timestamp: Date(),
            isAuth: true
        )

        guard let groupKey = groupKey, let key = key, let root = FirebaseRef.database() else {
            completion(.success(fallback))
            return
        }
        let ref = root.child("Articles").child(groupKey).child(key)

        ref.observeSingleEvent(of: .value, with: { snapshot in
            guard var data = snapshot.value as? [String: Any] else {
                completion(.success(fallback))
                return
            }
            var result = fallback

            data["title"] = title
            data["content"] = content
            data["images"] = imageUrls
            ref.setValue(data)
            if let uid = data["uid"] as? String {
                result.uid = uid
            }
            if let name = data["name"] as? String {
                result.name = name
            }
            if let ms = (data["timestamp"] as? NSNumber)?.doubleValue {
                result.timestamp = Date(timeIntervalSince1970: ms / 1000)
            }
            completion(.success(result))
        }, withCancel: { _ in
            completion(.success(fallback))
        })
    }

    // MARK: - 본문 HTML 조립

    // Android Html.toHtml(spannableContent, TO_HTML_PARAGRAPH_LINES_INDIVIDUAL) + CreateArticleViewModel.
    // uploadProcess의 "<p><img src=...><p>" 이어붙이기를 한 함수로 합친 것 — 평문을 줄 단위로 <p>에 담고,
    // 그 뒤에 이미지 URL마다 <p><img></p> 문단을 덧붙인다. parseArticles/parseArticleDetail이 list_cont를
    // <p> 단위(HtmlUtil.cells(tag:"p"))/문단 단위(paragraphs)로 되읽는 것과 왕복이 맞아야 하므로, 줄바꿈
    // 없는 빈 본문(이미지만 있는 글)도 이미지 문단만으로 정상 파싱된다.
    private static func buildContentHtml(text: String, imageUrls: [String]) -> String {
        var paragraphs: [String] = []

        if !text.isEmpty {
            paragraphs.append(contentsOf: text.components(separatedBy: "\n").map { "<p>\(escapeHtml($0))</p>" })
        }
        paragraphs.append(contentsOf: imageUrls.map { "<p><img src=\"\($0)\" width=\"488\"></p>" })
        return paragraphs.joined()
    }

    private static func escapeHtml(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    // MARK: - 이미지 업로드 (Task 17)

    // Android addArticleImage(cookie:bitmap:callback:) 미러 — file_upload_pop.acl에 이미지 하나를
    // multipart로 올리고, 응답 본문에서 "/ilosfiles/"로 시작해 다음 큰따옴표 앞까지의 경로를 잘라
    // BASE_URL을 붙인다(Android: imageSrc.substring(lastIndexOf("/ilosfiles/"), lastIndexOf("\""))).
    // Android는 PNG(quality 80)로 압축하지만 파일명은 ".jpg"를 쓰는 불일치가 있었다 — 여기서는 파일명과
    // 실제 인코딩을 일치시켜 JPEG(quality 0.8)로 압축한다(서버가 확장자보다 실제 바이트를 신뢰하는
    // 한 무해한 개선). 리사이즈는 이 함수의 책임이 아니다 — 호출자(CreateArticleViewModel.send())가
    // BitmapUtil.resized(maxSize: 1280)를 먼저 적용한 뒤 넘긴다.
    func uploadImage(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let fileData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(AppError(message: "이미지 변환에 실패했습니다.")))
            return
        }
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let fileName = "\(Int64(Date().timeIntervalSince1970 * 1000)).jpg"

        MultipartRequest.upload(EndPoint.imageUpload,
                                 headers: ["Cookie": cookie],
                                 fileField: "file",
                                 fileName: fileName,
                                 mimeType: "image/jpeg",
                                 fileData: fileData,
                                 formParams: [:]) { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let response):
                guard let ilosRange = response.range(of: "/ilosfiles/", options: .backwards),
                      let quoteRange = response.range(of: "\"", options: .backwards),
                      quoteRange.lowerBound > ilosRange.lowerBound else {
                    completion(.failure(AppError(message: "이미지 업로드 응답을 해석할 수 없습니다.")))
                    return
                }
                let path = String(response[ilosRange.lowerBound..<quoteRange.lowerBound])

                completion(.success(EndPoint.baseURL + path))
            }
        }
    }

    // MARK: - Firebase 병합

    private func mergeFirebase(_ parsed: [(id: String, item: ArticleItem)], completion: @escaping (Resource<[ArticleItem]>) -> Void) {
        guard !parsed.isEmpty else {
            completion(.success([]))
            return
        }
        guard let groupKey = groupKey, let root = FirebaseRef.database() else {
            completion(.success(parsed.map { $0.item }))
            return
        }

        root.child("Articles").child(groupKey).observeSingleEvent(of: .value, with: { snapshot in
            var result = parsed

            for case let child as DataSnapshot in snapshot.children {
                guard let lmsId = child.childSnapshot(forPath: "id").value as? String,
                      let index = result.firstIndex(where: { $0.id == lmsId }) else {
                    continue
                }
                var item = result[index].item

                item.key = child.key
                if let uid = child.childSnapshot(forPath: "uid").value as? String {
                    item.uid = uid
                }
                if let images = child.childSnapshot(forPath: "images").value as? [String] {
                    item.images = images
                }
                if let ms = (child.childSnapshot(forPath: "timestamp").value as? NSNumber)?.doubleValue {
                    item.timestamp = Date(timeIntervalSince1970: ms / 1000)
                }
                if let videoId = child.childSnapshot(forPath: "youtube").childSnapshot(forPath: "videoId").value as? String {
                    item.youtubeId = videoId
                }
                if let uid = PreferenceManager.shared.user?.uid, uid == item.uid {
                    item.isAuth = true
                }
                result[index] = (id: result[index].id, item: item)
            }
            completion(.success(result.map { $0.item }))
        }, withCancel: { _ in
            // Firebase 조회 실패는 부가 보강 실패일 뿐이므로 LMS 파싱 결과만으로 성공 처리한다
            // (GroupRemoteDataSource.mergeFirebaseKeys와 동일한 방침).
            completion(.success(parsed.map { $0.item }))
        })
    }

    // MARK: - 상세 조회

    // Android getArticleData(cookie:articleId:articleKey:params:callback:)는 "?CLUB_GRP_ID=..&
    // startL=<position>&displayL=1"로 목록 엔드포인트를 재조회해 첫 listbox2 하나만 꺼낸다 — position은
    // Tab1Fragment의 RecyclerView 어댑터 포지션을 Intent extra로 그대로 넘겨받은 값이라, 그 사이 다른
    // 글이 올라오면 어긋날 수 있는 목록-오프셋 기반 조회다. 이 브리프의 fetchArticle(articleId:)는
    // position을 받지 않으므로(Task 12의 Tab1View→Task 16 push 경로가 어댑터 포지션을 들고 다니지
    // 않는다) 대신 ARTL_NUM을 폼 파라미터로 함께 보낸다 — 같은 게시글을 가리키는 식별자로 이미
    // share_delete.acl/share_update.acl 둘 다 ARTL_NUM을 받아들이므로, share_list.acl도 이를 필터로
    // 지원할 가능성이 높다는 판단이다(같은 리소스를 다루는 형제 액션들이 식별자 파라미터명을 공유하는
    // 것은 이런 레거시 JSP 액션 계열에서 흔한 패턴). 다만 이는 실서버로 검증할 수 없는 가정이라, 서버가
    // ARTL_NUM을 무시하고 기본 페이지만 돌려주는 최악의 경우에 대비해 matchedListboxBlock이 반환된
    // listbox2 블록들 중 comment_wrap의 "num" 속성이 articleId와 실제로 일치하는 것만 찾는다 — 일치하는
    // 블록이 없으면(서버가 필터를 무시했고 대상이 그 페이지 안에도 없는 경우) 절대 다른 블록으로
    // 대체하지 않고 곧바로 에러 처리한다(리뷰 지적사항 반영 — 예전엔 첫 블록으로 폴백했는데, 그건 다른
    // 사람의 글/댓글을 이 글인 것처럼 조용히 잘못 보여줄 수 있는 위험한 동작이었다. position을 새로
    // 배관하지 않는 대신 택한 단순화가, 틀린 화면을 보여주는 대가를 치러서는 안 된다).
    func fetchArticle(articleId: String, completion: @escaping (Resource<ArticleItem>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "CLUB_GRP_ID": groupId,
            "ARTL_NUM": articleId,
            "displayL": "1"
        ]

        HttpClient.request(EndPoint.groupArticleList, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                // 반환된 블록들 중 num(ARTL_NUM)이 실제로 일치하는 것을 찾는다 — 서버가 ARTL_NUM
                // 필터를 무시하고 기본 페이지를 돌려주는 경우, 예전엔 그 페이지의 첫 블록으로
                // "그럴듯하게" 대체했지만 그건 다른 사람의 글/댓글을 이 글인 것처럼 잘못 보여줄 수
                // 있는(개인정보 노출) 조용한 오류였다 — 리뷰 지적사항 반영: 이제 못 찾으면 그 자리에서
                // 명시적으로 에러 처리한다(폴백 없음). ArticleViewModel의 .error 경로는 article이
                // nil이면 기존 Tab1에서 넘어온 article을 그대로 유지하므로 화면이 깨지지 않는다.
                guard let matched = ArticleRemoteDataSource.matchedListboxBlock(articleId: articleId, in: html) else {
                    completion(.error("게시글을 찾을 수 없습니다."))
                    return
                }
                guard let item = self.parseArticleDetail(articleId: articleId, from: matched) else {
                    completion(.error("게시글을 불러오지 못했습니다."))
                    return
                }
                self.mergeFirebaseDetail(item, completion: completion)
            }
        }
    }

    // listbox2 블록들 중 comment_wrap의 num 속성이 articleId와 일치하는 블록만 반환한다(블록 자체가
    // 없거나 일치하는 블록이 없으면 nil — 더 이상 첫 블록으로 대체하지 않는다).
    private static func matchedListboxBlock(articleId: String, in html: String) -> String? {
        let blocks = ArticleRemoteDataSource.splitBlocks(class: "listbox2", in: html)

        return blocks.first(where: { block in
            guard let commentWrapChunk = ArticleRemoteDataSource.sliceToEnd(from: "comment_wrap", in: block),
                  let commentWrapOpenTag = ArticleRemoteDataSource.openTag(class: "comment_wrap", in: commentWrapChunk),
                  let id = HtmlUtil.attribute("num", in: commentWrapOpenTag)?.trimmingCharacters(in: .whitespaces) else {
                return false
            }
            return id == articleId
        })
    }

    private func parseArticleDetail(articleId: String, from matched: String) -> ArticleItem? {
        guard let viewArtChunk = ArticleRemoteDataSource.slice(from: "view_art", upTo: "comment_wrap", in: matched),
              let commentWrapChunk = ArticleRemoteDataSource.sliceToEnd(from: "comment_wrap", in: matched),
              let titleInner = ArticleRemoteDataSource.elementText(class: "list_title", in: viewArtChunk) else {
            return nil
        }
        let listTitle = HtmlUtil.text(titleInner)

        guard let dashRange = listTitle.range(of: "-", options: .backwards) else {
            return nil
        }
        let title = String(listTitle[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let name = String(listTitle[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
        let date = HtmlUtil.cells(in: viewArtChunk, tag: "td").first
        let timestamp = date.flatMap(DateUtil.timestamp(from:))
        let contentInner = ArticleRemoteDataSource.elementText(class: "list_cont", in: viewArtChunk) ?? ""
        let content = HtmlUtil.cells(in: contentInner, tag: "p").joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let auth = ArticleRemoteDataSource.openTag(class: "btn-small-gray", in: viewArtChunk) != nil
        let replyText = ArticleRemoteDataSource.elementText(class: "commentBtn", in: commentWrapChunk).map(HtmlUtil.text) ?? ""
        let replyCount = ArticleRemoteDataSource.firstInt(in: replyText)

        // Android imageExtract/youtubeExtract 미러 — list_cont를 <p> 단위로 순회해 문단마다 첫 <img>가
        // 있으면 이미지로, 없고 youtube-player가 있으면 유튜브로 처리한다(목록 파싱의 viewArt 전체
        // 스캔보다 더 정밀한 스코프 — 상세 전용으로 이 정밀도를 쓰는 이유는 이 파일 상단 코멘트 참고).
        var images: [String] = []
        var youtubeId: String?

        for paragraph in ArticleRemoteDataSource.paragraphs(in: contentInner) {
            if let image = ArticleRemoteDataSource.imageSources(in: paragraph).first {
                images.append(image)
            } else if youtubeId == nil,
                      let youtubeTag = ArticleRemoteDataSource.openTag(class: "youtube-player", in: paragraph),
                      let rawSrc = HtmlUtil.attribute("src", in: youtubeTag) {
                youtubeId = ArticleRemoteDataSource.youtubeId(fromSrc: HtmlUtil.text(rawSrc))
            }
        }

        // Android articleItem.setId(articleId)와 동일 — matched는 이미 num==articleId로 확인된 블록이라
        // 굳이 파싱해서 다시 비교할 필요 없이 호출자가 요청한 값을 그대로 쓴다.
        return ArticleItem(
            id: articleId,
            key: nil,
            uid: "",
            name: name,
            title: title,
            content: content,
            images: images,
            youtubeId: youtubeId,
            replyCount: replyCount,
            timestamp: timestamp,
            isAuth: auth
        )
    }

    // mergeFirebase(목록용)와 같은 필드(uid/images/timestamp/youtubeId)를 보강하지만 단건이라 배열 탐색 대신
    // 첫 일치 항목에서 멈춘다. groupKey/database가 없으면 LMS 파싱 결과만으로 성공 처리(부가 보강 생략)한다.
    private func mergeFirebaseDetail(_ item: ArticleItem, completion: @escaping (Resource<ArticleItem>) -> Void) {
        guard let groupKey = groupKey, let root = FirebaseRef.database() else {
            completion(.success(item))
            return
        }

        root.child("Articles").child(groupKey).observeSingleEvent(of: .value, with: { snapshot in
            var result = item

            for case let child as DataSnapshot in snapshot.children {
                guard let lmsId = child.childSnapshot(forPath: "id").value as? String, lmsId == result.id else {
                    continue
                }
                result.key = child.key
                if let uid = child.childSnapshot(forPath: "uid").value as? String {
                    result.uid = uid
                }
                if let images = child.childSnapshot(forPath: "images").value as? [String] {
                    result.images = images
                }
                if let ms = (child.childSnapshot(forPath: "timestamp").value as? NSNumber)?.doubleValue {
                    result.timestamp = Date(timeIntervalSince1970: ms / 1000)
                }
                if let videoId = child.childSnapshot(forPath: "youtube").childSnapshot(forPath: "videoId").value as? String {
                    result.youtubeId = videoId
                }
                if let uid = PreferenceManager.shared.user?.uid, uid == result.uid {
                    result.isAuth = true
                }
                break
            }
            completion(.success(result))
        }, withCancel: { _ in
            completion(.success(item))
        })
    }

    // list_cont 내부를 <p> 단위로 끊어 태그를 보존한 채 반환한다(HtmlUtil.cells는 blocks 후 text()로
    // 태그를 지워버려 이미지/유튜브 판별에는 쓸 수 없다 — 이 파일만의 로컬 보조 함수로 남긴다).
    private static func paragraphs(in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "<p\\b[^>]*>.*?</p>", options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        return matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: html) else {
                return nil
            }
            return String(html[range])
        }
    }

    // MARK: - HTML 파싱

    private func parseArticles(from html: String) -> [(id: String, item: ArticleItem)] {
        var result: [(id: String, item: ArticleItem)] = []
        let blocks = ArticleRemoteDataSource.splitBlocks(class: "listbox2", in: html)

        articleLoop: for block in blocks {
            guard let viewArtChunk = ArticleRemoteDataSource.slice(from: "view_art", upTo: "comment_wrap", in: block),
                  let commentWrapChunk = ArticleRemoteDataSource.sliceToEnd(from: "comment_wrap", in: block),
                  let commentWrapOpenTag = ArticleRemoteDataSource.openTag(class: "comment_wrap", in: commentWrapChunk),
                  let idString = HtmlUtil.attribute("num", in: commentWrapOpenTag)?.trimmingCharacters(in: .whitespaces),
                  !idString.isEmpty,
                  let id = Int64(idString) else {
                continue
            }

            // 중복/마지막 페이지 감지 — Android mMinId 로직을 순서까지 그대로 미러(값 갱신 후 비교,
            // 조건이 참이면 이 항목은 만들지 않고 이 응답의 나머지도 처리하지 않는다).
            minId = (minId == nil) ? id : min(minId!, id)
            if id > minId! {
                stopRequestMore = true
                break articleLoop
            }
            stopRequestMore = false

            guard let titleInner = ArticleRemoteDataSource.elementText(class: "list_title", in: viewArtChunk) else {
                continue
            }
            let listTitle = HtmlUtil.text(titleInner)

            guard let dashRange = listTitle.range(of: "-", options: .backwards) else {
                continue
            }
            let title = String(listTitle[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let name = String(listTitle[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            let date = HtmlUtil.cells(in: viewArtChunk, tag: "td").first
            let timestamp = date.flatMap(DateUtil.timestamp(from:))
            let contentInner = ArticleRemoteDataSource.elementText(class: "list_cont", in: viewArtChunk) ?? ""
            let content = HtmlUtil.cells(in: contentInner, tag: "p").joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            let images = ArticleRemoteDataSource.imageSources(in: viewArtChunk)
            let auth = ArticleRemoteDataSource.openTag(class: "btn-small-gray", in: viewArtChunk) != nil
            let replyText = ArticleRemoteDataSource.elementText(class: "commentBtn", in: commentWrapChunk).map(HtmlUtil.text) ?? ""
            let replyCount = ArticleRemoteDataSource.firstInt(in: replyText)
            var youtubeId: String?

            if let youtubeTag = ArticleRemoteDataSource.openTag(class: "youtube-player", in: viewArtChunk),
               let rawSrc = HtmlUtil.attribute("src", in: youtubeTag) {
                youtubeId = ArticleRemoteDataSource.youtubeId(fromSrc: HtmlUtil.text(rawSrc))
            }

            let item = ArticleItem(
                id: idString,
                key: nil,
                uid: "",
                name: name,
                title: title,
                content: content,
                images: images,
                youtubeId: youtubeId,
                replyCount: replyCount,
                timestamp: timestamp,
                isAuth: auth
            )

            result.append((id: idString, item: item))
        }
        return result
    }

    private static func imageSources(in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: "<img\\b[^>]*>", options: [.caseInsensitive]) else {
            return []
        }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        return matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: html),
                  let rawSrc = HtmlUtil.attribute("src", in: String(html[range])) else {
                return nil
            }
            let src = HtmlUtil.text(rawSrc)

            return src.contains("http") ? src : EndPoint.baseURL + src
        }
    }

    private static func youtubeId(fromSrc src: String) -> String? {
        guard let slashRange = src.range(of: "/", options: .backwards) else {
            return nil
        }
        let afterSlash = src[slashRange.upperBound...]

        if let queryRange = afterSlash.range(of: "?") {
            return String(afterSlash[..<queryRange.lowerBound])
        }
        // Android 원본은 "?"가 없으면 substring(x, -1)로 크래시하지만(바깥 try/catch로 그 문단만 스킵됨),
        // 여기서는 남은 문자열 전체를 id로 삼아 크래시 없이 안전하게 성능 저하 없는 결과를 낸다.
        return String(afterSlash)
    }

    private static func firstInt(in text: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: "\\d+", options: []),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return 0
        }
        return Int(text[range]) ?? 0
    }

    // MARK: - 클래스 기반 블록 추출 (Jericho getAllElementsByClass/getFirstElementByClass 미러)

    private static func openTagPattern(class className: String) -> String {
        "<[a-zA-Z][a-zA-Z0-9]*\\b[^>]*\\bclass\\s*=\\s*[\"'][^\"']*\\b\(NSRegularExpression.escapedPattern(for: className))\\b[^\"']*[\"'][^>]*>"
    }

    private static func firstMatchRange(pattern: String, in html: String, from location: Int = 0) -> NSRange? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }
        let nsHtml = html as NSString

        guard location <= nsHtml.length else {
            return nil
        }
        let searchRange = NSRange(location: location, length: nsHtml.length - location)

        return regex.firstMatch(in: html, range: searchRange)?.range
    }

    // className 토큰을 가진 여는 태그 자체(문자열)만 반환 — num/src 같은 속성만 필요할 때 쓴다.
    private static func openTag(class className: String, in html: String) -> String? {
        guard let range = firstMatchRange(pattern: openTagPattern(class: className), in: html) else {
            return nil
        }
        return (html as NSString).substring(with: range)
    }

    // html을 className 여는 태그가 시작하는 지점마다 잘라 "다음 같은 클래스가 시작하는 지점 직전까지"를
    // 한 블록으로 반환한다(listbox2처럼 같은 뎁스에서 반복되는 형제 요소를 닫는 태그 탐색 없이 나눈다).
    private static func splitBlocks(class className: String, in html: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: openTagPattern(class: className), options: [.caseInsensitive]) else {
            return []
        }
        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))
        var blocks: [String] = []

        for (index, match) in matches.enumerated() {
            let start = match.range.location
            let end = (index + 1 < matches.count) ? matches[index + 1].range.location : nsHtml.length

            guard end > start else {
                continue
            }
            blocks.append(nsHtml.substring(with: NSRange(location: start, length: end - start)))
        }
        return blocks
    }

    // startClass의 여는 태그부터 그 뒤에 처음 나오는 endClass의 여는 태그 시작 직전까지(형제 경계)를
    // 반환한다. view_art→comment_wrap처럼 서로 형제인 두 요소를 닫는 태그 탐색 없이 나눌 때 쓴다.
    private static func slice(from startClass: String, upTo endClass: String, in html: String) -> String? {
        guard let startRange = firstMatchRange(pattern: openTagPattern(class: startClass), in: html) else {
            return nil
        }
        let nsHtml = html as NSString
        let endRange = firstMatchRange(pattern: openTagPattern(class: endClass), in: html, from: startRange.location + startRange.length)
        let sliceEnd = endRange?.location ?? nsHtml.length

        guard sliceEnd > startRange.location else {
            return nil
        }
        return nsHtml.substring(with: NSRange(location: startRange.location, length: sliceEnd - startRange.location))
    }

    // startClass의 여는 태그부터 문자열 끝까지 반환 — comment_wrap처럼 블록의 마지막 형제일 때 쓴다.
    private static func sliceToEnd(from startClass: String, in html: String) -> String? {
        guard let startRange = firstMatchRange(pattern: openTagPattern(class: startClass), in: html) else {
            return nil
        }
        return (html as NSString).substring(from: startRange.location)
    }

    // className 요소의 여는 태그부터 "같은 태그명"의 첫 닫는 태그까지의 내부 HTML을 반환한다(태그명은
    // 백레퍼런스 \1로 고정 — HtmlUtil.attributeExact의 따옴표 백레퍼런스와 같은 기법). list_title/
    // list_cont처럼 내부에 같은 태그가 중첩되지 않는 단일 요소에만 안전하다.
    private static func elementText(class className: String, in html: String) -> String? {
        let pattern = "<([a-zA-Z][a-zA-Z0-9]*)\\b[^>]*\\bclass\\s*=\\s*[\"'][^\"']*\\b\(NSRegularExpression.escapedPattern(for: className))\\b[^\"']*[\"'][^>]*>(.*?)</\\1>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 2), in: html) else {
            return nil
        }
        return String(html[range])
    }
}
