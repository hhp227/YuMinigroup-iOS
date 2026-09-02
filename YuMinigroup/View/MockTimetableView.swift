//
//  MockTimetableView.swift
//  YuMinigroup
//
//  Android fragment_mock_timetable.xml(카드 안 lay_time+lay_0..lay_9) + helper/ui/TimetableView.java
//  (setTimetable/submitList — 이식 기준) 대응. 그리드 상수(dayLine/timeLine 배열 verbatim, 색
//  #FAF4C0/#EAEAEA, 높이 화면/20·화면/14)는 Task 4 SemesterTimetableGrid와 같은 UIScreen.main.bounds
//  전례를 그대로 잇는다 — 다만 데이터 셀 배경은 학기시간표(#F1F1F1)와 달리 #EAEAEA(스펙 §4.2)라
//  이 화면 전용 색 상수로 별도 선언한다(공유 안 함).
//
//  id 산식(교시index×5+(요일index−1), 0~49)은 helper/ui/TimetableView.java의 이중 루프
//  (i=교시 0..9, j=요일 1..5, id는 0부터 순차 증가) 그대로: dayOffset(0~4) = j-1. 헤더 행만 dayLine
//  전체(6개, "시간" 포함)를 쓰고, 데이터 행은 시간 열(탭 불가) + 데이터 셀 5개(탭 가능)로 나눈다 —
//  Android도 시간/요일 헤더 셀에는 onClickListener를 붙이지 않고 데이터 셀에만 붙인다.
//
//  다이얼로그는 iOS 15가 .alert에 TextField 2개를 못 담아 GroupInfoDialogView 관례(부모가 ZStack +
//  딤 배경 + 중앙 카드로 직접 띄움, FindGroupView의 padding(.horizontal, 32) 그대로 재사용)를 따르는
//  커스텀 오버레이로 짠다. 상태는 editingCellId 하나만 두고, 다이얼로그가 프리필/버튼 구성을
//  viewModel.items[cellId]의 존재 여부로 스스로 판단한다(빈 셀=추가 폼, 채운 셀=수정/삭제 폼).
//
//  Android update_timetable_dig는 프리필된 EditText를 탭하면 텍스트를 지워주는 보조 동작
//  (putSubject/putClassroom.setOnClickListener → setText(null))이 있지만, 브리프·스펙 어디에도
//  요구되지 않고 iOS TextField는 표준 편집 제스처(탭+전체 선택/삭제)로 이미 같은 결과를 낼 수 있어
//  이식하지 않는다(범위 밖 UX 보조 동작, 결함이 아니라 생략 판단).
//

import SwiftUI

struct MockTimetableView: View {
    @ObservedObject var viewModel: MockTimetableViewModel

    @State private var editingCellId: Int?

    init(viewModel: MockTimetableViewModel) {
        self.viewModel = viewModel
    }

    private static let dayLine = ["시간", "월", "화", "수", "목", "금"]

    private static let timeLine = [
        "1교시\n09:00", "2교시\n10:00", "3교시\n11:00", "4교시\n12:00", "5교시\n13:00",
        "6교시\n14:00", "7교시\n15:00", "8교시\n16:00", "9교시\n17:00", "10교시\n18:00"
    ]

    private static let headerColor = Color(red: 0.980, green: 0.957, blue: 0.753) // #FAF4C0
    private static let cellColor = Color(red: 0.918, green: 0.918, blue: 0.918)   // #EAEAEA

    private var headerHeight: CGFloat {
        UIScreen.main.bounds.height / 20
    }

    private var dataHeight: CGFloat {
        UIScreen.main.bounds.height / 14
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    headerRow

                    ForEach(0..<MockTimetableView.timeLine.count, id: \.self) { timeIndex in
                        dataRow(timeIndex: timeIndex)
                    }
                }
            }

            if let cellId = editingCellId {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { editingCellId = nil }

                MockTimetableDialogView(
                    existingItem: viewModel.items[cellId],
                    onSave: { subject, classroom in
                        viewModel.save(id: cellId, subject: subject, classroom: classroom)
                        editingCellId = nil
                    },
                    onDelete: {
                        viewModel.delete(id: cellId)
                        editingCellId = nil
                    },
                    onCancel: { editingCellId = nil }
                )
                .padding(.horizontal, 32)
            }
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(MockTimetableView.dayLine, id: \.self) { day in
                cell(text: day, backgroundColor: MockTimetableView.headerColor, height: headerHeight)
            }
        }
    }

    private func dataRow(timeIndex: Int) -> some View {
        HStack(spacing: 0) {
            cell(text: MockTimetableView.timeLine[timeIndex], backgroundColor: MockTimetableView.cellColor, height: dataHeight)

            ForEach(0..<5, id: \.self) { dayOffset in
                dataCell(cellId: timeIndex * 5 + dayOffset)
            }
        }
    }

    // Android data[id].setOnClickListener(항상 부착, 빈 셀도 탭 가능) 대응 — 학기시간표 셀과 달리
    // 조건부 onTapGesture가 아니다.
    private func dataCell(cellId: Int) -> some View {
        let item = viewModel.items[cellId]
        let text = item.map { $0.subject + "\n" + $0.classroom } ?? ""

        return cell(text: text, backgroundColor: MockTimetableView.cellColor, height: dataHeight)
            .contentShape(Rectangle())
            .onTapGesture { editingCellId = cellId }
    }

    private func cell(text: String, backgroundColor: Color, height: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(backgroundColor)
            .padding(1)
    }
}

// Android res/layout/timetable_input_dig.xml(라벨 2개 + EditText 2개) + AlertDialog.Builder
// (add_timetable_dig/update_timetable_dig) 대응 — GroupInfoDialogView 관례의 중앙 카드 다이얼로그.
// existingItem이 nil이면 추가 폼(제목 "시간표", [저장|취소]), 있으면 수정 폼(제목 "TimeTable",
// 프리필 + [수정|삭제|취소])으로 스스로 분기한다.
private struct MockTimetableDialogView: View {
    let existingItem: TimetableItem?
    let onSave: (String, String) -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @State private var subject: String
    @State private var classroom: String

    init(existingItem: TimetableItem?, onSave: @escaping (String, String) -> Void, onDelete: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.existingItem = existingItem
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _subject = State(initialValue: existingItem?.subject ?? "")
        _classroom = State(initialValue: existingItem?.classroom ?? "")
    }

    private var isEditing: Bool {
        existingItem != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "TimeTable" : "시간표")
                .font(.system(size: 17, weight: .bold))
                .padding(.top, 20)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 12) {
                fieldRow(label: "강 의 명  :", text: $subject, placeholder: "강의명을 입력하세요.")
                fieldRow(label: "강 의 실  :", text: $classroom, placeholder: "강의실을 입력하세요.")
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Divider()

            actionBar
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(6)
    }

    private func fieldRow(label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 15))

            TextField(placeholder, text: text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }

    // UserDialogView/GroupInfoDialogView.actionBar 관례(HStack+Divider) 그대로. 빈 셀=[저장|취소],
    // 채운 셀=[수정|삭제|취소](브리프 "+취소" 지시).
    private var actionBar: some View {
        HStack(spacing: 0) {
            if isEditing {
                actionButton("수정") { onSave(subject, classroom) }
                Divider()
                actionButton("삭제", role: .destructive, action: onDelete)
                Divider()
                actionButton("취소", action: onCancel)
            } else {
                actionButton("저장") { onSave(subject, classroom) }
                Divider()
                actionButton("취소", action: onCancel)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func actionButton(_ title: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColorCompat(role == .destructive ? .red : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
    }
}
