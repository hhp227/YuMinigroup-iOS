//
//  RegisterViewModel.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/07.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import Combine

class RegisterViewModel: ObservableObject {
    private let repository: UserRepository
    
    @Published
    var state = State()
    
    private func isEmailValid(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        return email.contains("@") ? NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluate(with: email) : !email.isEmpty
    }
    
    private func isPasswordValid(_ password: String) -> Bool {
        return password.count > 5
    }
    
    private func isPasswordAndConfirmationValid(_ password: String, _ confirmedPassword: String) -> Bool {
        return password == confirmedPassword
    }
    
    func register() {
        if isEmailValid(state.email) && isPasswordValid(state.password) && isPasswordAndConfirmationValid(state.password, state.confirmPassword) {
            repository.register(state.name, state.email, state.password)
                .receive(on: RunLoop.main)
                .sink { result in
                    switch result.status {
                    case .SUCCESS:
                        self.state = self.state.copy(
                            isLoading: false,
                            isSuccess: true
                        )
                    case .ERROR:
                        self.state = self.state.copy(
                            isLoading: false,
                            isSuccess: false,
                            message: result.message
                        )
                    case .LOADING:
                        self.state = self.state.copy(
                            isLoading: true
                        )
                    }
                }
                .store(in: &state.subscriptions)
        } else {
            print("?????")
        }
    }
    
    init(_ repository: UserRepository) {
        self.repository = repository
    }
    
    struct State {
        var name: String = ""
        
        var email: String = ""
        
        var password: String = ""
        
        var confirmPassword: String = ""
        
        var isLoading: Bool = false
        
        var isSuccess: Bool = false
        
        var message: String = ""
        
        var subscriptions: Set<AnyCancellable> = []
    }
}

extension RegisterViewModel.State {
    func copy(
        name: String? = nil,
        email: String? = nil,
        password: String? = nil,
        confirmPassword: String? = nil,
        isLoading: Bool? = nil,
        isSuccess: Bool? = nil,
        message: String? = nil,
        subscriptions: Set<AnyCancellable>? = nil
    ) -> RegisterViewModel.State {
        return .init(
            name: name ?? self.name,
            email: email ?? self.email,
            password: password ?? self.password,
            confirmPassword: confirmPassword ?? self.confirmPassword,
            isLoading: isLoading ?? self.isLoading,
            isSuccess: isSuccess ?? self.isSuccess,
            message: message ?? self.message,
            subscriptions: subscriptions ?? self.subscriptions
        )
    }
}
