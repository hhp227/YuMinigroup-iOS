//
//  HtmlUtil.swift
//  YuMinigroup
//
//  Android의 jericho HTML 파서 대응 — 정규식 기반 최소 구현.
//  KNU-iOS Helper/HtmlUtil.swift를 그대로 포트하고, YU 파서들이 쓰는 elementById/attribute/links를 추가했다.
//

import Foundation

enum HtmlUtil {
    // html 내의 <table>...</table> 블록들을 반환
    static func tables(in html: String) -> [String] {
        return blocks(in: html, tag: "table")
    }

    // 테이블 html 내의 <tr>...</tr> 블록들을 반환
    static func rows(in tableHtml: String) -> [String] {
        return blocks(in: tableHtml, tag: "tr")
    }

    // 행 html 내의 <th> 또는 <td> 내용(태그 제거된 텍스트)들을 반환
    static func cells(in rowHtml: String, tag: String) -> [String] {
        return blocks(in: rowHtml, tag: tag).map(text(_:))
    }

    // 특정 id를 가진 input 태그의 value 속성 값 (로그인 응답 파싱용)
    static func inputValue(byId id: String, in html: String) -> String? {
        let pattern = "<input[^>]*id=[\"']\(id)[\"'][^>]*>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range, in: html) else {
            return nil
        }
        let inputTag = String(html[range])
        let valuePattern = "value=[\"']([^\"']*)[\"']"

        guard let valueRegex = try? NSRegularExpression(pattern: valuePattern, options: [.caseInsensitive]),
              let valueMatch = valueRegex.firstMatch(in: inputTag, range: NSRange(inputTag.startIndex..., in: inputTag)),
              let valueRange = Range(valueMatch.range(at: 1), in: inputTag) else {
            return nil
        }
        return String(inputTag[valueRange])
    }

    // 특정 id 속성을 가진 임의 태그 요소의 전체 블록(여는 태그부터 그 태그명의 첫 닫는 태그까지)을 반환.
    // 정규식 기반이라 동일 태그가 내부에 중첩된 경우는 정확히 균형을 맞추지 못한다(기존 blocks()와 동일한 한계).
    static func elementById(_ id: String, in html: String) -> String? {
        let openTagPattern = "<([a-zA-Z0-9]+)[^>]*\\bid=[\"']\(NSRegularExpression.escapedPattern(for: id))[\"'][^>]*>"

        guard let openRegex = try? NSRegularExpression(pattern: openTagPattern, options: [.caseInsensitive]),
              let openMatch = openRegex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let tagNameRange = Range(openMatch.range(at: 1), in: html),
              let openTagRange = Range(openMatch.range, in: html) else {
            return nil
        }
        let tagName = String(html[tagNameRange])
        let closeTag = "</\(tagName)>"

        guard let closeTagRange = html.range(of: closeTag,
                                              options: [.caseInsensitive],
                                              range: openTagRange.upperBound..<html.endIndex) else {
            return nil
        }
        return String(html[openTagRange.lowerBound..<closeTagRange.upperBound])
    }

    // 특정 id를 가진 임의 태그의 "여는 태그 문자열 자체"만 반환한다. elementById와 달리 닫는 태그를
    // 요구하지 않으므로 <img id="photo" src="..."> 같은 self-closing/void 요소에도 쓸 수 있다
    // (Task 7: myinfo_update_photo.acl의 <img id="photo">에서 src 속성을 읽기 위해 추가된 HtmlUtil 확장).
    static func openTag(withId id: String, in html: String) -> String? {
        let pattern = "<[a-zA-Z0-9]+[^>]*\\bid=[\"']\(NSRegularExpression.escapedPattern(for: id))[\"'][^>]*>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range, in: html) else {
            return nil
        }
        return String(html[range])
    }

    // 태그 문자열(예: "<a href='x' class='y'>") 내에서 특정 속성의 값을 반환
    static func attribute(_ name: String, in tag: String) -> String? {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: name))=[\"']([^\"']*)[\"']"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let range = Range(match.range(at: 1), in: tag) else {
            return nil
        }
        return String(tag[range])
    }

    // attribute(_:in:)는 여는/닫는 따옴표가 서로 다른 종류(큰따옴표든 작은따옴표든 먼저 나오는 쪽)와
    // 매칭되므로, 속성값 내부에 반대 종류의 따옴표가 섞여 있으면(예: onclick="javascript:fn('a','b')"
    // — 큰따옴표 HTML 속성 안에 작은따옴표 JS 문자열 인자가 중첩) 첫 내부 따옴표에서 잘려버린다
    // (Task 10 리뷰에서 발견 — group_grid onclick 파싱이 전부 빈 목록으로 강등되는 원인이었다).
    // 이 함수는 여는 따옴표 종류를 캡처해 백레퍼런스로 같은 종류의 닫는 따옴표까지만 값으로 삼는다.
    static func attributeExact(_ name: String, in tag: String) -> String? {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: name))=([\"'])((?:(?!\\1).)*)\\1"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: tag, range: NSRange(tag.startIndex..., in: tag)),
              let range = Range(match.range(at: 2), in: tag) else {
            return nil
        }
        return String(tag[range])
    }

    // html 내의 모든 <a href="...">텍스트</a> 쌍을 (href, 태그 제거된 텍스트)로 반환
    static func links(in html: String) -> [(href: String, text: String)] {
        let pattern = "<a\\b[^>]*href=[\"']([^\"']*)[\"'][^>]*>(.*?)</a>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        return matches.compactMap { match -> (href: String, text: String)? in
            guard let hrefRange = Range(match.range(at: 1), in: html),
                  let innerRange = Range(match.range(at: 2), in: html) else {
                return nil
            }
            return (href: String(html[hrefRange]), text: text(String(html[innerRange])))
        }
    }

    // 태그 제거 + 기본 엔티티 디코딩
    static func text(_ html: String) -> String {
        var result = html.replacingOccurrences(of: "<br[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])

        // 따옴표로 감싼 속성값 안의 '>'(예: 경북대 공지 목록 href의 "/>")에서 태그가 끊겨
        // URL 조각이 본문으로 노출되지 않도록 속성 인식형 패턴으로 태그 제거
        result = result.replacingOccurrences(of: "<[^>\"']*(?:\"[^\"]*\"[^>\"']*|'[^']*'[^>\"']*)*>", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&nbsp;", with: " ")
        result = result.replacingOccurrences(of: "&lt;", with: "<")
        result = result.replacingOccurrences(of: "&gt;", with: ">")
        result = result.replacingOccurrences(of: "&amp;", with: "&")
        result = result.replacingOccurrences(of: "&quot;", with: "\"")
        result = result.replacingOccurrences(of: "&#39;", with: "'")
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func blocks(in html: String, tag: String) -> [String] {
        let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return []
        }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: html) else {
                return nil
            }
            return String(html[range])
        }
    }
}
