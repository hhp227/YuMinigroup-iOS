//
//  ReplyRemoteDataSource.swift
//  YuMinigroup
//
//  Android data.remote.ReplyRemoteDataSource 대응 — 게시글 댓글의 LMS HTML 파싱 + Firebase
//  Replys/{articleKey} 이중기록. ArticleRemoteDataSource.swift와 마찬가지로 정규식 기반 파서이고,
//  같은 "className 여는 태그부터 다음 형제 className 시작 직전까지"(splitBlocks) 기법을 쓴다 — 이
//  파일은 ArticleRemoteDataSource의 private static 파서 헬퍼(openTag/splitBlocks/elementText 등)에
//  접근할 수 없어(다른 타입, private) 필요한 만큼만 아래에 그대로 복제해 자기완결형으로 둔다.
//
//  fetchReplys(completion:)는 Android ArticleViewModel.fetchArticleData()가 getArticleData 응답에서
//  같이 뽑아내는 "comment-list" 목록을 독립 호출로 재현한다 — Android는 상세 글 조회와 댓글 목록을
//  같은 한 번의 HTTP 응답(콜백이 onSuccess를 commentList/articleItem 두 번 부르는 구조)에서 얻지만,
//  이 브리프는 ArticleRemoteDataSource.fetchArticle과 ReplyRemoteDataSource.fetchReplys를 별도
//  메소드/타입으로 분리했으므로 동일한 groupArticleList 요청을 각자 한 번씩 보낸다(대역폭은 약간
//  낭비지만, 두 데이터소스를 결합하는 것보다 경계가 단순하고 여기서 완결된다). ARTL_NUM 기반 조회
//  선택 이유는 ArticleRemoteDataSource.fetchArticle 코멘트와 동일 — 그 코멘트 참고.
//
//  comment-list 한 건의 구조(Android getReplyList 기준): comment-name(이름+"("+날짜+")", 본인 글이면
//  <input> 태그 포함) + comment-addr(id="cmt_txt_<replyId>", 내부 컨텐츠가 댓글 본문). 이름/댓글은
//  각각 마지막 "(" 앞부분 / <br> → \n 변환(HtmlUtil.text)으로 뽑는다.
//
//  Firebase 쓰기는 메소드별로 다르다: addReply/removeReply는 Android insertReplyToFirebase/
//  deleteReplyFromFirebase처럼 fire-and-forget(쓰기 완료를 기다리지 않고 LMS 파싱 결과로 바로
//  completion)이라 completion은 그 자리에서 정확히 한 번만 불린다. setReply(수정)만 Android
//  updateReplyDataToFirebase처럼 read-modify-write(기존 reply 항목을 먼저 읽어 uid/name/timestamp는
//  보존한 채 reply 텍스트만 바꿔 다시 쓴다)라 Firebase observeSingleEvent의 with/withCancel 중 정확히
//  하나에서만 completion을 부른다 — 두 completion 호출 경로가 겹치지 않는지가 이 파일에서 가장 주의
//  깊게 봐야 할 지점이다(파일 하단 각 메소드 코멘트에 completion 호출 지점을 명시해 뒀다).
//
//  setReply(replyId:text:completion:)는 브리프 시그니처에 replyKey가 없다 — Android
//  UpdateReplyViewModel은 Intent extra로 미리 받아둔 replyKey를 바로 쓰지만, 이 파일은 그 값을
//  안 받으므로 Replys/{articleKey} 자식들을 "id" 필드로 매칭해 키를 스스로 찾는다(ArticleRemoteDataSource.
//  mergeFirebase가 "id"로 매칭하는 것과 같은 패턴). Android의 setReply는 응답 문자열을 그대로
//  콜백에 넘기고(댓글 목록으로 재파싱하지 않는다) 그 원문이 실제로 comment-list HTML을 담고 있는지
//  확인할 근거가 없어(Android 자신도 파싱하지 않는다), 여기서는 그 가정을 하지 않고 Resource<Bool>
//  (성공 여부)만 돌려준다 — 아직 이 값을 쓰는 화면(UpdateReplyView)이 없는 Task 18 몫이라, Task 18은
//  수정 성공 후 fetchReplys()를 다시 불러 최신 목록을 얻는 편이 이 가정보다 안전하다.
//

import Foundation
import FirebaseDatabase

final class ReplyRemoteDataSource {
    private let groupId: String
    private let articleId: String
    private let articleKey: String?

    init(groupId: String, articleId: String, articleKey: String?) {
        self.groupId = groupId
        self.articleId = articleId
        self.articleKey = articleKey
    }

    // MARK: - 목록 조회

