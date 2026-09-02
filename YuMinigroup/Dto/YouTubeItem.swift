//
//  YouTubeItem.swift
//  YuMinigroup
//
//  Android dto/YouTubeItem.java 대응 — 유튜브 검색 결과 항목이자 게시글 첨부 페이로드(스펙 §6.1).
//  검색 API 응답은 중첩 JSON(id.videoId/snippet.*)이라 이 구조체로 직접 디코딩하지 않는다 —
//  YouTubeRemoteDataSource가 API 응답 전용 내부 타입으로 파싱한 뒤 이 평평한(flat) 구조체로 매핑한다
//  (Task 9). Codable은 이 구조체 자체의 직렬화(Task 6.3 첨부 왕복, 6.4 Firebase article map의
//  youtube 키)를 위한 것 — id는 계산 프로퍼티라 Codable 합성에서 제외된다(저장 프로퍼티만 대상).
//

import Foundation

struct YouTubeItem: Codable, Identifiable, Hashable {
    var id: String { videoId }

    var videoId, publishedAt, title, thumbnail, channelTitle: String
    var position: Int = -1    // Android 미러(-1=신규 첨부)
}
