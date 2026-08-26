//
//  GroupItem.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/29.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation

struct GroupItem: Codable, Identifiable {
    var id: Int
    
    var authorId: Int
    
    var groupName: String?
    
    var authorName: String?
    
    var image: String?
    
    var description: String?
    
    var createdAt: String?
    
    var joinType: Int
    
    enum CodingKeys: String, CodingKey {
        case id, description, image
        case authorId = "author_id"
        case authorName = "author_name"
        case createdAt = "created_at"
        case groupName = "name"
        case joinType = "join_type"
    }
}
