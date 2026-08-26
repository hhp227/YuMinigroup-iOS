//
//  DrawerScaffold.swift
//  YuMinigroup
//
//  ParallaxTabLayout iOS 키트(UI/DrawerScaffold.swift) 포팅분(Task 2) — 원본은 샘플 전용 라우트 열거형
//  (.first/.second 두 케이스)과 "FirstFragment"/"SecondFragment" 하드코딩 메뉴 2행 전용이었다.
//  Task 9(MainView)에서 실제 라우트 6행(메인화면/영대소식/시간표/도서관 좌석/순환버스/로그아웃)을
//  붙이며 CollapsingHeader(Task 2, tabTitles: [String] 주입)와 같은 방식으로 일반화한다: 라우트 타입에
//  대한 의존을 완전히 제거하고, 헤더는 뷰 빌더로, 메뉴 항목은 DrawerMenuItem 배열로 주입받는다.
//  DrawerScaffold는 슬라이드 애니메이션/스크림 탭-닫힘/선택 강조/항목 클릭 시 드로어 닫힘이라는
//  "셸" 책임만 지고, 헤더 내용과 메뉴 항목의 의미(라우트 vs 액션)는 전부 호출부(MainView)가 정한다.
//

import SwiftUI

struct DrawerMenuItem: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let isSelected: Bool
    let onSelect: () -> Void
}

struct DrawerScaffold<Header: View, Content: View>: View {
    let menuItems: [DrawerMenuItem]
    let header: () -> Header
    let content: (_ openDrawer: @escaping () -> Void) -> Content

    @State private var isDrawerOpen = false

    var body: some View {
        ZStack(alignment: .leading) {
            content { withAnimation(.easeOut) { isDrawerOpen = true } }
                .disabled(isDrawerOpen)

            if isDrawerOpen {
                Color.black.opacity(0.32)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut) { isDrawerOpen = false } }

                VStack(alignment: .leading, spacing: 0) {
                    header()
                    ForEach(menuItems) { item in
                        DrawerItem(
                            title: item.title,
                            systemImage: item.systemImage,
                            isSelected: item.isSelected,
                            onClick: {
                                item.onSelect()
                                withAnimation(.easeOut) { isDrawerOpen = false }
                            }
                        )
                    }
                    Spacer()
                }
                .frame(width: 304)
                .background(Color(uiColor: .systemBackground))
                .transition(.move(edge: .leading))
            }
        }
    }
}

private struct DrawerItem: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            HStack {
                Image(systemName: systemImage)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
