//
//  CalendarXmlParser.swift
//  YuMinigroup
//
//  Android viewmodel.Tab2ViewModel.fetchDataTask의 DocumentBuilder 파싱 대응 — YU 학사일정 XML
//  (EndPoint.schedule 응답)을 파싱한다. 실측 응답 루트는 <YUdata>이고 그 아래 <Items> 엘리먼트가
//  반복되며, 각 <Items>는 <Subject>(제목)와 <Date>(날짜, 요일 괄호 포함 — 예: "2026-02-26(목)",
//  기간이면 "2026-03-30(월) ~ 2026-04-08(수)") 두 자식만 실제로 쓰인다. Android가 함께 조회하는
//  <Author>/<Text>/<Link>는 로그 출력 외 UI에 전혀 반영되지 않고(getParsing 결과를 Log.e에만 사용)
//  실측 응답에도 존재하지 않아 옮기지 않는다.
//
//  Android는 DOM(DocumentBuilderFactory)을 쓰지만 이 파일은 브리프 지시대로 XMLParser(SAX)로
//  포팅하고, 손상된 XML엔 크래시 대신 빈 배열을 돌려준다(parser(_:parseErrorOccurred:)는 에러를
//  삼키기만 하고, static parse(_:)가 XMLParser.parse()의 Bool 반환값으로 최종 성공/실패를 가른다).
//
//  Android 필터링(Tab2ViewModel.fetchDataTask)은 "date.substring(0,4)==year && date의 첫 '-' 다음
//  2글자==month"로 Date 문자열의 시작 연/월만 비교한다 — 기간 일정이라도 시작월에만 노출되는
//  Android 그대로의 동작이다(Tab2ViewModel.swift의 월 필터가 파싱된 startDate의 Calendar 컴포넌트
//  비교로 이를 그대로 미러한다). 요일 괄호 "(목)"는 날짜 파싱 전 버려도 되므로 앞 10글자
//  ("yyyy-MM-dd")만 취해 DateUtil로 파싱한다.
//

import Foundation

// Android Map<String,String>("date"/"content") 대응 — 시작일/종료일(기간 일정일 때만)/제목.
struct ScheduleItem: Identifiable, Hashable {
    let id = UUID()
    let startDate: Date
    let endDate: Date?
    let title: String
}

final class CalendarXmlParser: NSObject, XMLParserDelegate {
    static func parse(_ data: Data) -> [ScheduleItem] {
        let parser = CalendarXmlParser()
        let xmlParser = XMLParser(data: data)

        xmlParser.delegate = parser
        guard xmlParser.parse() else {
            return []
        }
        return parser.items
    }

    private var items: [ScheduleItem] = []
    private var currentText = ""
    private var currentSubject: String?
    private var currentDate: String?

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        if elementName == "Items" {
            currentSubject = nil
            currentDate = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "Subject":
            currentSubject = trimmed
        case "Date":
            currentDate = trimmed
        case "Items":
            if let subject = currentSubject, let dateString = currentDate, let item = Self.makeScheduleItem(title: subject, dateString: dateString) {
                items.append(item)
            }
        default:
            break
        }
    }

    // 손상된 XML(끊긴 태그 등)에도 크래시하지 않도록 에러만 삼킨다 — parse()가 false를 반환하면
    // static parse(_:)가 빈 배열로 처리한다.
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {}

    // MARK: - Parsing helpers

    private static func makeScheduleItem(title: String, dateString: String) -> ScheduleItem? {
        let parts = dateString.components(separatedBy: "~").map { $0.trimmingCharacters(in: .whitespaces) }

        guard let first = parts.first, let startDate = parseDate(first) else {
            return nil
        }
        let endDate = parts.count > 1 ? parseDate(parts[1]) : nil

        return ScheduleItem(startDate: startDate, endDate: endDate, title: title)
    }

    // "2026-02-26(목)" 같은 요일 괄호 포함 문자열에서 앞 10글자("yyyy-MM-dd")만 취해 DateUtil로 파싱한다.
    private static func parseDate(_ string: String) -> Date? {
        guard string.count >= 10 else {
            return nil
        }
        return DateUtil.timestamp(from: String(string.prefix(10)))
    }
}
