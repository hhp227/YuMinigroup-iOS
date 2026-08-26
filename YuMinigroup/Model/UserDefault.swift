//
//  UserDefault.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2025/02/23.
//

import Foundation

struct UserDefault: Codable {
    var user: User?
    
    var notifications: String? = nil
    
    enum CodingKeys: String, CodingKey {
        case user, notifications
    }
}
