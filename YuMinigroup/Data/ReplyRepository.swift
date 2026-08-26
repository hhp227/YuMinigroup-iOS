//
//  ReplyRepository.swift
//  YuMinigroup
//
//  ReplyRemoteDataSource를 그대로 위임하는 순수 패스스루 — ArticleRepository.swift/GroupRepository.swift/
//  UserRepository.swift와 동일한 경계 계층. ArticleViewModel은 이 Repository만 참조하고
//  ReplyRemoteDataSource를 직접 참조하지 않는다.
//

import Foundation

final class ReplyRepository {
    private let remote: ReplyRemoteDataSource

    init(groupId: String, articleId: String, articleKey: String?) {
        remote = ReplyRemoteDataSource(groupId: groupId, articleId: articleId, articleKey: articleKey)
    }

    func fetchReplys(completion: @escaping (Resource<[ReplyItem]>) -> Void) {
        remote.fetchReplys(completion: completion)
    }

    func addReply(text: String, completion: @escaping (Resource<[ReplyItem]>) -> Void) {
        remote.addReply(text: text, completion: completion)
    }

    func setReply(replyId: String, text: String, completion: @escaping (Resource<Bool>) -> Void) {
        remote.setReply(replyId: replyId, text: text, completion: completion)
    }

    func removeReply(replyId: String, replyKey: String?, completion: @escaping (Resource<[ReplyItem]>) -> Void) {
        remote.removeReply(replyId: replyId, replyKey: replyKey, completion: completion)
    }
}
