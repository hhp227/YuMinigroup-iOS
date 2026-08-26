//
//  UserRemoteDataSource.swift
//  YuMinigroup
//
//  Android의 viewmodel.LoginViewModel(SSO 3단계 핸드셰이크+myinfo 스크랩)+
//  viewmodel.ProfileViewModel(프로필 동기화·사진 변경) 대응. 로그인 정보를 외부 로그 서버로
//  전송하는 레거시 CREATE_LOG 블록은 보안상 이식하지 않는다(마이그레이션 하드 룰).
//

import Foundation
import FirebaseAuth

final class UserRemoteDataSource {
    private static let testAccountId = "22000000"

    private static let testAccountPassword = "TestUser"

    private static let testAccountEmail = "TestUser@yu.ac.kr"

    // 영남대 포털 SSO 로그인 폼이 요구하는 고정 파라미터 — Android LoginViewModel과 동일 값
    private static let ssoParamP = "20112030550005B055003090F570256534A010F47070C4556045E18020750110"

    private static let ssoReferer = "http://portal.yu.ac.kr/sso/login.jsp"

    // loginSSOPortal이 ssotoken Set-Cookie를 못 받았을 때 내는 메시지 — 아이디/비밀번호가 실제로
    // 거부된 경우로 간주하는 유일한 신호. SplashViewModel.autoLogin이 이 문자열과 정확히 일치하는지
    // 비교해 "자격증명 거부"와 "일시적 오류"를 가른다(SplashViewModel.swift 상단 코멘트 참고).
    // 두 곳에서 리터럴이 따로 있으면 드리프트 시 실제 인증 거부가 일시적 오류로 오분류될 수 있어
    // 이 상수 하나로 통일한다.
    static let authFailureMessage = "아이디 또는 비밀번호가 잘못되었습니다."