    func fetchReplys(completion: @escaping (Resource<[ReplyItem]>) -> Void) {
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
                let blocks = ReplyRemoteDataSource.splitBlocks(class: "listbox2", in: html)

                // 응답 자체에 listbox2가 하나도 없으면(그룹에 글이 아예 없는 등) 댓글 없음으로 조용히
                // 넘어간다 — 이건 그대로 유지한다. 하지만 블록이 있는데 그중 num(ARTL_NUM)이 실제로
                // 일치하는 게 하나도 없으면(서버가 필터를 무시하고 다른 페이지를 돌려준 경우) 예전엔
                // 첫 블록의 댓글을 "이 글의 댓글"인 것처럼 잘못 보여줄 수 있었다(다른 사람의 댓글 내용
                // 노출 — ArticleRemoteDataSource.fetchArticle과 같은 문제, 리뷰 지적사항 반영으로 함께
                // 고쳤다). 이제 못 찾으면 폴백하지 않고 에러 처리한다.
                guard !blocks.isEmpty else {
                    completion(.success([]))
                    return
                }
                guard let matched = blocks.first(where: { block in
                    guard let commentWrapChunk = ReplyRemoteDataSource.sliceToEnd(from: "comment_wrap", in: block),
                          let openTag = ReplyRemoteDataSource.openTag(class: "comment_wrap", in: commentWrapChunk),
                          let id = HtmlUtil.attribute("num", in: openTag)?.trimmingCharacters(in: .whitespaces) else {
                        return false
                    }
                    return id == self.articleId
                }) else {
                    completion(.error("게시글을 찾을 수 없습니다."))
                    return
                }
                let parsed = self.parseReplys(scopedHtml: matched)

                self.mergeFirebase(parsed, completion: completion)
            }
        }
    }

    // MARK: - 작성

    func addReply(text: String, completion: @escaping (Resource<[ReplyItem]>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "CLUB_GRP_ID": groupId,
            "ARTL_NUM": articleId,
            "CMT": text
        ]

        HttpClient.request(EndPoint.insertReply, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                let parsed = self.parseReplys(scopedHtml: html)

                // Android insertReplyToFirebase 미러 — fire-and-forget(쓰기 완료를 기다리지 않는다).
                // 새로 삽입된 댓글은 Android처럼 방금 파싱한 목록의 마지막 항목으로 가정한다.
                if let articleKey = self.articleKey,
                   let root = FirebaseRef.database(),
                   let user = PreferenceManager.shared.user,
                   let newId = parsed.last?.id {
                    let map: [String: Any] = [
                        "id": newId,
                        "uid": user.uid ?? "",
                        "name": user.name ?? "",
                        "reply": text,
                        "timestamp": Int64(Date().timeIntervalSince1970 * 1000)
                    ]

                    root.child("Replys").child(articleKey).childByAutoId().setValue(map)
                }
                // completion은 fire-and-forget Firebase 쓰기와 무관하게 mergeFirebase 내부에서 정확히
                // 한 번(성공 시 with:, 실패 시 withCancel:) 불린다.
                self.mergeFirebase(parsed, completion: completion)
            }
        }
    }

    // MARK: - 수정

    func setReply(replyId: String, text: String, completion: @escaping (Resource<Bool>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "CLUB_GRP_ID": groupId,
            "ARTL_NUM": articleId,
            "CMMT_NUM": replyId,
            "CMT": text
        ]

        HttpClient.request(EndPoint.modifyReply, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success:
                guard let articleKey = self.articleKey, let root = FirebaseRef.database() else {
                    completion(.success(true))
                    return
                }
                let query = root.child("Replys").child(articleKey)

                // Android updateReplyDataToFirebase 미러 — read(전체 자식 스캔, id로 매칭) →
                // modify(reply 필드만 text+"\n"으로 교체, Android 원문 그대로) → write. completion은
                // 아래 observeSingleEvent의 with:/withCancel: 중 정확히 한 곳에서만 불린다.
                query.observeSingleEvent(of: .value, with: { snapshot in
                    var matchedChild: DataSnapshot?

                    for case let child as DataSnapshot in snapshot.children {
                        if let lmsId = child.childSnapshot(forPath: "id").value as? String, lmsId == replyId {
                            matchedChild = child
                            break
                        }
                    }
                    guard let child = matchedChild else {
                        completion(.success(true))
                        return
                    }
                    var map = child.value as? [String: Any] ?? [:]

                    map["reply"] = text + "\n"
                    query.child(child.key).setValue(map)
                    completion(.success(true))
                }, withCancel: { _ in
                    completion(.success(true))
                })
            }
        }
    }

    // MARK: - 삭제

    func removeReply(replyId: String, replyKey: String?, completion: @escaping (Resource<[ReplyItem]>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "CLUB_GRP_ID": groupId,
            "CMMT_NUM": replyId,
            "ARTL_NUM": articleId
        ]

        HttpClient.request(EndPoint.deleteReply, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                // Android removeReply의 "!response.contains(...)" 실패 문자열 검사를 그대로 미러.
                guard !html.contains("처리를 실패했습니다") else {
                    completion(.error("삭제에 실패했습니다."))
                    return
                }
                if let articleKey = self.articleKey, let replyKey = replyKey, let root = FirebaseRef.database() {
                    // Android deleteReplyFromFirebase 미러 — fire-and-forget.
                    root.child("Replys").child(articleKey).child(replyKey).removeValue()
                }
                let parsed = self.parseReplys(scopedHtml: html)

                self.mergeFirebase(parsed, completion: completion)
            }
        }
    }

    // MARK: - Firebase 병합

    // ArticleRemoteDataSource.mergeFirebase와 같은 원칙: "id" 필드로 매칭해 key/uid를 보강하고,
    // PreferenceManager의 현재 uid와 일치하면 isAuth를 true로 승격(내려가지는 않음)한다. articleKey나
    // database가 없으면(레거시 게시글 등) 보강 없이 LMS 파싱 결과만으로 성공 처리한다.
    private func mergeFirebase(_ parsed: [(id: String, item: ReplyItem)], completion: @escaping (Resource<[ReplyItem]>) -> Void) {
        guard !parsed.isEmpty else {
            completion(.success([]))
            return
        }
        guard let articleKey = articleKey, let root = FirebaseRef.database() else {
            completion(.success(parsed.map { $0.item }))
            return
        }

        root.child("Replys").child(articleKey).observeSingleEvent(of: .value, with: { snapshot in
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
                if let ms = (child.childSnapshot(forPath: "timestamp").value as? NSNumber)?.doubleValue {
                    item.timestamp = Date(timeIntervalSince1970: ms / 1000)
                }
                if let uid = PreferenceManager.shared.user?.uid, uid == item.uid {
                    item.isAuth = true
                }
                result[index] = (id: result[index].id, item: item)
            }
            completion(.success(result.map { $0.item }))
        }, withCancel: { _ in
            completion(.success(parsed.map { $0.item }))
        })
    }

    // MARK: - HTML 파싱

    // scopedHtml은 이미 한 게시글 범위로 좁혀진 조각이어야 한다(fetchReplys는 listbox2 블록 하나,
    // addReply/removeReply는 해당 엔드포인트 응답 전체 — Android도 그 응답을 그대로 Source에 넘긴다).
    private func parseReplys(scopedHtml: String) -> [(id: String, item: ReplyItem)] {
        var result: [(id: String, item: ReplyItem)] = []
        let blocks = ReplyRemoteDataSource.splitBlocks(class: "comment-list", in: scopedHtml)

        for block in blocks {
            guard let commentNameInner = ReplyRemoteDataSource.elementText(class: "comment-name", in: block),
                  let commentAddrOpenTag = ReplyRemoteDataSource.openTag(class: "comment-addr", in: block),
                  let commentAddrInner = ReplyRemoteDataSource.elementText(class: "comment-addr", in: block),
                  let rawId = HtmlUtil.attribute("id", in: commentAddrOpenTag)?.trimmingCharacters(in: .whitespaces),
                  !rawId.isEmpty else {
                continue
            }
            let replyId = rawId.replacingOccurrences(of: "cmt_txt_", with: "")
            let fullName = HtmlUtil.text(commentNameInner)

            guard let parenRange = fullName.range(of: "(", options: .backwards) else {
                continue
            }
            let name = String(fullName[..<parenRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let dateRaw = HtmlUtil.cells(in: commentNameInner, tag: "span").first ?? ""
            let date = dateRaw.replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "").trimmingCharacters(in: .whitespaces)
            let reply = HtmlUtil.text(commentAddrInner)
            let isAuth = commentNameInner.range(of: "<input", options: [.caseInsensitive]) != nil
            let item = ReplyItem(
                id: replyId,
                key: nil,
                uid: "",
                name: name,
                reply: reply,
                date: date.isEmpty ? nil : date,
                timestamp: DateUtil.timestamp(from: date),
                isAuth: isAuth
            )

            result.append((id: replyId, item: item))
        }
        return result
    }

    // MARK: - 클래스 기반 블록 추출 (ArticleRemoteDataSource의 private static 헬퍼를 이 파일에 맞게 복제)

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

    private static func openTag(class className: String, in html: String) -> String? {
        guard let range = firstMatchRange(pattern: openTagPattern(class: className), in: html) else {
            return nil
        }
        return (html as NSString).substring(with: range)
    }

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

    private static func sliceToEnd(from startClass: String, in html: String) -> String? {
        guard let startRange = firstMatchRange(pattern: openTagPattern(class: startClass), in: html) else {
            return nil
        }
        return (html as NSString).substring(from: startRange.location)
    }

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
