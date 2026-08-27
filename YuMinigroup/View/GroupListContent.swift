//
//  GroupListContent.swift
//  YuMinigroup
//
//  Android res/layout/activity_list.xml(+group_list_item.xml) 대응 — FindGroupView/RequestView가
//  공유하는 목록 본문(RequestView 자체는 Task 3 범위 밖이라 이 컴포넌트만 지금 만든다). Android는
//  ShimmerFrameLayout(스켈레톤)/SwipeRefreshLayout+RecyclerView/빈 상태 RelativeLayout 세 뷰를
//  visibility로 토글하는데, 여기서는 순수 함수형 뷰로 옮겨 isInitialLoading으로 스켈레톤과 실제
//  목록을 완전히 분기한다.
//
//  isInitialLoading은 이 뷰가 계산하지 않는다 — 호출부(FindGroupView)가
//  "state.isLoading && !state.hasRequestMore"로 계산해 내려준다(Android의
//  "isLoading() && !hasRequestMore()" 셔터 바인딩 그대로).
//
//  Android group_list_item.xml/FindGroupActivity는 RecyclerView에 별도 ItemDecoration(구분선)을
//  달지 않으므로, 여기서도 셀 사이에 Divider를 넣지 않는다(각 셀의 150×100 이미지 + 10pt 안쪽
//  여백만으로 시각적으로 구분된다).
//
//  페이징은 1차 Tab3View 관례(마지막 셀 onAppear에서 loadMore, isEndReached면 재호출하지 않음)를
//  그대로 따른다. 새로고침은 SwipeRefreshLayout 대신 시스템 .refreshable(iOS 15+)을 쓴다.
//

import SwiftUI

struct GroupListContent: View {
    let items: [GroupItem]
    let isInitialLoading: Bool
    let hasRequestMore: Bool
    let isEndReached: Bool
    let emptyMessage: String
    let onItemTap: (GroupItem) -> Void
    let onLoadMore: () -> Void
    let onRefresh: () -> Void

    private static let skeletonRowCount = 7

    var body: some View {
        Group {
            if isInitialLoading {
                skeletonList
            } else {
                ZStack {
                    listScrollView

                    // 개선 4(빈 상태 UI) — Android는 이 화면에 빈 상태 문구를 그리지 않는다.
                    if items.isEmpty {
                        Text(emptyMessage)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var listScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    Button(action: { onItemTap(item) }) {
                        GroupListCell(item: item)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if !isEndReached && item.id == items.last?.id {
                            onLoadMore()
                        }
                    }
                }

                if hasRequestMore && !isEndReached {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
        }
        .refreshable {
            onRefresh()
        }
    }

    // Android ShimmerFrameLayout(7×group_list_placeholder_item) 대응.
    private var skeletonList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(0..<GroupListContent.skeletonRowCount, id: \.self) { _ in
                    skeletonRow
                }
            }
        }
        .redacted(reason: .placeholder)
    }

    private var skeletonRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 150, height: 100)

            VStack(alignment: .leading, spacing: 6) {
                Text("가나다라마바사 그룹 이름")
                    .font(.system(size: 16))
                    .lineLimit(2)

                Text("가입방식: 자동 승인")
                    .font(.system(size: 13))
            }
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(10)
    }
}

// Android group_list_item.xml 대응(tv_info 없음 — 목록 셀에는 회원수 등 info 필드를 그리지 않는다,
// GroupInfoDialogView에서만 표시).
private struct GroupListCell: View {
    let item: GroupItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteImage(urlString: item.image)
                .aspectRatio(contentMode: .fill)
                .frame(width: 150, height: 100)
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 16))
                    .lineLimit(2)
                    .foregroundColorCompat(.primary)

                // Task 1 이연 방어: menu_list 스코프를 못 찾아 joinType이 nil이면 Android 삼항식과
                // 동일하게 "운영자 승인 확인" 쪽(더 안전한 기본값)으로 표시한다.
                Text(item.joinType == "0" ? "가입방식: 자동 승인" : "가입방식: 운영자 승인 확인")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 10)

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
