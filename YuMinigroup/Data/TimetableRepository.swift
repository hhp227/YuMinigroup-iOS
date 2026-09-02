//
//  TimetableRepository.swift
//  YuMinigroup
//
//  TimetableRemoteDataSource를 그대로 위임하는 순수 패스스루 — UnivNoticeRepository/SeatRepository와
//  동일 경계 계층(스펙 §4.2 "1차 계층 관례").
//

import Foundation

final class TimetableRepository {
    private let remote = TimetableRemoteDataSource()

    func fetchSemesterTable(completion: @escaping (Resource<[[String]]>) -> Void) {
        remote.fetchSemesterTable(completion: completion)
    }
}
