//
//  ArticleItem.swift
//  YuMinigroup
//
//  Android dto/ArticleItem.java 대응 — 게시글 목록/상세 카드. Android는 replyCount를 String으로,
//  유튜브 정보를 별도 YouTubeItem(dto/YouTubeItem.java) 객체로 갖지만, 1차 마이그레이션에서는
//  replyCount를 Int로 변환하고 유튜브 정보는 videoId 하나만 남겨 썸네일 표시+외부 열기 전용으로
//  단순화한다(youtubeId = Android YouTubeItem.videoId 미러).
//
//  youtubePosition(3차 Task 10 신설)은 상세 파서(Task 11)가 list_cont를 <p> 단위로 순회하며 유튜브
//  <p> 앞에 몇 개의 이미지 <p>가 있었는지 센 값 — 상세 화면이 이미지 스택의 해당 인덱스에 인앱 재생
//  WKWebView를 끼워 넣을 때 쓴다(스펙 §6.5). 목록 셀은 이 값을 쓰지 않는다(썸네일은 항상 우선 노출).
//

import Foundation

struct ArticleItem: Codable, Identifiable, Hashable {
    var id: String            // artl_num
    var key: String?          // Firebase key
    var uid, name, title, content: String
    var images: [String]
    var youtubeId: String?    // 1차: 썸네일 표시+외부 열기 전용
    var youtubePosition: Int? // 상세 삽입 위치(앞선 이미지 개수) — 목록은 미사용
    var replyCount: Int
    var timestamp: Date?
    var isAuth: Bool          // 본인 글 여부(수정/삭제 메뉴)
}
