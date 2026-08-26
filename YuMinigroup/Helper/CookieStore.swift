//
//  CookieStore.swift
//  YuMinigroup
//
//  YU SSO 핸드셰이크용 수동 쿠키 저장소 — Android CookieManager.getCookie(EndPoint.LOGIN_LMS) 대응.
//  HttpClient는 httpCookieAcceptPolicy = .never로 쿠키를 전혀 다루지 않으므로,
//  Set-Cookie 응답 헤더를 이 저장소에 수동으로 적재하고, 이후 요청에는 cookieHeader를 "Cookie" 헤더로 직접 붙인다.
//

import Foundation

final class CookieStore {
    static let shared = CookieStore()

    private var cookies: [String: String] = [:]
    private let lock = NSLock()

    private init() {
    }

    // 원본 Set-Cookie 헤더 값(예: "SESSION_IMAX=abc123; Path=/; HttpOnly")을 받아
    // 첫 ";" 앞의 name=value만 남기고 저장한다.
    func store(_ cookie: String) {
        let nameValue: Substring

        if let semicolonIndex = cookie.firstIndex(of: ";") {
            nameValue = cookie[..<semicolonIndex]
        } else {
            nameValue = cookie[...]
        }
        guard let equalsIndex = nameValue.firstIndex(of: "=") else {
            return
        }
        let name = nameValue[..<equalsIndex].trimmingCharacters(in: .whitespaces)
        let value = String(nameValue[nameValue.index(after: equalsIndex)...]).trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else {
            return
        }
        lock.lock()
        cookies[name] = value
        lock.unlock()
    }

    // 저장된 쿠키들을 "; "로 조인한 Cookie 요청 헤더 값
    var cookieHeader: String? {
        lock.lock()
        defer { lock.unlock() }

        guard !cookies.isEmpty else {
            return nil
        }
        return cookies.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
    }

    func clear() {
        lock.lock()
        cookies.removeAll()
        lock.unlock()
    }
}
