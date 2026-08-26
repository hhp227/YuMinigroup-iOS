//
//  HttpClient.swift
//  YuMinigroup
//
//  Android의 Volley(StringRequest) 대응 — URLSession 기반. 콜백은 메인 큐에서 호출된다.
//
//  YU SSO 로그인은 (a) 리다이렉트를 따라가면 Set-Cookie가 유실되고, (b) 쿠키가 전면 수동이어야 하며,
//  (c) portal.yu.ac.kr이 TLS 신뢰 예외를 필요로 하는 3단계 핸드셰이크다. 이를 위해 KNU판(request만 존재)에
//  requestWithHeaders·리다이렉트 미추적·portal 한정 TLS 예외 delegate를 추가한 확장판.
//

import Foundation

enum HttpClient {
    // 본문 문자열만 필요한 일반 요청 (UTF-8 우선, 실패시 EUC-KR 폴백)
    static func request(_ urlString: String,
                         method: String = "GET",
                         headers: [String: String] = [:],
                         formParams: [String: String]? = nil,
                         completion: @escaping (Result<String, Error>) -> Void) {
        performRequest(urlString, method: method, headers: headers, formParams: formParams) { result in
            switch result {
            case .success(let (data, _)):
                completion(.success(decode(data)))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // SSO 핸드셰이크용 — 본문과 함께 HTTPCookie 파싱을 거친 "name=value" 쿠키 배열을 반환한다.
    static func requestWithHeaders(_ urlString: String,
                                    method: String = "GET",
                                    headers: [String: String] = [:],
                                    formParams: [String: String]? = nil,
                                    completion: @escaping (Result<(body: String, setCookies: [String]), Error>) -> Void) {
        performRequest(urlString, method: method, headers: headers, formParams: formParams) { result in
            switch result {
            case .success(let (data, response)):
                completion(.success((body: decode(data), setCookies: setCookieValues(from: response))))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Session

    // 쿠키 전면 수동(httpCookieAcceptPolicy = .never / httpShouldSetCookies = false) +
    // 리다이렉트 미추적 + portal.yu.ac.kr 한정 TLS 예외를 갖는 전용 세션.
    // internal로 노출 — MultipartRequest도 URLSession.shared 대신 이 세션을 재사용해
    // 공용 쿠키 저장소로 Set-Cookie가 새는 것을 막는다(리뷰 IMPORTANT 3).
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral

        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        return URLSession(configuration: configuration, delegate: SessionDelegate(), delegateQueue: nil)
    }()

    // MARK: - Core

    private static func performRequest(_ urlString: String,
                                        method: String,
                                        headers: [String: String],
                                        formParams: [String: String]?,
                                        completion: @escaping (Result<(Data, HTTPURLResponse?), Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(.failure(AppError(message: "잘못된 URL: \(urlString)")))
            }
            return
        }
        var request = URLRequest(url: url)

        request.httpMethod = method
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let formParams = formParams {
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")

            request.httpBody = encodeParams(formParams).data(using: .utf8)
        }
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                // 본문이 없는(예: SSO 302) 응답도 Set-Cookie는 살려서 전달해야 하므로
                // data가 nil이어도 실패시키지 않고 빈 Data로 계속 진행한다(리뷰 IMPORTANT 6).
                completion(.success((data ?? Data(), response as? HTTPURLResponse)))
            }
        }.resume()
    }

    // UTF-8 우선, 실패시 EUC-KR로 디코딩 (학교 서버 대응)
    private static func decode(_ data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        let eucKr = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue))

        return String(data: data, encoding: String.Encoding(rawValue: eucKr)) ?? ""
    }

    // allHeaderFields는 딕셔너리라 CFNetwork가 반복된 Set-Cookie 헤더를 콤마로 병합한 값 하나로
    // 접어버릴 수 있다(예: "SESSION_IMAX=abc; Path=/; HttpOnly, ssotoken=xyz; Path=/"). 단순 문자열
    // 순회/분리로는 Expires 속성의 콤마와 쿠키 구분 콤마를 구별할 수 없으므로, Foundation이 제공하는
    // HTTPCookie.cookies(withResponseHeaderFields:for:)로 위임해 정확히 분리한다(리뷰 CRITICAL 1).
    private static func setCookieValues(from response: HTTPURLResponse?) -> [String] {
        guard let response = response, let url = response.url else {
            return []
        }
        var fields: [String: String] = [:]

        for (key, value) in response.allHeaderFields {
            if let keyString = key as? String, let valueString = value as? String {
                fields[keyString] = valueString
            }
        }
        return HTTPCookie.cookies(withResponseHeaderFields: fields, for: url).map { "\($0.name)=\($0.value)" }
    }

    private static func encodeParams(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics

        allowed.insert(charactersIn: "-._*")
        return params.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value

            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
    }

    // MARK: - SessionDelegate

    // 리다이렉트를 따라가지 않고(SSO 302 응답의 Set-Cookie 보존), portal.yu.ac.kr에 한해서만
    // TLS 신뢰 예외를 두는 delegate (Android SSLConnect의 신뢰-전체-허용을 단일 호스트로 축소한 미러)
    private final class SessionDelegate: NSObject, URLSessionTaskDelegate {
        private static let trustedHost = "portal.yu.ac.kr"

        func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest,
                         completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }

        func urlSession(_ session: URLSession,
                         didReceive challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                  challenge.protectionSpace.host == SessionDelegate.trustedHost,
                  let serverTrust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        }
    }
}
