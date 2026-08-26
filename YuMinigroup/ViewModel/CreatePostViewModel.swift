//
//  CreatePostViewModel.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/28.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import Combine

class CreatePostViewModel: ObservableObject {
    private let repository: PostRepository
    
    private var apiKey: String = ""
    
    private let post: PostItem
    
    private let type: Int
    
    private let groupId: Int
    
    @Published
    var state: State
    
    private func insertPost(_ text: String) {
        repository.addPost(apiKey, groupId: groupId, text)
            .receive(on: RunLoop.main)
            .sink { result in
                switch result.status {
                case .SUCCESS:
                    if self.state.items.count > 1 {
                        // TODO
                    } else {
                        self.state = self.state.copy(
                            isLoading: false,
                            postId: result.data ?? -1
                        )
                    }
                case .ERROR:
                    self.state = self.state.copy(
                        isLoading: false,
                        message: result.message ?? "An unexpected error occured"
                    )
                case .LOADING:
                    self.state = self.state.copy(isLoading: true)
                }
            }
            .store(in: &state.subscriptions)
    }
    
    private func updatePost(_ text: String) {
        repository.setPost(apiKey, post.id, text)
            .receive(on: RunLoop.main)
            .sink { result in
                switch result.status {
                case .SUCCESS:
                    if result.data == true {
                        self.deleteImages(self.post.id)
                        if self.state.items.count > 1 {
                            self.uploadImage(1, self.post.id)
                        } else {
                            self.state = self.state.copy(
                                isLoading: false,
                                postId: self.post.id
                            )
                        }
                    }
                case .ERROR:
                    self.state = self.state.copy(
                        isLoading: false,
                        message: result.message ?? "An unexpected error occured"
                    )
                case .LOADING:
                    self.state = self.state.copy(isLoading: true)
                }
            }
            .store(in: &state.subscriptions)
    }
    
    private func uploadImage(_ position: Int, _ postId: Int) {
        
    }
    
    private func imageUploadProcess(_ position: Int, _ postId: Int) {
        
    }
    
    private func deleteImages(_ postId: Int) {
        
    }
    
    func addItem(_ item: ImageItem) {
        DispatchQueue.main.async {
            self.state = self.state.copy(
                items: self.state.items + [item]
            )
        }
    }
    
    func removeItem() {
        
    }
    
    func actionSend() {
        if !state.text.isEmpty || state.items.count > 1 {
            switch type {
            case 0:
                insertPost(state.text)
                break
            case 1:
                updatePost(state.text)
                break
            default:
                break
            }
        } else {
            state = state.copy(message: "입력해주세요.")
        }
    }
    
    init(
        _ repository: PostRepository,
        _ userDefaultsManager: UserDefaultsManager,
        _ savedStateHandle: SavedStateHandle
    ) {
        self.repository = repository
        self.post = savedStateHandle.get(POST_KEY) ?? PostItem.EMPTY
        self.type = savedStateHandle.get(TYPE_KEY) ?? 0
        self.groupId = savedStateHandle.get(GROUP_ID_KEY) ?? 0
        self.state = State(text: post.text, items: [post])
        
        userDefaultsManager.userPublisher
            .catch { _ in
                Just(nil)
            }
            .sink {
                self.apiKey = $0?.apiKey ?? ""
            }
            .store(in: &state.subscriptions)
    }
    
    struct State {
        var text: String = ""
        
        var isLoading: Bool = false
        
        var items: [ListItem] = []
        
        var postId: Int = -1
        
        var message: String = ""
        
        var subscriptions: Set<AnyCancellable> = []
    }
}

extension CreatePostViewModel.State {
    func copy(
        text: String? = nil,
        isLoading: Bool? = nil,
        items: [ListItem]? = nil,
        postId: Int? = nil,
        message: String? = nil,
        subscriptions: Set<AnyCancellable>? = nil
    ) -> CreatePostViewModel.State {
        return .init(
            text: text ?? self.text,
            isLoading: isLoading ?? self.isLoading,
            items: items ?? self.items,
            postId: postId ?? self.postId,
            message: message ?? self.message,
            subscriptions: subscriptions ?? self.subscriptions
        )
    }
}
