//
//  DateUtil.swift
//  YuMinigroup
//
//  Android의 helper.DateUtil 대응 — 문자열 파싱/상대 시각/포맷팅을 Date 기반으로 제공한다.
//

import Foundation

enum DateUtil {
    // LMS 응답에서 흔히 쓰이는 날짜 포맷들. Android DateUtil.java:12가 쓰는 "yyyy.MM.dd a h:mm:ss"
    // (예: "2023.05.12 오후 3:24:01", ArticleRemoteDataSource.java:98/161에서 소비)는 오전/오후
    // AM/PM 심볼이 있어야 매칭되므로 ko_KR 로케일이 필요하다. 나머지 숫자 전용 포맷은 en_US_POSIX로 고정한다.
    private static let knownFormats: [(pattern: String, localeIdentifier: String)] = [
        ("yyyy.MM.dd a h:mm:ss", "ko_KR"),
        ("yyyy-MM-dd HH:mm:ss", "en_US_POSIX"),
        ("yyyy-MM-dd'T'HH:mm:ss", "en_US_POSIX"),
        ("yyyy-MM-dd", "en_US_POSIX"),
        ("yyyyMMdd", "en_US_POSIX")
    ]

    // 문자열을 Date로 파싱 (알려진 포맷을 순서대로 시도, 모두 실패하면 nil)
    static func timestamp(from string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            return nil
        }
        for (pattern, localeIdentifier) in knownFormats {
            if let date = makeFormatter(pattern: pattern, localeIdentifier: localeIdentifier).date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    // Date를 "n분전/n시간전/날짜" 형태로 반환 (Android DateUtil.getPeriodTime 대응)
    static func relative(_ date: Date) -> String {
        let diff = Date().timeIntervalSince(date)

        switch diff {
        case ..<60:
            return "방금전"
        case ..<3600:
            return "\(Int(diff / 60))분전"
        case ..<86400:
            return "\(Int(diff / 3600))시간전"
        default:
            return format(date, pattern: "yyyy.MM.dd")
        }
    }

    // 지정한 패턴으로 Date를 문자열로 변환 (숫자 전용 출력이므로 en_US_POSIX 고정)
    static func format(_ date: Date, pattern: String) -> String {
        return makeFormatter(pattern: pattern, localeIdentifier: "en_US_POSIX").string(from: date)
    }

    private static func makeFormatter(pattern: String, localeIdentifier: String) -> DateFormatter {
        let formatter = DateFormatter()

        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = pattern
        return formatter
    }
}
