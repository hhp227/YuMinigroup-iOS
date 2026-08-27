//
//  GroupMainView.swift
//  YuMinigroup
//
//  Android fragment_group_main.xml + GroupMainFragment 대응 — AppToolbar(메인화면, 햄버거가 드로어를 연다)
//  바로 아래 3버튼 바(Android BottomNavigationView가 실제로는 툴바 바로 밑, 그리드 위에 배치되는 것과
//  동일한 위치 — 이름과 달리 화면 맨 아래가 아니다), 그 아래 2열 그리드. Android의 광고/인기그룹
//  캐러셀/헤더 행(GroupGridAdapter)은 범위 밖이라 이식하지 않는다.
//
//  그룹 셀 탭은 Task 11(GroupView)로 이어진다 — NavigationLink destination을 그룹 이름을 받던
//  플레이스홀더 화면에서 GroupView(groupItem: group)로 교체했다. 하단 3버튼은 Task 4(2차)에서
//  "그룹찾기"/"가입신청중 그룹"이 FindGroupView/RequestView로, Task 6(2차)에서 "그룹 만들기"가
//  CreateGroupView로 교체됐다 — bottomButton을 제네릭 destination 클로저로 바꿔 버튼마다 다른 화면을
//  push한다.
//
//  NavigationLink를 쓰려면 NavigationView 조상이 필요한데(iOS 15.6 타깃, NavigationStack 미사용),
//  MainView/DrawerScaffold 트리에는 NavigationView가 없으므로 이 화면 자체에 로컬 NavigationView를
//  둔다. 루트 화면은 AppToolbar가 대신하므로 시스템 네비게이션 바는 navigationBarHiddenCompat()로
//  숨긴다 — 다만 push된 화면(PlaceholderView·GroupView) 쪽은 자체적으로 숨기지 않으므로 시스템
//  백 버튼이 자연스럽게 나타난다(GroupView는 그 백 버튼 위에 CollapsingListScaffold 전용 배경/틴트
//  색만 얹는다 — task-11-report.md 참고).
//
//  Task 6: 그룹 생성 성공 시 CreateGroupView는 자기 자신을 dismiss(pop)한 뒤 onCreated(group)만
//  부른다(그 화면은 GroupMain의 내부 상태를 모른다) — 새 그룹 GroupView로의 push는 여기
//  handleCreated가 담당한다. pop과 push를 같은 프레임에서 연달아 실행하면 두 네비게이션 애니메이션이
//  경합해 화면이 깨지므로(Android는 CreateGroupActivity.finish() 직후 GroupActivity를 여는 것이라
//  이 문제가 없다 — Activity 전환은 애니메이션이 서로 안 겹친다), pop 애니메이션(표준 0.35초 내외)이
//  끝날 시간을 벌어준 뒤 push한다. NavigationLink(isActive:)로 숨김 링크를 하나 두고
//  createdGroup/isCreatedGroupActive를 이 화면이 들고 있다가 지연 후 활성화하는 방식이다.
//

import SwiftUI

struct GroupMainView: View {
    @StateObject private var viewModel = GroupMainViewModel()

    let onMenuClick: () -> Void

    @State private var createdGroup: GroupItem?
    @State private var isCreatedGroupActive = false

    private static let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationView {
            ZStack {
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

                // 그룹 생성 직후 새 그룹 GroupView로 이동하는 숨김 링크(헤더 코멘트 참고).
                NavigationLink(isActive: $isCreatedGroupActive) {
                    if let createdGroup = createdGroup {
                        GroupView(groupItem: createdGroup)
                    }
                } label: {
                    EmptyView()
                }
                .hidden()
            }
            .navigationBarHiddenCompat()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .toast(message: $viewModel.state.message)
    }

    // CreateGroupView.onCreated 콜백 — 목록 새로고침 + 지연 후 새 그룹 화면 push(헤더 코멘트 참고).
    private func handleCreated(_ group: GroupItem) {
        viewModel.fetchGroups()
        createdGroup = group
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isCreatedGroupActive = true
        }
    }

    // Android BottomNavigationView(navigation_find/navigation_request/navigation_create) 대응.
    private var bottomButtonBar: some View {
        HStack(spacing: 0) {
            bottomButton(title: "그룹찾기", systemImage: "magnifyingglass") {
                FindGroupView(onJoined: viewModel.fetchGroups)
            }
            bottomButton(title: "가입신청중 그룹", systemImage: "person.3.fill") {
                RequestView()
            }
            bottomButton(title: "그룹 만들기", systemImage: "plus.circle") {
                CreateGroupView(onCreated: handleCreated)
            }
        }
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // destination을 제네릭 클로저로 받아 버튼마다 다른 화면을 push한다(브리프 Step4 시그니처).
    private func bottomButton<Destination: View>(title: String, systemImage: String,
                                                  @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination()) {
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

    // Android 빈 상태 페이저(b_find/b_create) 대응 — 그룹 찾기/그룹 생성으로 바로 이어지는 버튼 2개.
    private var emptyBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            Text("가입한 그룹이 없습니다")
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                NavigationLink(destination: FindGroupView(onJoined: viewModel.fetchGroups)) {
                    Text("그룹 찾기")
                }
                .buttonStyle(.borderedProminent)

                NavigationLink(destination: CreateGroupView(onCreated: handleCreated)) {
                    Text("그룹 생성")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 4)
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
