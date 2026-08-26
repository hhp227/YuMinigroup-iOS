//
//  User.swift
//  YuMinigroup
//
//  Android dto/User.java 대응 — LMS 로그인 사용자 정보(9개 필드). Helper/PreferenceManager.swift가
//  User()를 기본 생성자로 호출한 뒤 UserDefaults.string(forKey:)(String? 반환)을 각 필드에 그대로
//  대입하는 계약을 갖고 있어, 필드를 전부 Optional String으로 선언하고 커스텀 이니셜라이저는
//  두지 않는다(합성 memberwise init이 전 필드 Optional이라 User() 호출도 그대로 컴파일된다).
//

import Foundation

struct User: Codable, Hashable {
    var userId, password, name, department, number, grade, email, uid: String?
    var phoneNumber: String?
}
