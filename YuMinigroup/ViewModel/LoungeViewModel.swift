//
//  LoungeViewModel.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/29.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Combine
import Foundation

class LoungeViewModel: ObservableObject {
    private let repository: PostRepository
    
    private var apiKey: String = ""
    
    @Published
    var state = State()
    
    private func setPagingData(pagingData: PagingData<PostItem>) {
        state = state.copy(pagingData: pagingData)
    }
    
    func togglePostLike(_ post: PostItem) {
        // 임시 코드
        let pagingData = state.pagingData.filter { $0.id != post.id }
        
        setPagingData(pagingData: pagingData)
        print("togglePostLike \(post)")
    }
    
    func onDeletePost(_ post: PostItem) {
        let pagingData = state.pagingData.filter { $0.id != post.id }
        
        setPagingData(pagingData: pagingData)
        print("onDeletePost")
    }
    
    func refresh() {
        print("refresh")
    }
    
    init(_ repository: PostRepository, _ userDefaultsManager: UserDefaultsManager) {
        self.repository = repository
        
        userDefaultsManager.userPublisher
            .catch { error in Just(nil) }
            .sink { user in
                self.apiKey = user?.apiKey ?? ""
                self.state.user = user
            }
            .store(in: &state.subscriptions)
        repository.getPosts(groupId: 0)
            .receive(on: RunLoop.main)
            .cachedIn()
            .sink(receiveValue: setPagingData)
            .store(in: &state.subscriptions)
    }
    
    deinit {
        self.state.subscriptions.removeAll()
    }
    
    struct State {
        var isLoading: Bool = false
        
        var pagingData: PagingData<PostItem> = PagingData<PostItem>.empty()
        
        var user: User? = nil
        
        var message: String = ""
        
        var subscriptions: Set<AnyCancellable> = []
    }
}

extension LoungeViewModel.State {
    func copy(
        isLoading: Bool? = nil,
        pagingData: PagingData<PostItem>? = nil,
        user: User? = nil,
        message: String? = nil,
        subscriptions: Set<AnyCancellable>? = nil
    ) -> LoungeViewModel.State {
        .init(
            isLoading: isLoading ?? self.isLoading,
            pagingData: pagingData ?? self.pagingData,
            user: user ?? self.user,
            message: message ?? self.message,
            subscriptions: subscriptions ?? self.subscriptions
        )
    }
}
