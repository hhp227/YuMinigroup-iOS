//
//  AuthService.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/12/13.
//

import Foundation

class AuthServiceImpl: AuthService {
    func login(_ email: String, _ password: String) async throws -> BasicApiResponse<User> {
        let params = ["email": email, "password": password].map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)
        var urlRequest = URLRequest(url: URL(string: URL_LOGIN)!)
        urlRequest.httpMethod = HttpMethod.post.method
        urlRequest.httpBody = params
        urlRequest.timeoutInterval = 10
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            fatalError(response.description)
        }
        guard let basicResponse = try? JSONDecoder().decode(BasicApiResponse<User>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return basicResponse
    }
    
    func register(_ name: String, _ email: String, _ password: String) async throws -> BasicApiResponse<VoidCodable> {
        let params = ["name": name, "email": email, "password": password].map { "\($0)=\($1)" }.joined(separator: "&").data(using: .utf8)
        let header = ["Content-Type": "application/x-www-form-urlencoded; charset=utf-8"]
        var urlRequest = URLRequest(url: URL(string: URL_REGISTER)!)
        urlRequest.httpMethod = HttpMethod.post.method
        urlRequest.httpBody = params
        urlRequest.timeoutInterval = 10
        urlRequest.allHTTPHeaderFields = header
        let (data, response) = try! await URLSession.shared.data(for: urlRequest)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            fatalError(response.description)
        }
        guard let apiResponse = try? JSONDecoder().decode(BasicApiResponse<VoidCodable>.self, from: data) else {
            throw OurStoryError.jsonDecodeError(message: "json decode error occur")
        }
        return apiResponse
    }
}

protocol AuthService {
    func login(_ email: String, _ password: String) async throws -> BasicApiResponse<User>
    
    func register(_ name: String, _ email: String, _ password: String) async throws -> BasicApiResponse<VoidCodable>
}
