//
//  LoginViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.LoginViewModel 대응 — 아이디/비밀번호 유효성 검사(둘 다 비어있지 않을 것) 후
//  UserRepository.login을 호출한다. Android는 EditText 두 개에 각각 에러를 붙이지만(mEmailError/
//  mPasswordError), 이쪽 State는 토스트용 message 하나뿐이라 아이디 → 비밀번호 순으로 검사해 먼저
//  걸리는 쪽 문구만 노출한다(문구 자체는 Android 원문 그대로). 성공 시 PreferenceManager.storeUser로
//  세션을 저장하는 것은 VM 책임이다(UserRepository.login은 저장하지 않는다 — Task 7 계약).
//

import Foundation
import Combine

final class LoginViewModel: ObservableObject {
    struct State {
        var id = ""
        var password = ""
        var isLoading = false
        var message: String?
        var loggedInUser: User?
    }

    @Published var state = State()

    private let userRepository: UserRepository

    init(userRepository: UserRepository = UserRepository()) {
        self.userRepository = userRepository
    }

    // Android LoginViewModel.login(id, password) 대응.
    func login() {
        guard !state.isLoading else {
            return
        }
        guard !state.id.isEmpty else {
            state.message = "아이디 또는 학번을 입력하세요."
            return
        }
        guard !state.password.isEmpty else {
            state.message = "패스워드를 입력하세요."
            return
        }
        state.message = nil
        state.isLoading = true
        userRepository.login(id: state.id, password: state.password) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let user):
                self.state.isLoading = false
                PreferenceManager.shared.storeUser(user)
                self.state.loggedInUser = user
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }
}
