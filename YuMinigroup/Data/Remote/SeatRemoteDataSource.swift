//
//  SeatRemoteDataSource.swift
//  YuMinigroup
//
//  Android viewmodel.SeatViewModel.fetchDataTask(JsonObjectRequest) 대응 — 이 리포는 1차 관례대로
//  VM이 아니라 DataSource+Repository 계층에 네트워킹/파싱을 둔다(UnivNoticeRemoteDataSource와 동일
//  경계). 공개 GET, 쿠키/헤더 불필요(스펙 §4.3) — HttpClient.request를 headers 기본값([:])으로 그대로
//  호출한다.
//
//  파싱: JSON 루트 키 `_Model_lg_clicker_reading_room_brief_list`(배열) → 각 원소를
//  JSONSerialization으로 얻은 [String: Any] 딕셔너리에서 l_id/l_room_name/l_count/l_occupied/
//  l_percentage_integer/l_open_mode 여섯 필드를 뽑는다. Android는 JSONObject.getString(...)이 숫자
//  값도 문자열로 강등해 돌려주는데(JSONObject의 관례), Foundation의 JSONSerialization은 숫자 필드를
//  NSNumber로 돌려주므로 그대로 String 캐스팅하면 실패한다 — 브리프 지시대로 각 값을 "\($0)"로 강제
//  강등하는 유연 디코딩을 쓴다(값이 문자열이든 숫자든 동일하게 취급, NSNull/키 누락만 실패로 skip).
//  행 단위 실패는 skip(개별 예외 처리, GroupRemoteDataSource/UnivNoticeRemoteDataSource와 동일 원칙).
//
//  루트 키 자체를 못 찾으면(페이지 구조가 바뀐 경우) 전체를 .error로 강등한다(UnivNoticeRemoteDataSource의
//  board-table 세그먼트 부재 처리와 동일 원칙).
//

import Foundation

final class SeatRemoteDataSource {
    // Android fetchDataTask(isRefresh) 대응. 요청 자체는 페이징이 없으므로 매번 전체를 다시 받는다.
    func fetchSeats(completion: @escaping (Resource<[SeatItem]>) -> Void) {
        completion(.loading)

        HttpClient.request(EndPoint.librarySeatRooms) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let body):
                guard let data = body.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let list = json["_Model_lg_clicker_reading_room_brief_list"] as? [[String: Any]] else {
                    completion(.error("좌석 정보를 불러오지 못했습니다."))
                    return
                }
                completion(.success(list.compactMap(SeatRemoteDataSource.parseItem(_:))))
            }
        }
    }

    // MARK: - JSON 파싱 (스펙 §4.3)

    private static func parseItem(_ dict: [String: Any]) -> SeatItem? {
        guard let id = SeatRemoteDataSource.string(dict["l_id"]),
              let name = SeatRemoteDataSource.string(dict["l_room_name"]),
              let count = SeatRemoteDataSource.string(dict["l_count"]),
              let occupied = SeatRemoteDataSource.string(dict["l_occupied"]),
              let percentage = SeatRemoteDataSource.string(dict["l_percentage_integer"]),
              let status = SeatRemoteDataSource.string(dict["l_open_mode"]) else {
            return nil
        }
        return SeatItem(id: id, name: name, count: count, occupied: occupied, percentageInteger: percentage, status: status)
    }

    // 유연 디코딩: 문자열/숫자 어느 쪽으로 와도 "\($0)"로 강등한다(브리프 지시). NSNull이나 키 자체가
    // 없는 경우만 nil로 돌려 상위 guard가 그 행을 skip하게 한다.
    private static func string(_ value: Any?) -> String? {
        guard let value = value, !(value is NSNull) else {
            return nil
        }
        return "\(value)"
    }
}
