//
//  ReplyItem.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/09/23.
//  Copyright © 2021 홍희표. All rights reserved.
//

struct ReplyItem: Codable, Identifiable, ListItem {
    var id: Int
    
    var userId: Int
    
    var name: String
    
    var reply: String
    
    var status: Int
    
    var profileImage: String?
    
    var timeStamp: String
    
    static let EMPTY = ReplyItem(id: 0, userId: 0, name: "", reply: "", status: 0, profileImage: nil, timeStamp: "")
    
    enum CodingKeys: String, CodingKey {
        case id, name, reply, status
        case userId = "user_id"
        case profileImage = "profile_img"
        case timeStamp = "created_at"
    }
}
