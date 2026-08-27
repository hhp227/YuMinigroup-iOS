//
//  BbsItem.swift
//  YuMinigroup
//
//  Android dto/BbsItem.java 대응 — 영대소식 목록 카드(스펙 §4.1). 4개 필드 전부 String이다
//  (Android도 전부 String — 날짜/작성자를 별도 타입으로 파싱하지 않는다).
//

import Foundation

struct BbsItem: Identifiable, Hashable {
    var id, title, writer, date: String
}
