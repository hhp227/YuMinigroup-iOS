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

    // Task 1(2차): 그룹찾기(FindGroupView) 목록. 페이징 종료는 isGroupPagingStopped로 조회한다.
    func fetchNotJoinedGroups(offset: Int, limit: Int, completion: @escaping (Resource<[GroupItem]>) -> Void) {
        remote.fetchNotJoinedGroups(offset: offset, limit: limit, completion: completion)
    }

    // Task 1(2차): 가입신청중(RequestView) 목록.
    func fetchJoinRequestGroups(offset: Int, limit: Int, completion: @escaping (Resource<[GroupItem]>) -> Void) {
        remote.fetchJoinRequestGroups(offset: offset, limit: limit, completion: completion)
    }

    // Android isStopRequestMore() 대응 — 화면이 다음 페이지 요청 전에 확인한다.
    var isGroupPagingStopped: Bool {
        remote.isGroupPagingStopped
    }

    // 새로고침 시 minId/stopRequestMore를 함께 리셋한다(Android 결함 3 수정).
    func resetGroupPaging() {
        remote.resetGroupPaging()
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
