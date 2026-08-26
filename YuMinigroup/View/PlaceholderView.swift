//
//  PlaceholderView.swift
//  YuMinigroup
//
//  Task 10 이후(그룹메인/영대소식/시간표/도서관 좌석/순환버스)가 실제 화면으로 교체되기 전까지,
//  MainView의 드로어 라우트가 공통으로 보여주는 자리표시 화면 — AppToolbar(햄버거 버튼이 드로어를 연다)
//  + 중앙 안내 문구.
//

import SwiftUI

struct PlaceholderView: View {
    let title: String
    let onMenuClick: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AppToolbar(title: title, navigationIcon: .menu, onNavigationClick: onMenuClick)

            Spacer()
            Text("준비중입니다")
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
