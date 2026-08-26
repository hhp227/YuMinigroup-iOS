//
//  PostItem.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/29.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation

struct PostItem: Codable, Identifiable, Equatable, ListItem {
    var id: Int
    
    var userId: Int
    
    var name: String
    
    var text: String
    
    var status: Int
    
    var profileImage: String?
    
    //var timeStamp: Date
    var timeStamp: String?
    
    var replyCount: Int
    
    var likeCount: Int
    
    var reportCount: Int
    
    var attachment: Attachment
    
    static var EMPTY = PostItem(id: 0, userId: 0, name: "", text: "", status: 0, timeStamp: ""/*timeStamp: .now*/, replyCount: 0, likeCount: 0, reportCount: 0, attachment: .init(images: [], video: nil))
    
    static func == (lhs: PostItem, rhs: PostItem) -> Bool {
        return lhs.id == rhs.id
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, text, status, attachment
        case userId = "user_id"
        case profileImage = "profile_img"
        case timeStamp = "created_at"
        case replyCount = "reply_count"
        case likeCount = "like_count"
        case reportCount = "report_count"
    }
    
    struct Attachment: Codable {
        var images: [ImageItem]
        
        var video: String?
    }
}
