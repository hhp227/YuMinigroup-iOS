//
//  Tab1View.swift
//  YuMinigroup
//
//  Android fragment/Tab1Fragment(fragment_tab1.xml) 대응 — 소식 탭 실제 화면. GroupView가 소유한
//  Tab1ViewModel을 주입받아(@ObservedObject — 이 뷰는 만들지 않으므로 @StateObject가 아니다)
//  RefreshableLazyColumn(Task 2 킷, items:[String]) 위에 얹는다. GroupView의 다른 3탭은 여전히
//  GroupTabPlaceholder라 이 화면 하나만 headerHeight/isActive/scrollOffset 계약을 실제로 채운다.
//
//  RefreshableLazyColumn은 items를 [String]으로만 받으므로 게시글 id 배열을 넘기고, 행 클로저 안에서
//  articlesById 딕셔너리로 실제 ArticleItem을 되찾는다(그 자체 계약이라 수정할 수 없음 — Task 2/브리프
//  "do NOT modify" 대상).
//
//  ⚠️ RefreshableLazyColumn.refreshable{}의 실제 본문은 이 킷이 이식된 원본 데모(ParallaxTabLayout
//  FirstTabScreen/FirstTabViewModel) 그대로 "isRefreshEnabled 확인 후 1초 대기"뿐이고, 실제로 어떤
//  콜백도 호출하지 않는다(내부 @State isRefreshing만 토글) — 즉 당겨서 새로고침 제스처가 시스템
//  스피너는 보여주지만 Tab1ViewModel.refresh()를 실제로 트리거하지는 못한다. 이 파일에서 수정 가능한
//  범위가 아니라(브리프의 "do NOT modify" 목록) 고치지 않았다: 첫 로드는 Tab1ViewModel.init이 이미
//  스스로 fetchNextPage()를 실행하므로 정상 동작하고, refresh()/upsert() 자체는 Task 16/17이 작성·수정
//  화면에서 돌아올 때 호출할 수 있도록 완전히 구현해 두었다 — 다만 "손가락으로 당기면 실제로 새로고침
//  된다"는 체감 동작은 이 킷이 확장되기 전까진 없다. 자세한 근거는 task-12-report.md 참고.
//
//  빈 상태 "글쓰기" 블록은 Android onEmptyViewClick(CreateArticleActivity 실행) 대응이지만, GroupView의
//  FAB과 동일한 이유로 지금은 no-op이다(Task 17까지 CreateArticleView가 없어 참조할 수 없음).
//

import SwiftUI

struct Tab1View: View {
    @ObservedObject var viewModel: Tab1ViewModel
    let headerHeight: CGFloat
    let appBarState: CollapsingAppBarState
    let isActive: Bool
    @Binding var scrollOffset: CGFloat

    // uniqueKeysWithValues는 중복 id에서 fatalError로 트랩된다 — 페이지 경계에서 같은 글이 겹쳐 들어오는
    // 경우(이론상 stopRequestMore가 걸리기 전 한 응답 안에서는 없지만, 서로 다른 두 응답이 겹칠 가능성은
    // 배제할 수 없다)에도 크래시하지 않도록 첫 번째 값을 유지하는 안전한 생성자를 쓴다.
    private var articlesById: [String: ArticleItem] {
        Dictionary(viewModel.state.articles.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    var body: some View {
        ZStack {
            RefreshableLazyColumn(
                items: viewModel.state.articles.map { $0.id },
                headerHeight: headerHeight,
                isRefreshEnabled: appBarState.isExpanded,
                isScrollTrackingEnabled: isActive
            ) { articleId in
                row(for: articleId)
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) {
                if isActive && !$0.isNaN {
                    scrollOffset = $0
                }
            }

            if viewModel.state.articles.isEmpty {
                if viewModel.state.isLoading {
                    ProgressView()
                        .padding(.top, headerHeight + 60)
                } else {
                    emptyState
                        .padding(.top, headerHeight + 60)
                }
            }
        }
        .toast(message: $viewModel.state.message)
    }

    @ViewBuilder
    private func row(for articleId: String) -> some View {
        if let article = articlesById[articleId] {
            NavigationLink(destination: ArticleView(
                article: article,
                groupId: viewModel.groupId,
                groupKey: viewModel.groupKey,
                onDeleted: { viewModel.remove(article: $0) },
                onUpdated: { viewModel.upsert($0) }
            )) {
                ArticleListCell(article: article)
            }
            .buttonStyle(.plain)
            .onAppear {
                if !viewModel.state.endReached, articleId == viewModel.state.articles.last?.id {
                    viewModel.loadMore()
                }
            }

            Divider()
        }
    }

    // Android empty_layout("글쓰기") 대응.
    private var emptyState: some View {
        Button(action: {}) {
            VStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text("글쓰기")
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
