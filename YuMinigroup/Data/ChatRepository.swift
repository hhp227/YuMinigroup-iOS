//
//  ChatRepository.swift
//  YuMinigroup
//
//  ChatRemoteDataSource를 그대로 위임하는 순수 패스스루 — GroupRepository/UserRepository와 동일한
//  경계 계층(1차 관례). 화면(ChatView/ChatViewModel)은 Task 8 몫이라 여기서는 배선하지 않는다.
//

import Foundation

final class ChatRepository {
    private let remote = ChatRemoteDataSource()

    var isAvailable: Bool {
        remote.isAvailable
    }

    func fetchMessages(currentUid: String,
                        receiver: String,
                        isGroupChat: Bool,
                        cursor: String?,
                        limit: Int,
                        completion: @escaping (Result<[MessageItem], Error>) -> Void) {
        remote.fetchMessages(currentUid: currentUid, receiver: receiver, isGroupChat: isGroupChat, cursor: cursor, limit: limit, completion: completion)
    }

    func observeNewMessages(currentUid: String,
                             receiver: String,
                             isGroupChat: Bool,
                             afterKey: String?,
                             onMessage: @escaping (MessageItem) -> Void) -> UInt? {
        remote.observeNewMessages(currentUid: currentUid, receiver: receiver, isGroupChat: isGroupChat, afterKey: afterKey, onMessage: onMessage)
    }

    func removeObserver(currentUid: String, receiver: String, isGroupChat: Bool, handle: UInt) {
        remote.removeObserver(currentUid: currentUid, receiver: receiver, isGroupChat: isGroupChat, handle: handle)
    }

    @discardableResult
    func sendMessage(user: User, receiver: String, isGroupChat: Bool, text: String) -> MessageItem? {
        remote.sendMessage(user: user, receiver: receiver, isGroupChat: isGroupChat, text: text)
    }
}
