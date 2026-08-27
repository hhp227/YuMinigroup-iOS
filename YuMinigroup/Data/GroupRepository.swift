//
//  GroupRepository.swift
//  YuMinigroup
//
//  GroupRemoteDataSource를 그대로 위임하는 순수 패스스루 — UserRepository.swift와 동일한 경계 계층.
//

import Foundation
import UIKit

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

    // Task 2(2차): 가입신청(GroupInfoDialogView, TYPE_REQUEST).
    func registerGroup(groupId: String, key: String?, joinType: String, fallback: GroupItem?, completion: @escaping (Resource<Bool>) -> Void) {
        remote.registerGroup(groupId: groupId, key: key, joinType: joinType, fallback: fallback, completion: completion)
    }

    // Task 2(2차): 신청취소(GroupInfoDialogView, TYPE_CANCEL).
    func cancelJoinRequest(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void) {
        remote.cancelJoinRequest(groupId: groupId, key: key, completion: completion)
    }

    // Task 5(2차): 그룹 생성(CreateGroupView) — LMS insert → 이미지 multipart(있을 때만) → Firebase 원자 기록.
    func addGroup(title: String,
                  description: String,
                  joinType: String,
                  image: UIImage?,
                  completion: @escaping (Resource<(key: String?, group: GroupItem)>) -> Void) {
        remote.addGroup(title: title, description: description, joinType: joinType, image: image, completion: completion)
    }

    // Task 7(3차): 모임정보 프리필(DefaultSettingView) — 그룹 설정 초기 로드.
    func fetchGroupSetting(groupId: String, completion: @escaping (Resource<(name: String, description: String, joinType: String)>) -> Void) {
        remote.fetchGroupSetting(groupId: groupId, completion: completion)
    }

    // Task 7(3차): 모임정보 저장(DefaultSettingView "수정") — LMS 업데이트 → 이미지(있을 때만) →
    // Firebase Groups/{key} 표적 갱신.
    func updateGroup(groupId: String,
                      key: String?,
                      title: String,
                      description: String,
                      joinType: String,
                      image: UIImage?,
                      completion: @escaping (Resource<(name: String, description: String, joinType: String, imageURL: String?)>) -> Void) {
        remote.updateGroup(groupId: groupId, key: key, title: title, description: description, joinType: joinType, image: image, completion: completion)
    }

    func leaveGroup(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void) {
        remote.leaveGroup(groupId: groupId, key: key, completion: completion)
    }

    func deleteGroup(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void) {
        remote.deleteGroup(groupId: groupId, key: key, completion: completion)
    }
}
