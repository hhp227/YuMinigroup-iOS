//
//  UserDefaultsManager.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/11/21.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import Combine

class UserDefaultsManager {
    private let userDefaults: UserDefaults = .standard
    
    var userDefault: AnyPublisher<UserDefault, Error> {
        get {
            return userDefaults
                .publisher(for: \.userDefault)
                .tryMap {
                    if let data = $0 {
                        return try! PropertyListDecoder().decode(UserDefault.self, from: data)
                    } else {
                        return UserDefault(user: nil, notifications: nil)
                    }
                }
                .eraseToAnyPublisher()
        }
    }
    
    var notificationsPublisher: AnyPublisher<String?, Error> {
        get {
            return userDefault.map { $0.notifications }.eraseToAnyPublisher()
        }
    }
    
    var userPublisher: AnyPublisher<User?, Error> {
        get {
            return userDefault.map { $0.user }.eraseToAnyPublisher()
        }
    }
    
    func storeUser(_ user: User?) {
        userDefaults.userDefault = try? PropertyListEncoder().encode(UserDefault(user: user))
    }
    
    func removeUser() {
        userDefaults.removeObject(forKey: UserDefaultsManager.USER_KEY)
    }
    
    func clear() {
        if let appDomain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: appDomain)
        }
    }
    
    static let USER_KEY = "user"
    
    class var instance: UserDefaultsManager {
        struct Static {
            static let shared = UserDefaultsManager()
        }
        return Static.shared
    }
}

extension UserDefaults {
    // ??? 이상함
    @objc dynamic var key: Data? {
        return self.data(forKey: UserDefaultsManager.USER_KEY)
    }
    // 일단 이것으로 해결
    @objc var userDefault: Data? {
        get {
            return data(forKey: UserDefaultsManager.USER_KEY)
        }
        set {
            set(newValue, forKey: UserDefaultsManager.USER_KEY)
        }
    }
}

extension UserDefault {
    func copy(
        user: User? = nil,
        notifications: String? = nil
    ) -> UserDefault {
        return .init(
            user: user ?? self.user,
            notifications: self.notifications
        )
    }
}
