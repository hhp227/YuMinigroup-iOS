//
//  TimetableRemoteDataSource.swift
//  YuMinigroup
//
//  Android fragment.SemesterTimeTableFragment(StringRequest+jericho) 대응 — 학기시간표 파싱(스펙
//  §4.2). 1차 계층 관례대로 VM이 아니라 이 계층에 네트워킹/파싱을 둔다(UnivNoticeRemoteDataSource/
//  SeatRemoteDataSource와 동일 경계). LMS 인증이 필요한 GET이라 Cookie 헤더가 필수다
//  (GroupRemoteDataSource.fetchMembers 관례 — CookieStore.shared.cookieHeader ?? "", 파라미터는 없음).
//
//  Android 원본은 jericho `Source(response).getFirstElementByClass("bbslist")`로 태그명을 가리지 않고
//  class="bbslist" 요소를 찾은 뒤 그 안의 모든 `<tr>`을 26개까지, 각 tr의 "직계 자식 엘리먼트"를 6개까지
//  순회한다(SemesterTimeTableFragment.java/helper/ui/SemesterTimetableView.java — 후자가 스펙 §2 결함 2의
//  "이식 기준 모델"이지만 그 모델이 고치는 결함은 모의시간표 셀 클릭 판정 쪽이라 학기시간표 파싱 자체는
//  프래그먼트 원본과 동일하다). 이 파서는 그 계약을 그대로 미러한다:
//  1) bbslistSegment(from:)로 class="bbslist"인 여는 태그를 찾고(태그명은 캡처 그룹으로 알아내
//     HtmlUtil.elementById와 동일한 방식 — 실제 페이지가 <table class="bbslist">인지 <div class="bbslist">
//     인지 확정할 수 없어 태그 불문으로 짠다) 그 태그의 첫 닫는 태그까지를 세그먼트로 슬라이싱한다.
//  2) HtmlUtil.rows(in:)(blocks(in:tag:"tr"))로 그 세그먼트 안의 tr 블록들을 최대 26개 얻는다.
//  3) 각 tr 블록에서 브리프가 제시한 두 대안 중 "행 문자열에서 <td|th> 블록 정규식"을 택한다 —
//     HtmlUtil.cells(in:tag:"td")와 cells(tag:"th")를 따로 뽑아 이어붙이면, 한 행에 th/td가 섞여
//     있을 때(예: 첫 열이 교시 레이블 th, 나머지가 데이터 td) 원래 열 순서가 깨진다. 로컬
//     cellBlocks(in:)는 정규식이 문서에 나온 순서대로 매치를 반환하므로 열 순서를 그대로 보존한다
//     (HtmlUtil.blocks(in:tag:)와 동일하게 "같은 태그가 셀 안에 중첩되면 정확히 못 다룬다"는 한계는
//     그대로 안고 간다 — 시간표 표는 셀 안에 표가 중첩되는 경우가 사실상 없어 실무적으로 안전하다).
//
//  `.bbslist` 세그먼트 자체를 못 찾으면 전체를 .error로 강등한다(UnivNoticeRemoteDataSource의
//  board-table 부재 처리와 동일 원칙, 메시지는 브리프 지시 "시간표를 불러오지 못했습니다." 그대로).
//  tr은 있지만 직계 셀이 0개인 행은 skip하지 않고 빈 배열 그대로 담는다(Android가 셀 없는 빈
//  LinearLayout 행도 그대로 추가하는 것과 동일 — 26행 카운트는 실제 tr 개수 기준이지 비지 않은 행
//  기준이 아니다).
//

import Foundation

final class TimetableRemoteDataSource {
    private static let maxRows = 26
    private static let maxColumns = 6

    // Android StringRequest(GET, EndPoint.TIMETABLE) + getHeaders()의 Cookie 대응. 첫 행=요일 헤더.
    func fetchSemesterTable(completion: @escaping (Resource<[[String]]>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""

        HttpClient.request(EndPoint.timetable, method: "GET", headers: ["Cookie": cookie]) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                guard let segment = TimetableRemoteDataSource.bbslistSegment(from: html) else {
                    completion(.error("시간표를 불러오지 못했습니다."))
                    return
                }
                completion(.success(TimetableRemoteDataSource.parseTable(from: segment)))
            }
        }
    }

    // MARK: - HTML 파싱 (스펙 §4.2)

    private static func bbslistSegment(from html: String) -> String? {
        let pattern = "<([a-zA-Z0-9]+)[^>]*\\bclass=[\"']bbslist[\"'][^>]*>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let tagNameRange = Range(match.range(at: 1), in: html),
              let openRange = Range(match.range, in: html) else {
            return nil
        }
        let tagName = String(html[tagNameRange])
        let closeTag = "</\(tagName)>"

        guard let closeRange = html.range(of: closeTag,
                                           options: [.caseInsensitive],
                                           range: openRange.upperBound..<html.endIndex) else {
            return nil
        }
        return String(html[openRange.lowerBound..<closeRange.upperBound])
    }

    private static func parseTable(from segment: String) -> [[String]] {
        return HtmlUtil.rows(in: segment).prefix(maxRows).map(TimetableRemoteDataSource.parseRow(_:))
    }

    private static func parseRow(_ rowHtml: String) -> [String] {
        return TimetableRemoteDataSource.cellBlocks(in: rowHtml).prefix(maxColumns).map(HtmlUtil.text(_:))
    }

    // <td>...</td> / <th>...</th>를 문서 순서 그대로 뽑는 로컬 헬퍼(HtmlUtil.blocks(in:tag:)는 태그 하나만
    // 받으므로 td/th를 한 번에 못 뽑는다 — 파일 헤더 코멘트 참고).
    private static func cellBlocks(in rowHtml: String) -> [String] {
        let pattern = "<(?:td|th)\\b[^>]*>(.*?)</(?:td|th)>"

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
}
