//
//  PostRepository.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/11.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import Combine

class PostRepository {
    private let postService: PostService
    
    func getPosts(groupId: Int) -> AnyPublisher<PagingData<PostItem>, Never> {
        return Pager(
            config: PagingConfig(pageSize: PostRepository.NETWORK_PAGE_SIZE, enablePlaceholders: false),
            pagingSourceFactory: { PostPagingSource(postService: self.postService, groupId: groupId) }
        ).publisher
    }
    
    func getPost(postId: Int) -> Publishers.Catch<AnyPublisher<Resource<PostItem>, Error>, Just<Resource<PostItem>>> {
        return Future { promise in
            Task {
                do {
                    let post = PostItem(id: 0, userId: 0, name: "newPost", text: "newPostText", status: 0, timeStamp: ""/*timeStamp: .now*/, replyCount: 0, likeCount: 0, reportCount: 0, attachment: .init(images: []))
                    
                    promise(.success(Resource.success(post)))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .prepend(Resource.loading(nil))
        .eraseToAnyPublisher()
        .catch { error in
            Just(Resource.error(error.localizedDescription, nil))
        }
    }
    
    func addPost(_ apiKey: String, groupId: Int, _ text: String) -> Publishers.Catch<AnyPublisher<Resource<Int>, Error>, Just<Resource<Int>>> {
        return Future { promise in
            Task {
                do {
                    let response = try await self.postService.addPost(apiKey, text, groupId)
                    
                    if !response.error {
                        promise(.success(Resource.success(response.data)))
                    } else {
                        promise(.success(Resource.error(response.message!, nil)))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .prepend(Resource.loading(nil))
        .eraseToAnyPublisher()
        .catch { error in
            Just(Resource.error(error.localizedDescription, nil))
        }
    }
    
    func setPost(_ apiKey: String, _ postId: Int, _ text: String) -> Publishers.Catch<AnyPublisher<Resource<Bool>, Error>, Just<Resource<Bool>>> {
        return Future { promise in
            Task {
                do {
                    let response = try await self.postService.setPost(apiKey, postId, text, 0)
                    
                    if !response.error {
                        promise(.success(Resource.success(response.data)))
                    } else {
                        promise(.success(Resource.error(response.message!, nil)))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .prepend(Resource.loading(nil))
        .eraseToAnyPublisher()
        .catch { error in
            Just(Resource.error(error.localizedDescription, nil))
        }
    }
    
    func removePost(_ apiKey: String, _ postId: Int) -> Publishers.Catch<AnyPublisher<Resource<Bool>, Error>, Just<Resource<Bool>>> {
        return Future { promise in
            Task {
                do {
                    let response = try await self.postService.removePost(apiKey, postId)
                    
                    if !response.error {
                        // TODO localDataSource.deletePost(postId)
                        promise(.success(Resource.success(true)))
                    } else {
                        promise(.success(Resource.error(response.message!, nil)))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .prepend(Resource.loading(nil))
        .eraseToAnyPublisher()
        .catch { error in
            Just(Resource.error(error.localizedDescription, nil))
        }
    }
    
    init(_ postService: PostService) {
        self.postService = postService
    }
    
    private static let NETWORK_PAGE_SIZE = 10
    
    private static var instance: PostRepository? = nil
    
    static func getInstance(postService: PostService) -> PostRepository {
        if let instance = self.instance {
            return instance
        } else {
            let postRepository = PostRepository(postService)
            self.instance = postRepository
            return postRepository
        }
    }
}
