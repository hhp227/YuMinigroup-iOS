//
//  ArticleItem.swift
//  YuMinigroup
//
//  Android dto/ArticleItem.java 대응 — 게시글 목록/상세 카드. Android는 replyCount를 String으로,
//  유튜브 정보를 별도 YouTubeItem(dto/YouTubeItem.java) 객체로 갖지만, 1차 마이그레이션에서는
//  replyCount를 Int로 변환하고 유튜브 정보는 videoId 하나만 남겨 썸네일 표시+외부 열기 전용으로
//  단순화한다(youtubeId = Android YouTubeItem.videoId 미러).
//

import Foundation

struct ArticleItem: Codable, Identifiable, Hashable {
    var id: String            // artl_num
    var key: String?          // Firebase key
    var uid, name, title, content: String
    var images: [String]
    var youtubeId: String?    // 1차: 썸네일 표시+외부 열기 전용
    var replyCount: Int
    var timestamp: Date?
    var isAuth: Bool          // 본인 글 여부(수정/삭제 메뉴)
}
