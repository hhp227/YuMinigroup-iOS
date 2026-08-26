//
//  PreferenceManager.swift
//  YuMinigroup
//
//  Android helper.PreferenceManager(SharedPreferences) 대응 — UserDefaults + Combine 기반.
//  저장 필드는 Android dto.User/PreferenceManager와 동일하게 userId, password, name, department, number,
//  grade, email, uid, phoneNumber 9종이다. User는 Task 5(Dto/User.swift)에서 정의되는 외부 타입이며,
//  이 파일은 그 필드 목록을 그대로 계약으로 삼는다.
//

import Foundation
import Combine

final class PreferenceManager {
    static let shared = PreferenceManager()

    private enum Key {
        static let userId = "usr_id"
        static let password = "usr_pwd"
        static let name = "usr_nm"
        static let department = "usr_dept_nm"
        static let number = "usr_stu_id"
        static let grade = "usr_grade"
        static let email = "usr_mail"
        static let uid = "usr_uid"
        static let phoneNumber = "usr_hp"
    }

    private let defaults = UserDefaults.standard
    private let userSubject: CurrentValueSubject<User?, Never>

    private init() {
        userSubject = CurrentValueSubject(PreferenceManager.loadUser(from: UserDefaults.standard))
    }

    var user: User? {
        userSubject.value
    }

    var userPublisher: AnyPublisher<User?, Never> {
        userSubject.eraseToAnyPublisher()
    }

    func storeUser(_ user: User) {
        defaults.set(user.userId, forKey: Key.userId)
        defaults.set(user.password, forKey: Key.password)
        defaults.set(user.name, forKey: Key.name)
        defaults.set(user.department, forKey: Key.department)
        defaults.set(user.number, forKey: Key.number)
        defaults.set(user.grade, forKey: Key.grade)
        defaults.set(user.email, forKey: Key.email)
        defaults.set(user.uid, forKey: Key.uid)
        defaults.set(user.phoneNumber, forKey: Key.phoneNumber)
        userSubject.send(user)
    }

    func removeUser() {
        [Key.userId, Key.password, Key.name, Key.department, Key.number,
         Key.grade, Key.email, Key.uid, Key.phoneNumber].forEach(defaults.removeObject(forKey:))
        userSubject.send(nil)
    }

    private static func loadUser(from defaults: UserDefaults) -> User? {
        guard let userId = defaults.string(forKey: Key.userId) else {
            return nil
        }
        var user = User()

        user.userId = userId
        user.password = defaults.string(forKey: Key.password)
        user.name = defaults.string(forKey: Key.name)
        user.department = defaults.string(forKey: Key.department)
        user.number = defaults.string(forKey: Key.number)
        user.grade = defaults.string(forKey: Key.grade)
        user.email = defaults.string(forKey: Key.email)
        user.uid = defaults.string(forKey: Key.uid)
        user.phoneNumber = defaults.string(forKey: Key.phoneNumber)
        return user
    }
}
