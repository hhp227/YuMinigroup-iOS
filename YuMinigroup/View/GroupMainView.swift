//
//  GroupMainView.swift
//  YuMinigroup
//
//  Android fragment_group_main.xml + GroupMainFragment 대응 — AppToolbar(메인화면, 햄버거가 드로어를 연다)
//  바로 아래 3버튼 바(Android BottomNavigationView가 실제로는 툴바 바로 밑, 그리드 위에 배치되는 것과
//  동일한 위치 — 이름과 달리 화면 맨 아래가 아니다), 그 아래 2열 그리드. Android의 광고/인기그룹
//  캐러셀/헤더 행(GroupGridAdapter)은 범위 밖이라 이식하지 않는다.
//
//  그룹 셀 탭은 Task 11(GroupView)로 이어진다 — NavigationLink destination을
//  PlaceholderView(title: 그룹 이름)에서 GroupView(groupItem: group)로 교체했다. 하단 3버튼은
//  여전히 PlaceholderView를 push한다(그룹찾기/가입신청중 그룹/그룹 만들기는 각각 Task 12/13/14 몫).
//
//  NavigationLink를 쓰려면 NavigationView 조상이 필요한데(iOS 15.6 타깃, NavigationStack 미사용),
//  MainView/DrawerScaffold 트리에는 NavigationView가 없으므로 이 화면 자체에 로컬 NavigationView를
//  둔다. 루트 화면은 AppToolbar가 대신하므로 시스템 네비게이션 바는 navigationBarHiddenCompat()로
//  숨긴다 — 다만 push된 화면(PlaceholderView·GroupView) 쪽은 자체적으로 숨기지 않으므로 시스템
//  백 버튼이 자연스럽게 나타난다(GroupView는 그 백 버튼 위에 CollapsingListScaffold 전용 배경/틴트
//  색만 얹는다 — task-11-report.md 참고).
//

import SwiftUI

struct GroupMainView: View {
    @StateObject private var viewModel = GroupMainViewModel()

    let onMenuClick: () -> Void

    private static let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppToolbar(title: "메인화면", navigationIcon: .menu, onNavigationClick: onMenuClick)

                bottomButtonBar

                ZStack {
                    ScrollView {
                        if viewModel.state.groups.isEmpty && !viewModel.state.isLoading {
                            emptyBanner
                        } else {
                            LazyVGrid(columns: GroupMainView.columns, spacing: 14) {
                                ForEach(viewModel.state.groups) { group in
                                    NavigationLink(destination: GroupView(groupItem: group)) {
                                        GroupGridCell(group: group)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(14)
                        }
                    }
                    .refreshable {
                        viewModel.fetchGroups()
                    }

                    if viewModel.state.isLoading && viewModel.state.groups.isEmpty {
                        ProgressView()
                    }
                }
            }
            .navigationBarHiddenCompat()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .toast(message: $viewModel.state.message)
    }

    // Android BottomNavigationView(navigation_find/navigation_request/navigation_create) 대응.
    private var bottomButtonBar: some View {
        HStack(spacing: 0) {
            bottomButton(title: "그룹찾기", systemImage: "magnifyingglass")
            bottomButton(title: "가입신청중 그룹", systemImage: "person.3.fill")
            bottomButton(title: "그룹 만들기", systemImage: "plus.circle")
        }
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private func bottomButton(title: String, systemImage: String) -> some View {
        NavigationLink(destination: PlaceholderView(title: title, onMenuClick: onMenuClick)) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var emptyBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("가입한 그룹이 없습니다")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

private struct GroupGridCell: View {
    let group: GroupItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RemoteImage(urlString: group.image)
                .aspectRatio(contentMode: .fill)
                .frame(height: 100)
                .clipped()

            Text(group.name)
                .font(.system(size: 15))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3))
                .lineLimit(1)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }
}