    // SSO 3단계 핸드셰이크(SESSION_IMAX 획득 → ssotoken 획득 → 세션 확립) 후 myinfo/사진을 스크랩해
    // User를 조립한다. 테스트 계정(22000000/TestUser)은 실 SSO를 건너뛰고 FirebaseAuth로 우회한다.
    // 반환된 User의 저장(PreferenceManager.storeUser)은 호출측(ViewModel) 책임이다.
    func login(id: String, password: String, completion: @escaping (Resource<User>) -> Void) {
        completion(.loading)
        if id == UserRemoteDataSource.testAccountId && password == UserRemoteDataSource.testAccountPassword {
            loginTestAccount(id: id, password: password, completion: completion)
            return
        }
        HttpClient.requestWithHeaders(EndPoint.loginLMS, method: "POST") { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let response):
                guard let sessionCookie = response.setCookies.first(where: { $0.contains("SESSION_IMAX") }) else {
                    completion(.error("로그인 세션을 생성하지 못했습니다."))
                    return
                }
                CookieStore.shared.store(sessionCookie)
                self.loginSSOPortal(id: id, password: password, completion: completion)
            }
        }
    }

    // myinfo_form.acl → myinfo_update_photo.acl 순으로 스크랩한다. 로그인 이후(CookieStore에 세션이
    // 있는 상태)에 독립적으로도 호출할 수 있도록 자격증명은 PreferenceManager에 저장된 값을 쓴다
    // (로그인 흐름 내부에서는 이미 아는 id/password로 바로 스크랩하는 private 오버로드를 대신 쓴다).
    func fetchMyInfo(completion: @escaping (Resource<User>) -> Void) {
        completion(.loading)
        let savedUser = PreferenceManager.shared.user

        fetchMyInfo(userId: savedUser?.userId, password: savedUser?.password, completion: completion)
    }

    // 프로필 동기화(LMS 학사정보 재수집). 응답 JSON({"isError":Bool,"message":String})을 그대로 전달한다.
    func syncProfile(completion: @escaping (Resource<String>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""

        HttpClient.request(EndPoint.syncProfile, method: "POST", headers: ["Cookie": cookie]) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let body):
                guard let data = body.data(using: .utf8),
                      let response = try? JSONDecoder().decode(SyncResponse.self, from: data) else {
                    completion(.error("동기화 실패"))
                    return
                }
                if response.isError {
                    completion(.error("동기화 실패"))
                } else {
                    completion(.success(response.message ?? ""))
                }
            }
        }
    }

    // myinfo_file_update.acl(미리보기) → myinfo_insert.acl(반영) 순차 업로드 — Android
    // ProfileViewModel.uploadImage(false)가 성공 시 uploadImage(true)를 연쇄 호출하는 흐름과 동일하다.
    // (두 호출 각각 파일명을 새로 뽑는 것도 Android가 매 uploadImage 호출마다 UUID를 새로 뽑는 것과 동일)
    func updateProfileImage(imageData: Data, completion: @escaping (Resource<String>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""

        MultipartRequest.upload(EndPoint.profileImagePreview,
                                 headers: ["Cookie": cookie],
                                 fileField: "img_file",
                                 fileName: UserRemoteDataSource.randomFileName(),
                                 mimeType: "image/jpeg",
                                 fileData: imageData,
                                 formParams: ["FLAG": "FILE"]) { previewResult in
            switch previewResult {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success:
                MultipartRequest.upload(EndPoint.profileImageUpdate,
                                         headers: ["Cookie": cookie],
                                         fileField: "img_file",
                                         fileName: UserRemoteDataSource.randomFileName(),
                                         mimeType: "image/jpeg",
                                         fileData: imageData,
                                         formParams: ["FLAG": "FILE"]) { updateResult in
                    switch updateResult {
                    case .failure(let error):
                        completion(.error(error.localizedDescription))
                    case .success(let body):
                        if body.contains("성공") {
                            completion(.success("수정되었습니다."))
                        } else {
                            completion(.error("실패했습니다."))
                        }
                    }
                }
            }
        }
    }

    // MARK: - SSO steps

    private func loginSSOPortal(id: String, password: String, completion: @escaping (Resource<User>) -> Void) {
        let headers = ["Referer": UserRemoteDataSource.ssoReferer, "Cookie": CookieStore.shared.cookieHeader ?? ""]
        let formParams = [
            "cReturn_Url": EndPoint.loginLMS,
            "type": "lms",
            "p": UserRemoteDataSource.ssoParamP,
            "login_gb": "0",
            "userId": id,
            "password": password
        ]

        HttpClient.requestWithHeaders(EndPoint.yuPortalLoginURL, method: "POST", headers: headers, formParams: formParams) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let response):
                guard let ssoToken = response.setCookies.first(where: { $0.contains("ssotoken") }) else {
                    completion(.error(UserRemoteDataSource.authFailureMessage))
                    return
                }
                CookieStore.shared.store(ssoToken)
                self.establishSession(id: id, password: password, completion: completion)
            }
        }
    }

    private func establishSession(id: String, password: String, completion: @escaping (Resource<User>) -> Void) {
        let cookie = CookieStore.shared.cookieHeader ?? ""

        HttpClient.request(EndPoint.loginLMS, method: "POST", headers: ["Cookie": cookie]) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success:
                self.fetchMyInfo(userId: id, password: password, completion: completion)
            }
        }
    }

    // MARK: - myinfo/사진 스크랩

    private func fetchMyInfo(userId: String?, password: String?, completion: @escaping (Resource<User>) -> Void) {
        let cookie = CookieStore.shared.cookieHeader ?? ""

        HttpClient.request(EndPoint.myInfo, method: "GET", headers: ["Cookie": cookie]) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                guard let user = UserRemoteDataSource.parseMyInfo(html, userId: userId, password: password) else {
                    completion(.error("프로필 파싱 실패"))
                    return
                }
                self.fetchUserImage(user: user, completion: completion)
            }
        }
    }

    private func fetchUserImage(user: User, completion: @escaping (Resource<User>) -> Void) {
        let cookie = CookieStore.shared.cookieHeader ?? ""

        HttpClient.request(EndPoint.getUserImage, method: "GET", headers: ["Cookie": cookie]) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                guard let uid = UserRemoteDataSource.parseUid(from: html) else {
                    completion(.error("프로필 파싱 실패"))
                    return
                }
                var finalUser = user

                finalUser.uid = uid
                completion(.success(finalUser))
            }
        }
    }

    // Android LoginViewModel.getUserInfo 대응 — content_text 블록의 <tr> 중 <td>가 2개 이상인 행만
    // 골라, 두 번째 td 텍스트의 첫 토큰(첫 공백 앞부분)을 순서대로 이름/전화번호/이메일로 삼는다.
    // (Android 원본도 학과/학번/학년은 채우지 않는다 — extractedList는 인덱스 0~2까지만 쓰인다)
    //
    // HtmlUtil.elementById는 정규식 기반이라 첫 매칭 닫는 태그에서 블록을 끊는다(균형 매칭 아님 —
    // HtmlUtil.swift:47-48에 문서화된 한계). jericho는 실제 DOM을 균형 매칭하므로, content_text가
    // <div>이고 그 안에 표(정보 테이블) 이전에 다른 중첩 <div>가 있으면 우리 쪽만 블록이 잘려
    // rows(in:)가 빈 배열을 내고 로그인이 실패할 수 있다. 앵커된 블록에서 3개 미만이 나오면 전체
    // html을 대상으로 같은 추출을 한 번 더 시도하는 안전망을 둔다(정상 케이스는 그대로 1차에서 끝남).
    private static func parseMyInfo(_ html: String, userId: String?, password: String?) -> User? {
        var extracted = UserRemoteDataSource.extractInfoFields(from: HtmlUtil.elementById("content_text", in: html) ?? "")

        if extracted.count < 3 {
            extracted = UserRemoteDataSource.extractInfoFields(from: html)
        }
        guard extracted.count > 2 else {
            return nil
        }
        var user = User()

        user.userId = userId
        user.password = password
        user.name = extracted[0]
        user.phoneNumber = extracted[1]
        user.email = extracted[2]
        return user
    }

    private static func extractInfoFields(from html: String) -> [String] {
        var extracted: [String] = []

        for rowHtml in HtmlUtil.rows(in: html) {
            let cells = HtmlUtil.cells(in: rowHtml, tag: "td")

            if cells.count > 1 {
                extracted.append(UserRemoteDataSource.firstToken(cells[1]))
            }
        }
        return extracted
    }

    // Android: imageUrl.substring(imageUrl.indexOf("id=") + "id=".length(), imageUrl.lastIndexOf("&size"))
    // jericho는 속성값을 이미 엔티티 디코딩해 돌려주지만 HtmlUtil.attribute는 원문 그대로 반환하므로,
    // LMS가 흔한 이스케이프 형태(src="...id=XXXX&amp;size=100")로 내려주면 "&size" 탐색이 실패해
    // 로그인이 끊길 수 있다. HtmlUtil.text(_:)가 이미 하는 엔티티 디코딩(&amp;/&lt;/&gt;/&quot;/&#39;)을
    // 그대로 재사용해 정상 케이스(이스케이프 없는 src)는 동작이 바뀌지 않게 하면서 이스케이프된 케이스도
    // 살린다. src에는 태그가 없으므로 HtmlUtil.text의 태그 제거 동작은 사실상 no-op이다.
    private static func parseUid(from html: String) -> String? {
        guard let photoTag = HtmlUtil.openTag(withId: "photo", in: html),
              let rawSrc = HtmlUtil.attribute("src", in: photoTag) else {
            return nil
        }
        let src = HtmlUtil.text(rawSrc)

        guard let idRange = src.range(of: "id="),
              let sizeRange = src.range(of: "&size", options: .backwards),
              idRange.upperBound <= sizeRange.lowerBound else {
            return nil
        }
        return String(src[idRange.upperBound..<sizeRange.lowerBound])
    }

    // Java String.split(" ")[0] 대응 — 첫 공백 앞부분(공백이 없으면 전체, 앞부분이 공백이면 빈 문자열)
    private static func firstToken(_ value: String) -> String {
        guard let spaceIndex = value.firstIndex(of: " ") else {
            return value
        }
        return String(value[..<spaceIndex])
    }

    private static func randomFileName() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "") + ".jpg"
    }

    // MARK: - 테스트 계정(FirebaseAuth 우회)

    private func loginTestAccount(id: String, password: String, completion: @escaping (Resource<User>) -> Void) {
        guard FirebaseRef.isConfigured else {
            completion(.error("Firebase가 설정되지 않았습니다."))
            return
        }
        Auth.auth().signIn(withEmail: UserRemoteDataSource.testAccountEmail, password: password) { authResult, error in
            guard let firebaseUser = authResult?.user else {
                completion(.error("Firebase error" + (error?.localizedDescription ?? "")))
                return
            }
            var user = User()

            user.uid = firebaseUser.uid
            user.userId = id
            user.password = password
            user.name = "TestUser"
            user.number = UserRemoteDataSource.testAccountId
            user.phoneNumber = "01000000000"
            user.email = UserRemoteDataSource.testAccountEmail
            completion(.success(user))
        }
    }

    private struct SyncResponse: Decodable {
        let isError: Bool
        let message: String?
    }
}
