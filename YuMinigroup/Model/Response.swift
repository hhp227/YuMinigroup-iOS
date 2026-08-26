//
//  Response.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2023/03/04.
//

import Foundation

struct BasicApiResponse<T: Codable>: Codable {
    var error: Bool
    var message: String? = nil
    var data: T? = nil
    
    enum CodingKeys: String, CodingKey {
        case error, message
        case data = "result"
    }
}

struct VoidCodable: Codable {}
