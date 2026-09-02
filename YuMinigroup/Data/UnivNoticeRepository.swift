//
//  UnivNoticeRepository.swift
//  YuMinigroup
//
//  UnivNoticeRemoteDataSource를 그대로 위임하는 순수 패스스루 — UserRepository/GroupRepository와
//  동일한 경계 계층(스펙 §4.1 "1차 계층 관례" 지시).
//

import Foundation

final class UnivNoticeRepository {
    private let remote = UnivNoticeRemoteDataSource()

    func fetchNotices(offset: Int, completion: @escaping (Resource<[BbsItem]>) -> Void) {
        remote.fetchNotices(offset: offset, completion: completion)
    }
}
