//
//  SeatItem.swift
//  YuMinigroup
//
//  Android dto/SeatItem.java 대응 — 도서관 좌석 카드(스펙 §4.3). 6개 필드 전부 String이다(Android도
//  전부 String — l_occupied/l_percentage_integer도 파싱 시점까지는 문자열로 남긴다. 정수화는 렌더링
//  시점(SeatView 셀)에서만 필요한 곳에 국소적으로 적용한다, Android BindingUtils.parseInt 대응).
//

import Foundation

struct SeatItem: Identifiable, Hashable {
    var id, name, count, occupied, percentageInteger, status: String
}
