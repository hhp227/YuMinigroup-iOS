//
//  PostService.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2023/01/10.
//

import Foundation

class PostServiceImpl: PostService {
    func getPosts(_ groupId: Int, _ offset: Int, _ loadSize: Int) async throws -> BasicApiResponse<[PostItem]> {
        var urlRequest = URLRequest(url: URL(string: URL_POSTS.replacingOccurrences(of: "{GROUP_ID}", with: String(groupId)).replacingOccurrences(of: "{OFFSET}", with: String(offset)).replacingOccurrences(of: "{LOAD_SIZE}", with: String(loadSize)))!)
        urlRequest.httpMethod = HttpMethod.get.method
        urlRequest.timeoutInterval = 10
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            fatalError(response.description)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<[PostItem]>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }
    
    func addPost(_ apiKey: String, _ text: String, _ groupId: Int) async throws -> BasicApiResponse<Int> {
        var urlRequest = URLRequest(url: URL(string: URL_POST)!)
        let params = ["text": text, "group_id": String(groupId)]
            .map { "\($0)=\($1)" }
            .joined(separator: "&")
            .data(using: .utf8)
        let header = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8", "Authorization": apiKey]
        urlRequest.httpMethod = HttpMethod.post.method
        urlRequest.httpBody = params
        urlRequest.timeoutInterval = 10
        urlRequest.allHTTPHeaderFields = header
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            fatalError(response.description)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<Int>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }

    func setPost(_ apiKey: String, _ postId: Int, _ text: String, _ status: Int = 0) async throws -> BasicApiResponse<Bool> {
        var urlRequest = URLRequest(url: URL(string: "\(URL_POST)/\(postId)")!)
        let params = ["post_id": String(postId), "text": text, "status": String(status)]
            .map { "\($0)=\($1)" }
            .joined(separator: "&")
            .data(using: .utf8)
        let header = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8", "Authorization": apiKey]
        urlRequest.httpMethod = HttpMethod.put.method
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
    
    func removePost(_ apiKey: String, _ postId: Int) async throws -> BasicApiResponse<VoidCodable> {
        var urlRequest = URLRequest(url: URL(string: "\(URL_POST)/\(postId)")!)
        let params = ["post_id": String(postId)]
            .map { "\($0)=\($1)" }
            .joined(separator: "&")
            .data(using: .utf8)
        let header = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8", "Authorization": apiKey]
        urlRequest.httpMethod = HttpMethod.delete.method
        urlRequest.httpBody = params
        urlRequest.timeoutInterval = 10
        urlRequest.allHTTPHeaderFields = header
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            fatalError(response.description)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<VoidCodable>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }
}

protocol PostService {
    func getPosts(_ groupId: Int, _ offset: Int, _ loadSize: Int) async throws -> BasicApiResponse<[PostItem]>
    
    func addPost(_ apiKey: String, _ text: String, _ groupId: Int) async throws -> BasicApiResponse<Int>

    func setPost(_ apiKey: String, _ postId: Int, _ text: String, _ status: Int) async throws -> BasicApiResponse<Bool>
    
    func removePost(_ apiKey: String, _ postId: Int) async throws -> BasicApiResponse<VoidCodable>
}
