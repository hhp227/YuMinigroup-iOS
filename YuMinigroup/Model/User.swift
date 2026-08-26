//
//  User.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/07.
//  Copyright © 2021 홍희표. All rights reserved.
//

struct User: Codable {
    let id: Int
    
    var name: String
    
    var email: String
    
    var apiKey: String
    
    var profileImage: String
    
    var createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, email
        case apiKey = "api_key"
        case profileImage = "profile_img"
        case createdAt = "created_at"
    }
}
