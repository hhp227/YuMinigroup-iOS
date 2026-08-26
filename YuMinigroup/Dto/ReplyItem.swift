//
//  ReplyItem.swift
//  YuMinigroup
//
//  Android dto/ReplyItem.java 대응 — 게시글 댓글. Android가 date(표시용 날짜 문자열)와
//  timestamp(정렬/상대시각 계산용 long)를 둘 다 갖고 있어 date를 대조 후 추가로 미러링한다.
//

import Foundation

struct ReplyItem: Codable, Identifiable, Hashable {
    var id: String            // cmt_num
    var key: String?
    var uid, name, reply: String
    var date: String?         // Android ReplyItem.date 미러(표시용 날짜 문자열)
    var timestamp: Date?
    var isAuth: Bool
}
