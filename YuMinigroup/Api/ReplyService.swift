//
//  ReplyService.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2023/01/23.
//

import Foundation

class ReplyServiceImpl: ReplyService {
    func getReplys(_ apiKey: String, _ postId: Int) async throws -> BasicApiResponse<[ReplyItem]> {
        var urlRequest = URLRequest(url: URL(string: URL_REPLYS.replacingOccurrences(of: "{POST_ID}", with: String(postId)))!)
        urlRequest.httpMethod = HttpMethod.get.method
        urlRequest.timeoutInterval = 10
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            return BasicApiResponse(error: false)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<[ReplyItem]>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }
    
    func getReply(_ apiKey: String, _ replyId: Int) async throws -> BasicApiResponse<ReplyItem> {
        var params = ["reply_id": replyId]
        let header = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8", "Authorization": apiKey]
        var urlRequest = URLRequest(url: URL(string: URL_REPLY.replacingOccurrences(of: "{REPLY_ID}", with: String(replyId)))!)
        urlRequest.httpMethod = HttpMethod.get.method
        urlRequest.timeoutInterval = 10
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            return BasicApiResponse(error: false)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<ReplyItem>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }
    
    func addReply(_ apiKey: String, _ postId: Int, _ text: String) async throws -> BasicApiResponse<ReplyItem> {
        var urlRequest = URLRequest(url: URL(string: URL_REPLYS.replacingOccurrences(of: "{POST_ID}", with: String(postId)))!)
        urlRequest.httpMethod = HttpMethod.post.method
        urlRequest.timeoutInterval = 10
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            return BasicApiResponse(error: false)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<ReplyItem>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }
    
    func setReply(_ apiKey: String, _ replyId: Int, _ reply: String, _ status: String = "0") async throws -> BasicApiResponse<String> {
        let params = ["reply": reply, "status": status].map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)
        let header = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8", "Authorization": apiKey]
        var urlRequest = URLRequest(url: URL(string: URL_REPLY.replacingOccurrences(of: "{REPLY_ID}", with: String(replyId)))!)
        urlRequest.httpMethod = HttpMethod.put.method
        urlRequest.httpBody = params
        urlRequest.timeoutInterval = 10
        urlRequest.allHTTPHeaderFields = header
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            fatalError(response.description)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<String>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }
    
    func removeReply(_ apiKey: String, _ replyId: Int) async throws -> BasicApiResponse<Bool> {
        let params = ["reply_id": replyId].map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)
        let header = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8", "Authorization": apiKey]
        var urlRequest = URLRequest(url: URL(string: URL_REPLY.replacingOccurrences(of: "{REPLY_ID}", with: String(replyId)))!)
        urlRequest.httpMethod = HttpMethod.delete.method
        urlRequest.httpBody = params
        urlRequest.timeoutInterval = 10
        urlRequest.allHTTPHeaderFields = header
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            fatalError(response.description)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<Bool>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }
}

protocol ReplyService {
    func getReplys(_ apiKey: String, _ postId: Int) async throws -> BasicApiResponse<[ReplyItem]>
    
    func getReply(_ apiKey: String, _ replyId: Int) async throws -> BasicApiResponse<ReplyItem>
    
    func addReply(_ apiKey: String, _ postId: Int, _ text: String) async throws -> BasicApiResponse<ReplyItem>
    
    func setReply(_ apiKey: String, _ replyId: Int, _ reply: String, _ status: String) async throws -> BasicApiResponse<String>
    
    func removeReply(_ apiKey: String, _ replyId: Int) async throws -> BasicApiResponse<Bool>
}
