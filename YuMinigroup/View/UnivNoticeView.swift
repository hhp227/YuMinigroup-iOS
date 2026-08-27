//
//  UnivNoticeView.swift
//  YuMinigroup
//
//  Android fragment.UnivNoticeFragment(FragmentListBinding+BbsListAdapter) 대응 — 드로어 "영대소식"
//  루트 화면(스펙 §4.1). ChatListView 관례(로컬 NavigationView + AppToolbar(.menu) +
//  navigationBarHiddenCompat)를 그대로 따른다 — 상세를 WebViewScreen push로 열어야 해서 이 화면
//  자신이 NavigationView 조상을 둬야 한다(MainContentRouter 트리에는 NavigationView가 없음, Task 1
//  WebViewScreen 헤더 코멘트 참고).
//
//  첫 로딩만 중앙 스피너(isLoading && items.isEmpty) — FindGroupView와 달리 스켈레톤이 없는 화면이라
//  hasRequestMore를 스피너 판정에 쓰지 않는다(브리프 지시). 마지막 셀 onAppear에서 fetchNextPage()를
//  부른다 — offset<100/isLoading/isEndReached 가드는 VM(UnivNoticeViewModel.fetchNextPage)이 전담하고,
//  여기서는 GroupListContent와 동일하게 !isEndReached만 한 번 더 확인해 불필요한 호출을 줄인다.
//

import SwiftUI

struct UnivNoticeView: View {
    @StateObject private var viewModel = UnivNoticeViewModel()

    let onMenuClick: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppToolbar(title: "영대소식", navigationIcon: .menu, onNavigationClick: onMenuClick)

                ZStack {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.state.items) { item in
                                NavigationLink(destination: WebViewScreen(urlString: EndPoint.yuNoticeView(articleNo: item.id), title: "영대소식")) {
                                    BbsItemCell(item: item)
                                }
                                .buttonStyle(.plain)
                                .onAppear {
                                    if !viewModel.state.isEndReached && item.id == viewModel.state.items.last?.id {
                                        viewModel.fetchNextPage()
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        viewModel.refresh()
                    }

                    if viewModel.state.isLoading && viewModel.state.items.isEmpty {
                        ProgressView()
                    }
                }
            }
            .navigationBarHiddenCompat()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .toast(message: $viewModel.state.message)
    }
}

// Android res/layout/bbs_item.xml(CardView) 대응 — 제목 17pt singleLine / 아래 날짜 15pt + 우측
// 작성자 10pt. GroupMainView.GroupGridCell과 동일한 카드 스타일(배경+cornerRadius 4+shadow)을 쓴다.
private struct BbsItemCell: View {
    let item: BbsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.system(size: 17))
                .lineLimit(1)
                .foregroundColorCompat(.primary)

            HStack {
                Text(item.date)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                Spacer()

                Text(item.writer)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}
