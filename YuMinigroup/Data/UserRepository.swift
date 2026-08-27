//
//  UserRepository.swift
//  YuMinigroup
//
//  UserRemoteDataSource를 그대로 위임하는 순수 패스스루 — ViewModel이 DataSource를 직접 들지 않도록
//  경계만 제공한다. Android 쪽엔 로그인 전용 Repository가 따로 없이 LoginViewModel이 Volley 요청을
//  직접 들고 있지만, 이 마이그레이션은 Repository+DataSource 경계를 전 기능에 일관 적용한다
//  (다른 태스크가 만드는 GroupRepository/ArticleRepository 등과 동일한 얇은 위임 계층).
//

import Foundation

final class UserRepository {
    private let remote = UserRemoteDataSource()

    func login(id: String, password: String, completion: @escaping (Resource<User>) -> Void) {
        remote.login(id: id, password: password, completion: completion)
    }

    func fetchMyInfo(completion: @escaping (Resource<User>) -> Void) {
        remote.fetchMyInfo(completion: completion)
    }

    func syncProfile(completion: @escaping (Resource<String>) -> Void) {
        remote.syncProfile(completion: completion)
    }

    func updateProfileImage(imageData: Data, completion: @escaping (Resource<String>) -> Void) {
        remote.updateProfileImage(imageData: imageData, completion: completion)
    }

    // Task 7(3차): 그룹 설정 회원관리 탭(MemberManagementView).
    func fetchManagedMembers(groupId: String, completion: @escaping (Resource<[MemberItem]>) -> Void) {
        remote.fetchManagedMembers(groupId: groupId, completion: completion)
    }
}
