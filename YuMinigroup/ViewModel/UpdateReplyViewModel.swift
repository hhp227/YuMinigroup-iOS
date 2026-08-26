//
//  UpdateReplyViewModel.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/06/04.
//  Copyright © 2022 홍희표. All rights reserved.
//

import Combine
import SwiftUI

class UpdateReplyViewModel: ObservableObject {
    private let replyRepository: ReplyRepository
    
    private var apiKey: String = ""
    
    @Binding
    private var reply: ReplyItem
    
    @Published
    var state = State()
    
    func updateReply() {
        if !state.text.isEmpty {
            replyRepository.setReply(apiKey, reply.id, state.text)
                .receive(on: RunLoop.main)
                .sink { result in
                    switch result.status {
                    case .SUCCESS:
                        self.reply.reply = self.state.text
                        self.state = self.state.copy(
                            isLoading: false,
                            isSuccess: result.data
                        )
                    case .ERROR:
                        self.state = self.state.copy(
                            isLoading: false,
                            isSuccess: false,
                            message: result.message ?? "An unexpected error occured"
                        )
                    case .LOADING:
                        self.state = self.state.copy(
                            isLoading: true
                        )
                    }
                }
                .store(in: &state.subscriptions)
        } else {
            print("text is empty")
        }
    }
    
    init(
        _ replyRepository: ReplyRepository,
        _ userDefaultsManager: UserDefaultsManager,
        _ savedStateHandle: SavedStateHandle
    ) {
        self.replyRepository = replyRepository
        
        if let reply: Binding<ReplyItem> = savedStateHandle.get(REPLY_KEY) {
            self._reply = reply
            self.state.text = reply.reply.wrappedValue
        } else {
            self._reply = Binding(get: { ReplyItem.EMPTY }, set: { _ in })
        }
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
        
        var isSuccess: Bool = false
        
        var message: String = ""
        
        var subscriptions: Set<AnyCancellable> = []
    }
}

extension UpdateReplyViewModel.State {
    func copy(
        text: String? = nil,
        isLoading: Bool? = nil,
        isSuccess: Bool? = nil,
        message: String? = nil,
        subscriptions: Set<AnyCancellable>? = nil
    ) -> UpdateReplyViewModel.State {
        return UpdateReplyViewModel.State(
            text: text ?? self.text,
            isLoading: isLoading ?? self.isLoading,
            isSuccess: isSuccess ?? self.isSuccess,
            message: message ?? self.message,
            subscriptions: subscriptions ?? self.subscriptions
        )
    }
}
