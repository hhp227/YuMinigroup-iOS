//
//  ReplyRepository.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/09/15.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import Combine

class ReplyRepository {
    private let replyService: ReplyService
    
    func getReplys(_ apiKey: String, _ postId: Int) -> Publishers.Catch<AnyPublisher<Resource<[ReplyItem]>, Error>, Just<Resource<[ReplyItem]>>> {
        return Future { promise in
            Task {
                do {
                    let response = try await self.replyService.getReplys(apiKey, postId)
                    
                    if !response.error {
                        promise(.success(.success(response.data)))
                    } else {
                        promise(.success(.error(response.message!, nil)))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .prepend(Resource.loading(nil))
        .eraseToAnyPublisher()
        .catch { error in
            Just(.error(error.localizedDescription, nil))
        }
    }
    
    func getReply(_ apiKey: String, _ replyId: Int) {
        // TODO
    }
    
    func addReply(_ apiKey: String, _ postId: Int, _ text: String) -> Publishers.Catch<AnyPublisher<Resource<ReplyItem>, Error>, Just<Resource<ReplyItem>>> {
        return Future { promise in
            Task {
                do {
                    let response = try await self.replyService.addReply(apiKey, postId, text)
                    
                    if !response.error {
                        promise(.success(.success(response.data)))
                    } else {
                        promise(.success(.error(response.message!, nil)))
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
    
    func setReply(_ apiKey: String, _ replyId: Int, _ text: String) -> Publishers.Catch<AnyPublisher<Resource<Bool>, Error>, Just<Resource<Bool>>> {
        return Future { promise in
            Task {
                do {
                    let response = try await self.replyService.setReply(apiKey, replyId, text, "0")
                    
                    if !response.error {
                        promise(.success(.success(true)))
                    } else {
                        promise(.success(.error(response.message ?? "Reply failed to update. Please try again!", false)))
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
    
    func removeReply(_ apiKey: String, _ replyId: Int) {
        // TODO
    }
    
    init(_ replyService: ReplyService) {
        self.replyService = replyService
    }
    
    private static var instance: ReplyRepository? = nil
    
    static func getInstance(replyService: ReplyService) -> ReplyRepository {
        if let instance = self.instance {
            return instance
        } else {
            let replyRepository = ReplyRepository(replyService)
            self.instance = replyRepository
            return replyRepository
        }
    }
}
