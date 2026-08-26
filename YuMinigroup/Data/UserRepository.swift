//
//  UserRepository.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/08.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import Combine

class UserRepository {
    private let authService: AuthService
    
    func login(_ email: String, _ password: String) -> Publishers.Catch<AnyPublisher<Resource<User>, Error>, Just<Resource<User>>> {
        return Future { promise in
            Task {
                do {
                    let response = try await self.authService.login(email, password)
                    
                    promise(.success(Resource.success(response.data)))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .prepend(Resource.loading(nil))
        .eraseToAnyPublisher()
        .catch { error in
            Just(Resource.error(error.localizedDescription, nil))
        }
    }
    
    func register(_ name: String, _ email: String, _ password: String) -> Publishers.Catch<AnyPublisher<Resource<Bool>, Error>, Just<Resource<Bool>>> {
        return Future { promise in
            Task {
                do {
                    let response = try await self.authService.register(name, email, password)
                        
                    if !response.error {
                        promise(.success(Resource.success(true)))
                    } else {
                        promise(.success(.error("", response.error)))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .prepend(Resource.loading(nil))
        .eraseToAnyPublisher()
        .catch { error in
            Just(Resource.error(error.localizedDescription, nil))
        }
    }
    
    init(_ authService: AuthService) {
        self.authService = authService
    }
    
    private static var instance: UserRepository? = nil
    
    static func getInstance(authService: AuthService) -> UserRepository {
        if let instance = self.instance {
            return instance
        } else {
            let userRepository = UserRepository(authService)
            self.instance = userRepository
            return userRepository
        }
    }
}
