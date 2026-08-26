//
//  Tab2View.swift
//  YuMinigroup
//
//  Android fragment/Tab2Fragment(fragment_tab2.xml + header_calendar.xml + schedule_item.xml) 대응 —
//  일정 탭 실제 화면. Tab1View와 같은 탭 바디 계약(viewModel:headerHeight:appBarState:isActive:
//  scrollOffset:)을 채우지만, appBarState는 쓰지 않는다(RefreshableLazyColumn 전용 계약이라
//  Tab1View만 실제로 소비 — 브리프가 명시한 대로 무시 가능한 파라미터).
//
//  Android의 header_calendar.xml + ExtendedCalendarView는 순수 월 그리드(날짜 선택용, 일정 유무
//  표시 없음)였고 아래 RecyclerView에 헤더(캘린더) + schedule_item을 한 어댑터로 얹는 구조였다.
//  여기서는 헤더/아이템을 하나의 ScrollView 안에 SwiftUI로 재구성하고, 그리드의 날짜 밑점(해당
//  월 일정 유무 표시)은 Android에 없던 자체 구현이다(브리프 "자체 구현" 지시).
//
//  월 그리드는 일요일 시작(Android ExtendedCalendarView의 CalendarAdapter도 Calendar.DAY_OF_WEEK
//  1=일요일 기준)으로 7열 LazyVGrid를 구성하고, 요일 헤더 7개 뒤에 이어 붙여 첫 줄이 자연히
//  요일 헤더가 되도록 한다.
//

import SwiftUI

struct Tab2View: View {
    @ObservedObject var viewModel: Tab2ViewModel
    let headerHeight: CGFloat
    let appBarState: CollapsingAppBarState
    let isActive: Bool
    @Binding var scrollOffset: CGFloat

    private let weekdaySymbols = ["일", "월", "화", "수", "목", "금", "토"]
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    // Tab2ViewModel과 동일 규칙(Asia/Seoul 고정) — 그리드 정렬/일정 유무 판정에 쓰인다.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)

        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }

    var body: some View {
        ScrollView {
            CollapsingHeaderSpacer(isScrollTrackingEnabled: isActive)

            VStack(alignment: .leading, spacing: 0) {
                calendarGrid
                Divider()
                scheduleList
            }
            .padding(.top, headerHeight)
        }
        .coordinateSpace(name: collapsingScrollCoordinateSpace)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) {
            if isActive && !$0.isNaN {
                scrollOffset = $0
            }
        }
        .toast(message: $viewModel.message)
    }

    // MARK: - Calendar grid (Android ExtendedCalendarView 대응, 일정 밑점은 자체 구현)

    private var calendarGrid: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: { viewModel.moveMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(DateUtil.format(viewModel.displayedMonth, pattern: "yyyy년 M월"))
                    .font(.headline)
                    .foregroundColorCompat(.primary)

                Spacer()

                Button(action: { viewModel.moveMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
            }
            .foregroundColorCompat(Color.accentColor)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(dayCells) { cell in
                    dayCellView(cell)
                }
            }

            if viewModel.isLoading {
                ProgressView()
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
    }

    private struct DayCell: Identifiable {
        let id: Int
        let day: Int?
    }

    private var dayCells: [DayCell] {
        guard let range = calendar.range(of: .day, in: .month, for: viewModel.displayedMonth) else {
            return []
        }
        let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: viewModel.displayedMonth)) ?? viewModel.displayedMonth
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) // 1=일 ... 7=토
        let leadingBlanks = firstWeekday - 1
        var cells = (0..<leadingBlanks).map { DayCell(id: -($0 + 1), day: nil) }

        cells.append(contentsOf: range.map { DayCell(id: $0, day: $0) })
        return cells
    }

    @ViewBuilder
    private func dayCellView(_ cell: DayCell) -> some View {
        if let day = cell.day {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.subheadline)
                Circle()
                    .fill(hasSchedule(onDay: day) ? Color.accentColor : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 32)
        } else {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 32)
        }
    }

    // viewModel.schedules는 이미 displayedMonth로 필터된 목록이므로, 그 목록만 기준으로 밑점을
    // 계산해 그리드-리스트 표시가 항상 일치하도록 한다(다른 달로 넘어간 기간 일정은 여기 밑점도
    // 찍지 않음 — Android의 시작월 필터와 같은 결과).
    private func hasSchedule(onDay day: Int) -> Bool {
        var components = calendar.dateComponents([.year, .month], from: viewModel.displayedMonth)

        components.day = day
        guard let dayDate = calendar.date(from: components) else {
            return false
        }
        return viewModel.schedules.contains { item in
            guard let endDate = item.endDate else {
                return calendar.isDate(dayDate, inSameDayAs: item.startDate)
            }
            let start = calendar.startOfDay(for: item.startDate)
            let end = calendar.startOfDay(for: endDate)

            return dayDate >= start && dayDate <= end
        }
    }

    // MARK: - Schedule list (Android schedule_item.xml 대응)

    @ViewBuilder
    private var scheduleList: some View {
        if viewModel.schedules.isEmpty {
            if !viewModel.isLoading {
                Text("이번 달 학사일정이 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
        } else {
            ForEach(viewModel.schedules) { item in
                scheduleRow(item)
                Divider()
            }
        }
    }

    private func scheduleRow(_ item: ScheduleItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(dateRangeText(item))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 96, alignment: .leading)

            Text(item.title)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
    }

    private func dateRangeText(_ item: ScheduleItem) -> String {
        let start = DateUtil.format(item.startDate, pattern: "MM.dd")

        guard let endDate = item.endDate else {
            return start
        }
        return "\(start) ~ \(DateUtil.format(endDate, pattern: "MM.dd"))"
    }
}
