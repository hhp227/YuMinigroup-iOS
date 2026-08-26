//
//  PostListCell.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/05/11.
//  Copyright © 2022 홍희표. All rights reserved.
//

import SwiftUI

struct PostListCell: View {
    @State
    private var isNavigate = false
    
    @Binding
    var post: PostItem
    
    let onLikeClick: () -> Void
    
    let onResult: (PostItem) -> Void
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: { isNavigate.toggle() }) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .top) {
                            AsyncImage(url: URL(string: URL_USER_PROFILE_IMAGE + (post.profileImage ?? ""))!) { result in
                                switch result {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                case .failure:
                                    Image(systemName: "photo")
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .frame(width: 55, height: 55)
                            .cornerRadius(45)
                            VStack(alignment: .leading) {
                                Text(post.name).fontWeight(.bold)
                                Text(/*DateUtil.getPeriodTimeGenerator(post.timeStamp)*/post.timeStamp ?? "")
                            }
                            .padding(.leading, 7)
                        }
                        .padding([.horizontal], 15)
                        if !post.text.isEmpty {
                            Text(post.text)
                                .multilineTextAlignment(.leading)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 15)
                                .padding(.top, 10)
                                .padding(.bottom, 5)
                        }
                        if let imageItem = post.attachment.images.first {
                            AsyncImage(url: URL(string: URL_POST_IMAGE_PATH + imageItem.image)!) { result in
                                switch result {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                case .failure:
                                    Image(systemName: "photo")
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            .padding(.top, 10)
                        }
                    }
                    .padding(.vertical, 20)
                }
                Divider()
                HStack(alignment: .center) {
                    HStack {
                        if post.likeCount > 0 {
                            Image(systemName: "heart.fill")
                        }
                        Button(action: onLikeClick) {
                            Text("Like")
                            if post.likeCount > 0 {
                                Text(String(post.likeCount))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    Divider()
                    Button(action: { isNavigate.toggle() }, label: {
                        HStack {
                            Text("Comment")
                            if post.replyCount > 0 {
                                Text(String(post.replyCount))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(10)
                    })
                }
                //NavigationLink(destination: PostDetailView(viewModel: InjectorUtils.instance.providePostDetailViewModel($post), onResult: onResult), isActive: $isNavigate, label: EmptyView.init) // old NavigationLink
            }
        }
        .navigationDestination(isPresented: $isNavigate) {
            PostDetailView(viewModel: InjectorUtils.instance.providePostDetailViewModel($post), onResult: { onResult(post) }) // new NavigationLink
        }
    }
}

struct PostListCell_Previews: PreviewProvider {
    static var previews: some View {
        PostListCell(post: Binding(get: { PostItem.EMPTY }, set: { _ in }), onLikeClick: {}, onResult: { _ in })
    }
}

