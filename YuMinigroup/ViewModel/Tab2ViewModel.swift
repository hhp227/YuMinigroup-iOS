//
//  Tab2ViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.Tab2ViewModel 대응 — 일정 탭(학사일정 캘린더)의 상태. 그룹 데이터가 아니라
//  YU 학사일정(EndPoint.schedule) 전역 XML을 그대로 보여준다는 점은 Android와 동일하다(GroupView가
//  넘겨주는 groupItem과 무관 — Tab1ViewModel과 달리 groupId/groupKey를 받지 않는다).
//
//  Android는 Calendar LiveData가 바뀔 때마다(최초 emit 포함, Tab2Fragment.observeViewModelData()의
//  getCalendar().observe { fetchDataTask }) 서버 XML을 매번 새로 내려받아 그 달로 필터링한다
//  (EndPoint.schedule은 연/월 파라미터를 받지 않고 학기 전체 XML을 통째로 돌려주므로, 매번 같은
//  응답을 다시 받아 필터링만 새로 하는 셈이다) — 이 VM도 moveMonth마다 fetch()를 다시 호출해 그
//  재요청 패턴을 그대로 미러한다(클라이언트 캐싱으로 최적화하지 않음).
//
//  월 필터는 CalendarXmlParser 헤더 코멘트에 적은 대로 Android의 "Date 문자열 시작 연/월만 비교"를
//  파싱된 startDate의 Calendar 컴포넌트 비교로 옮긴 것 — 기간 일정(startDate~endDate)도 시작월에만
//  노출되는 동작까지 그대로다. Asia/Seoul로 타임존을 고정하는 이유는 학사일정이 서버(학교) 로컬
//  기준이라 기기 타임존과 무관하게 월 경계가 어긋나지 않아야 하기 때문이다.
//

import Foundation

final class Tab2ViewModel: ObservableObject {
    @Published var displayedMonth: Date
    @Published var schedules: [ScheduleItem] = []
    @Published var isLoading = false
    @Published var message: String?

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()

    init() {
        displayedMonth = Tab2ViewModel.startOfMonth(Date(), calendar: calendar)
        fetch()
    }

    // Android Tab2Fragment.observeViewModelData()의 getCalendar().observe { fetchDataTask } 대응.
    func fetch() {
        let targetMonth = displayedMonth

        isLoading = true
        HttpClient.request(EndPoint.schedule) { [weak self] result in
            guard let self = self else {
                return
            }
            self.isLoading = false
            switch result {
            case .success(let body):
                guard let data = body.data(using: .utf8) else {
                    self.schedules = []
                    return
                }
                let parsed = CalendarXmlParser.parse(data)

                // 응답이 도착하기 전 사용자가 이미 다른 달로 넘어갔다면(연타) 그 사이 결과는 버린다.
                guard self.calendar.isDate(self.displayedMonth, equalTo: targetMonth, toGranularity: .month) else {
                    return
                }
                self.schedules = self.filter(parsed, for: targetMonth)
            case .failure(let error):
                self.message = error.localizedDescription
            }
        }
    }

    // Android Tab2ViewModel.previousMonth/nextMonth(연도 경계에서 12↔1월로 넘어가는 분기 포함) 대응 —
    // Calendar.date(byAdding:)가 그 분기를 흡수한다.
    func moveMonth(by delta: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else {
            return
        }
        displayedMonth = Tab2ViewModel.startOfMonth(newMonth, calendar: calendar)
        fetch()
    }

    // Android "date.substring(0,4)==year && date 첫 '-' 다음 2글자==month"를 startDate의 연/월
    // 비교로 옮김(CalendarXmlParser 헤더 코멘트 참고).
    private func filter(_ items: [ScheduleItem], for month: Date) -> [ScheduleItem] {
        items.filter { calendar.isDate($0.startDate, equalTo: month, toGranularity: .month) }
    }

    private static func startOfMonth(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)

        return calendar.date(from: components) ?? date
    }
}
