//
//  GroupRepository.swift
//  YuMinigroup
//
//  GroupRemoteDataSource를 그대로 위임하는 순수 패스스루 — UserRepository.swift와 동일한 경계 계층.
//

import Foundation

final class GroupRepository {
    private let remote = GroupRemoteDataSource()

    func fetchJoinedGroups(offset: Int, completion: @escaping (Resource<[GroupItem]>) -> Void) {
        remote.fetchJoinedGroups(offset: offset, completion: completion)
    }

    func fetchMembers(groupId: String, offset: Int, completion: @escaping (Resource<[MemberItem]>) -> Void) {
        remote.fetchMembers(groupId: groupId, offset: offset, completion: completion)
    }

    func leaveGroup(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void) {
        remote.leaveGroup(groupId: groupId, key: key, completion: completion)
    }

    func deleteGroup(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void) {
        remote.deleteGroup(groupId: groupId, key: key, completion: completion)
    }
}
