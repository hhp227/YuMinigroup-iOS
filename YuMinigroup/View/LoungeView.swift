//
//  LoungeView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/13.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct LoungeView: View {
    @State
    var isNavigateToCreatePostView = false
    
    @StateObject
    var viewModel: LoungeViewModel = InjectorUtils.instance.provideLoungeViewModel()
    
    private var fab: some View {
        Button(action: { isNavigateToCreatePostView.toggle() }) {
            Text("+")
                .font(.system(.largeTitle))
                .frame(width: 66, height: 60)
                .foregroundColor(.white)
                .padding(.bottom, 7)
        }
        .background(Color.blue)
        .cornerRadius(38.5)
        .padding()
        .shadow(color: Color.black.opacity(0.3), radius: 3, x: 3, y: 3)
    }
    
    var body: some View {
        ZStack {
            PostList(
                isNavigateToCreatePostView: $isNavigateToCreatePostView,
                lazyPagingItems: viewModel.$state.map { $0.pagingData }.collectAsLazyPagingItems(),
                onLikeClick: viewModel.togglePostLike,
                onResult: viewModel.onDeletePost,
                refreshCallback: viewModel.refresh
            )
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    fab
                }
            }
        }
    }
}

struct PostList: View {
    @State
    private var headerVisibleRatio: CGFloat = 1

    @State
    private var scrollOffset: CGPoint = .zero
    
    @Binding
    var isNavigateToCreatePostView: Bool
    
    @StateObject
    var lazyPagingItems: LazyPagingItems<PostItem>
    
    let onLikeClick: (PostItem) -> Void
    
    let onResult: (PostItem) -> Void
    
    let refreshCallback: () -> Void
    
    var body: some View {
        CollapsingNavigationBarView(
            headerHeight: 250,
            onScroll: handleScrollOffset,
            header: header
        ) {
            LazyVStack(spacing: 10) {
                Button(action: lazyPagingItems.refresh, label: { Text("Refresh") })
                ForEach(lazyPagingItems) { $post in
                    PostListCell(post: $post, onLikeClick: { onLikeClick(post) }, onResult: onResult)
                }
                HStack {
                    if lazyPagingItems.loadState.refresh is LoadState.Loading {
                        ProgressView()
                    } else if lazyPagingItems.loadState.append is LoadState.Loading {
                        ProgressView()
                    } else if lazyPagingItems.loadState.refresh is LoadState.Error {
                        
                    } else if lazyPagingItems.loadState.append is LoadState.Error {
                        
                    }
                }
            }
        }
        .navigationDestination(isPresented: $isNavigateToCreatePostView) {
            CreatePostView(
                viewModel: InjectorUtils.instance.provideCreatePostViewModel(type: 0, groupId: 0),
                onResult: refresh
            )
        }
    }
    
    func header() -> some View {
        ZStack(alignment: .bottomLeading) {
            // headerView
            ZStack {
                Color.red
                //ScrollViewHeaderImage(image: Image("header"))
                //ScrollViewHeaderGradient(.black.opacity(0.2), .black.opacity(0.5))
            }
            //ScrollViewHeaderGradient()
            //headerTitle.previewHeaderContent()
        }
    }
    
    func handleScrollOffset(_ offset: CGPoint, headerVisibleRatio: CGFloat) {
        self.scrollOffset = offset
        self.headerVisibleRatio = headerVisibleRatio
    }
    
    func refresh() {
        lazyPagingItems.refresh()
        refreshCallback()
    }
}

struct LoungeView_Previews: PreviewProvider {
    static var previews: some View {
        LoungeView()
    }
}
