//
//  MultipartRequest.swift
//  YuMinigroup
//
//  Android volley/util/MultipartRequest.java 미러 — boundary를 수동으로 조립하는 multipart/form-data 업로드.
//

import Foundation

enum MultipartRequest {
    static func upload(_ urlString: String,
                        headers: [String: String] = [:],
                        fileField: String,
                        fileName: String,
                        mimeType: String,
                        fileData: Data,
                        formParams: [String: String] = [:],
                        completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(.failure(AppError(message: "잘못된 URL: \(urlString)")))
            }
            return
        }
        let boundary = "apiclient-\(Int64(Date().timeIntervalSince1970 * 1000))"
        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        request.setValue("multipart/form-data;boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body(boundary: boundary,
                                 fileField: fileField,
                                 fileName: fileName,
                                 mimeType: mimeType,
                                 fileData: fileData,
                                 formParams: formParams)

        // URLSession.shared는 쿠키를 자동 저장/자동 전송하고 리다이렉트도 따라간다. 업로드 대상은
        // lms.yu.ac.kr이므로 응답의 Set-Cookie가 공용 쿠키 저장소로 새어 들어가면 RemoteImage 등
        // 다른 요청에서 그 쿠키가 의도치 않게 재사용될 수 있다. HttpClient의 수동-쿠키 세션을 재사용한다(리뷰 IMPORTANT 3).
        HttpClient.session.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(AppError(message: "응답이 비어있습니다.")))
                    return
                }
                completion(.success(decode(data)))
            }
        }.resume()
    }

    // Android MultipartRequest의 textParse + dataParse + 종료 boundary를 그대로 미러링
    private static func body(boundary: String,
                              fileField: String,
                              fileName: String,
                              mimeType: String,
                              fileData: Data,
                              formParams: [String: String]) -> Data {
        let lineEnd = "\r\n"
        let twoHyphens = "--"
        var data = Data()

        for (name, value) in formParams {
            append("\(twoHyphens)\(boundary)\(lineEnd)", to: &data)
            append("Content-Disposition: form-data; name=\"\(name)\"\(lineEnd)", to: &data)
            append(lineEnd, to: &data)
            append("\(value)\(lineEnd)", to: &data)
        }
        append("\(twoHyphens)\(boundary)\(lineEnd)", to: &data)
        append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\(lineEnd)", to: &data)
        append("Content-Type: \(mimeType)\(lineEnd)", to: &data)
        append(lineEnd, to: &data)
        data.append(fileData)
        append(lineEnd, to: &data)
        append("\(twoHyphens)\(boundary)\(twoHyphens)\(lineEnd)", to: &data)
        return data
    }

    private static func append(_ string: String, to data: inout Data) {
        data.append(contentsOf: string.utf8)
    }

    // UTF-8 우선, 실패시 EUC-KR로 디코딩 (학교 서버 대응) — HttpClient와 동일 규칙
    private static func decode(_ data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        let eucKr = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.EUC_KR.rawValue))

        return String(data: data, encoding: String.Encoding(rawValue: eucKr)) ?? ""
    }
}
