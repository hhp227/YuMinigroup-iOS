//
//  UnivNoticeRemoteDataSource.swift
//  YuMinigroup
//
//  Android viewmodel.UnivNoticeViewModel.fetchDataList/onResponse(jericho) 대응 — 이 리포는 1차
//  관례대로 VM이 아니라 DataSource+Repository 계층에 HTML 파싱/네트워킹을 둔다(스펙 §4.1 끝줄).
//  공개 GET, 쿠키/헤더 불필요(스펙 §8) — HttpClient.request를 headers 기본값([:])으로 그대로 호출한다.
//
//  파싱: `.board-table` 세그먼트(1차 GroupRemoteDataSource.allTags/세그먼트 관례 — "class="board-table"
//  여는 태그부터 </table>까지") → 그 안의 `<tbody>` 블록(로컬 정규식, HtmlUtil에 tbody 전용 함수가
//  없어 추가) → HtmlUtil.rows(tr들) → 각 행의 `<td>` 블록들. HtmlUtil.cells(in:tag:)는 태그를 제거한
//  텍스트만 돌려줘 href를 잃으므로, td 블록은 원본 내부 HTML을 보존하는 로컬 tdBlocks(_:)로 따로
//  뽑는다(HtmlUtil.text는 필드별로 나중에 적용). id는 td[1] 첫 `<a>`의 href를
//  CharacterSet(charactersIn: "=&")로 split한 인덱스 [3](Android
//  tds.get(1).getFirstElement(A).getAttributeValue("href").split("=|&")[3] 대응) — 인덱스 부족/빈
//  값이면 그 행만 skip한다(Android jericho 루프의 개별 예외 처리 대응, GroupRemoteDataSource와 동일
//  원칙). td[0](체크박스/번호 열)은 미사용.
//
//  board-table 세그먼트 자체를 못 찾으면(페이지 구조가 바뀐 경우) 전체를 .error로 강등한다(스펙 §4.1
//  결함 처리 목록에는 없지만 브리프가 명시). 세그먼트는 찾았는데 tbody/행이 비어 있으면(정말 공지가
//  없는 페이지일 수 있음) 빈 배열 성공으로 둔다 — board-table 유무 하나로 두 경우를 가른다(board-table이
//  없으면 파싱 결과도 항상 빈 배열이므로 "빈 배열 + board-table 없음"과 논리적으로 동치).
//

import Foundation

final class UnivNoticeRemoteDataSource {
    private static let pageSize = 10

    // Android fetchDataList(offset) 대응. articleLimit은 10 고정(인터페이스 계약).
    func fetchNotices(offset: Int, completion: @escaping (Resource<[BbsItem]>) -> Void) {
        completion(.loading)
        let urlString = EndPoint.yuNoticeList + "&articleLimit=\(UnivNoticeRemoteDataSource.pageSize)&article.offset=\(offset)"

        HttpClient.request(urlString) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                guard let segment = UnivNoticeRemoteDataSource.boardTableSegment(from: html) else {
                    completion(.error("목록을 불러오지 못했습니다."))
                    return
                }
                completion(.success(UnivNoticeRemoteDataSource.parseNotices(from: segment)))
            }
        }
    }

    // MARK: - HTML 파싱 (스펙 §4.1)

    private static func boardTableSegment(from html: String) -> String? {
        let pattern = "<[a-zA-Z0-9]+\\b[^>]*\\bclass=[\"']board-table[\"'][^>]*>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let openRange = Range(match.range, in: html) else {
            return nil
        }
        guard let closeRange = html.range(of: "</table>",
                                           options: [.caseInsensitive],
                                           range: openRange.upperBound..<html.endIndex) else {
            return nil
        }
        return String(html[openRange.lowerBound..<closeRange.upperBound])
    }

    private static func parseNotices(from segment: String) -> [BbsItem] {
        guard let tbody = UnivNoticeRemoteDataSource.tbodyBlock(in: segment) else {
            return []
        }
        return HtmlUtil.rows(in: tbody).compactMap(UnivNoticeRemoteDataSource.parseRow(_:))
    }

    // HtmlUtil에는 tbody 전용 추출 함수가 없어 blocks(in:tag:)와 동일한 형태(캡처그룹 1=내부 HTML)로
    // 로컬 구현한다.
    private static func tbodyBlock(in html: String) -> String? {
        let pattern = "<tbody[^>]*>(.*?)</tbody>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }

    // 행(tr 내부 문자열) 하나를 BbsItem으로. td[1]=제목(+첫 <a> href의 id), td[2]=작성자, td[3]=날짜.
    private static func parseRow(_ rowHtml: String) -> BbsItem? {
        let tds = UnivNoticeRemoteDataSource.tdBlocks(in: rowHtml)

        guard tds.count > 3,
              let anchorTag = UnivNoticeRemoteDataSource.firstMatch(pattern: "<a\\b[^>]*>", in: tds[1]),
              let href = HtmlUtil.attribute("href", in: anchorTag) else {
            return nil
        }
        let parts = href.components(separatedBy: CharacterSet(charactersIn: "=&"))

        guard parts.count > 3 else {
            return nil
        }
        let id = parts[3].trimmingCharacters(in: .whitespaces)

        guard !id.isEmpty else {
            return nil
        }
        return BbsItem(
            id: id,
            title: HtmlUtil.text(tds[1]),
            writer: HtmlUtil.text(tds[2]),
            date: HtmlUtil.text(tds[3])
        )
    }

    // HtmlUtil.cells(in:tag:)는 텍스트만 남겨 href를 잃으므로, <td>...</td>의 원본 내부 HTML을 그대로
    // 반환하는 로컬 헬퍼(GroupRemoteDataSource.allTags류 "로컬 헬퍼로" 관례 — 파일 헤더 코멘트 참고).
    private static func tdBlocks(in rowHtml: String) -> [String] {
        let pattern = "<td[^>]*>(.*?)</td>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let matches = regex.matches(in: rowHtml, range: NSRange(rowHtml.startIndex..., in: rowHtml))

        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: rowHtml) else {
                return nil
            }
            return String(rowHtml[range])
        }
    }

    private static func firstMatch(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range, in: html) else {
            return nil
        }
        return String(html[range])
    }
}
