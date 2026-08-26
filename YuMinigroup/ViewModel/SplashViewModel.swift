//
//  SplashViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.SplashViewModel 대응 — 저장된 자격증명으로 세션(SSO 쿠키)을 재확립한다.
//
//  주의(Task 7 리뷰에서 정정된 동작): UserRepository.login은 SSO 3단계 핸드셰이크뿐 아니라 myinfo
//  스크랩까지 매번 재실행하므로, 네트워크 순간 끊김이나 LMS 응답 포맷 변화 같은 "일시적" 사유로도
//  실패할 수 있다. 이걸 곧이곧대로 "자동 로그인 실패 → removeUser → 로그인 화면"으로 처리하면,
//  Android SplashViewModel(세션 재확립만 시도하고 실패해도 저장된 로그인 정보를 지우지 않는 관대한
//  성격)보다 훨씬 공격적으로 로그아웃시키게 된다. 그래서 실패를 두 갈래로 나눈다.
//
//  - "자격증명 자체가 거부됨"(UserRemoteDataSource.loginSSOPortal이 ssotoken 쿠키를 받지 못했을 때
//    내는 authFailureMessage 문자열과 정확히 일치) → 저장된 세션이 더 이상 유효하지 않다는 뜻이므로
//    PreferenceManager.removeUser() 후 로그인 화면으로 보낸다.
//  - 그 외 모든 에러(네트워크 오류·프로필 파싱 실패·Firebase 설정 누락 등 문자열이 위와 다른 모든 경우)
//    → 일시적인 것으로 간주해 저장된 세션을 그대로 유지한 채 메인으로 진행한다(message에 남겨 SplashView가
//    토스트로 보여줄 수 있게만 한다). 이 구분이 Resource.error의 문자열만으로 애매한 케이스가 있다면
//    보수적으로(=세션 유지) 처리한다 — task-8-report.md에 근거와 함께 기록.
//

import Foundation
import Combine

final class SplashViewModel: ObservableObject {
    enum Result: Equatable {
        case success
        case failure
    }

    @Published var result: Result?

    @Published var message: String?

    private let userRepository: UserRepository

    init(userRepository: UserRepository = UserRepository()) {
        self.userRepository = userRepository
    }

    func autoLogin() {
        guard let storedUser = PreferenceManager.shared.user,
              let id = storedUser.userId,
              let password = storedUser.password else {
            // 저장된 자격증명이 아예 없다 — 로그인 화면으로 보낼 수밖에 없다.
            result = .failure
            return
        }
        userRepository.login(id: id, password: password) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                break
            case .success(let user):
                PreferenceManager.shared.storeUser(user)
                self.result = .success
            case .error(let message, _):
                if message == UserRemoteDataSource.authFailureMessage {
                    PreferenceManager.shared.removeUser()
                    self.message = message
                    self.result = .failure
                } else {
                    self.message = message
                    self.result = .success
                }
            }
        }
    }
}
