//
//  SeatRepository.swift
//  YuMinigroup
//
//  SeatRemoteDataSource를 그대로 위임하는 순수 패스스루 — UnivNoticeRepository/UserRepository와
//  동일한 경계 계층(1차 관례).
//

import Foundation

final class SeatRepository {
    private let remote = SeatRemoteDataSource()

    func fetchSeats(completion: @escaping (Resource<[SeatItem]>) -> Void) {
        remote.fetchSeats(completion: completion)
    }
}
