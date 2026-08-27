//
//  GroupRemoteDataSource.swift
//  YuMinigroup
//
//  Android data.remote.GroupRemoteDataSource 대응 — 1차분은 getJoinedGroupList(가입한 그룹, 홈 화면
//  GroupMainView가 쓰는 목록)만 이식한다. getNotJoinedGroupList/getJoinRequestGroupList/
//  getPopularGroupList/addGroup/setGroup(그룹찾기·가입신청중·인기모임·그룹생성/수정)은 각각의 화면 태스크
//  몫이라 제외한다.
//
//  요청 파라미터는 Android GroupRemoteDataSource.getJoinedGroupList의 StringRequest.getParams()를
//  그대로 옮겼다: panel_id=2(내 그룹), start=<offset>, display=10, encoding=utf-8. Android 원본은
//  start를 항상 "1"로 고정해 호출하고(GroupMainViewModel.fetchDataTask는 오프셋 인자가 없다) 실제로
//  스크롤 더보기를 구현하지 않는다 — 이 화면(가입한 그룹)에는 페이지네이션이 없다는 뜻이다. 이 포팅은
//  브리프가 요구하는 offset 파라미터 인터페이스는 유지하되(향후 확장 여지), GroupMainViewModel은
//  Android와 동일하게 offset=1 한 번만 호출한다(가짜 스크롤 로딩을 지어내지 않는다 — task-10-report.md 참고).
//
//  HTML 파싱은 jericho의 getAllElements(A) 순회 + per-anchor try/catch(NPE→skip)를 정규식으로 미러한다:
//  각 <a onclick="...">...</a> 블록에서 onclick을 '로 split해 index 3=그룹id, index 1=="0"이면 관리자,
//  내부의 첫 <img src>를 BASE_URL과 합쳐 이미지, 첫 <strong> 텍스트를 이름으로 삼는다. Android는 이
//  루프 안에서 예외가 나면(NullPointerException 외의 타입, 예: onclick의 '분리 인자가 3개 미만일 때의
//  ArrayIndexOutOfBounds) 바깥 catch(Exception)로 번져 전체 루프가 멈추는 버그가 있다 — 여기서는 그 대신
//  개별 anchor만 건너뛰고 나머지는 계속 파싱한다(요구사항 "파싱 실패는 .error 강등, no crash"를 anchor
//  단위로 더 안전하게 만족).
//
//  Firebase 매핑(UserGroupList/{uid} value==true인 key들의 Groups/{key}.id를 LMS grp_id와 매칭해
//  GroupItem.key를 채움)은 Android initFirebaseData/fetchDataTaskFromFirebase 대응. FirebaseRef가
//  미설정이거나 uid가 없으면 매핑을 생략하고 LMS 파싱 결과만 반환한다(브리프 지시). Android는 매칭될
//  때마다 callback.onSuccess를 여러 번 호출하는 특이 동작이 있는데, 여기서는 모든 키 조회가 끝난 뒤
//  한 번만 completion을 호출한다(관찰 가능한 최종 결과는 동일 — 중복 콜백 제거는 의도적 개선).
//
//  리뷰 수정(task-10-report.md "Fix" 절 참고): onclick 속성은 HTML 큰따옴표 안에 JS 작은따옴표
//  인자를 담는다(예: onclick="javascript:fnView('0','12345','GroupName');"). HtmlUtil.attribute는
//  여는/닫는 따옴표 종류를 구분하지 않아 첫 내부 작은따옴표에서 값이 잘렸고(결과: onclick.split("'")가
//  1개짜리 배열이 되어 매 anchor가 스킵 → 목록이 통째로 빈 배열로 강등), HtmlUtil.attributeExact를
//  추가해 onclick만 이걸로 바꿨다. img src 등 기존 attribute(_:in:) 호출부는 그대로 둔다.
//
//  2차 Task 1: 그룹찾기(find)/가입신청중(request) 목록 — Android getNotJoinedGroupList/
//  getJoinRequestGroupList 대응. 두 메소드는 같은 share_group_list.acl 페이지(panel_id=1,
//  gubun=select_share_total)를 그룹 ID 파싱 방식(find=onclick을 "(),"로 split, request=onclick을
//  '로 split — Android가 groupIdExtract(String,int) 오버로드 두 종류를 각기 쓰는 것과 동일)만 다르게
//  써서 조회한다. 파싱은 <a onclick>이 아니라 id="accordion"&&class="accordion" 세그먼트 단위다(그룹
//  카드 하나 = accordion 블록 하나). HtmlUtil에는 Jericho의 getFirstElementByClass 같은 DOM 스코프
//  검색이 없어서, description/joinType(Android menuList.getAllElementsByClass("info"))과 info 목록
//  (Android element.getFirstElement(A).getAllElementsByClass("info"))이라는 서로 다른 두 스코프
//  (스펙 §3.2)를 accordion 세그먼트를 자를 때와 같은 관례("여는 태그의 시작 위치부터 끝까지"를
//  서브세그먼트로 삼기)로 각각 재현한다: class="menu_list" 여는 태그 위치부터 세그먼트 끝까지가
//  menu_list 서브세그먼트(description=[0], joinType=[1]), 첫 <a>...</a> 블록 내부(닫는 태그를 못
//  찾으면 그 여는 태그 위치부터 세그먼트 끝까지로 폴백)가 info 문자열 스코프다(수정 라운드 1 — 최초
//  구현은 두 스코프를 "세그먼트 전체의 모든 class=info 요소" 하나로 단순화했었는데, 사용자 승인 스펙과
//  충돌해 리뷰에서 Important로 지적됨. task-1-report.md의 "수정 라운드 1" 절 참고). 두 스코프 모두 못
//  찾거나 비어 있으면 해당 필드만 nil/빈 문자열로 강등한다 — 세그먼트 skip은 id/img/strong 실패
//  시에만 한다(그 필드들은 GroupItem 자체를 만들 수 없기 때문).
//
//  minId/stopRequestMore(Android mMinId/mStopRequestMore 미러)는 인스턴스 필드라 find/request가 같은
//  GroupRemoteDataSource 인스턴스를 쓰면 상태를 공유한다 — 화면당 ViewModel이 각자 GroupRepository()를
//  만드는 1차 구조(screenViewModel 인라인, DI 개편 완료분)에서는 FindGroupViewModel과 RequestViewModel이
//  각자 인스턴스를 가지므로 실제 충돌은 없다. resetGroupPaging()은 Android 결함 3(refresh 시
//  stopRequestMore 미리셋으로 페이징이 영구 정지되는 버그)을 수정한다 — minId와 함께 반드시 둘 다 리셋한다.
//

import Foundation
import FirebaseDatabase

final class GroupRemoteDataSource {
    // Android mMinId/mStopRequestMore 대응 — find/request 두 목록 조회가 공유하는 페이징 종료 휴리스틱
    // 상태다(파일 헤더 코멘트 참고). resetGroupPaging()으로만 명시적으로 되돌린다.
    private var minId = 0
    private var stopRequestMore = false

    // find(onclick "(),"-split) / request(onclick '-split) — Android groupIdExtract(String,int)의
    // 두 오버로드 차이를 그대로 미러하기 위한 모드 구분.
    private enum GroupIdParseMode {
        case find
        case request
    }

    // MARK: - 가입한 그룹 목록 (GroupMainView)

    func fetchJoinedGroups(offset: Int, completion: @escaping (Resource<[GroupItem]>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "panel_id": "2",
            "start": String(offset),
            "display": "10",
            "encoding": "utf-8"
        ]

        HttpClient.request(EndPoint.groupList, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                let items = GroupRemoteDataSource.parseJoinedGroups(from: html)

                guard let self = self else {
                    completion(.success(items))
                    return
                }
                self.mergeFirebaseKeys(into: items, completion: completion)
            }
        }
    }

    // MARK: - 그룹찾기/가입신청중 목록 (Task 1: 2차 데이터층)

    // Android isStopRequestMore() 대응.
    var isGroupPagingStopped: Bool {
        stopRequestMore
    }

    // Android 결함 3 수정: refresh 시 minId만 리셋하고 stopRequestMore를 남겨두면 이전 호출에서
    // true가 된 채로 페이징이 영구 정지된다 — 둘 다 반드시 함께 리셋한다.
    func resetGroupPaging() {
        minId = 0
        stopRequestMore = false
    }

    // Android getNotJoinedGroupList 대응(미가입 그룹, 그룹찾기 화면). 그룹 ID는 find 모드(onclick을
    // "(),"로 split)로 뽑는다. LMS 파싱 성공 후 Firebase Groups 전체 스캔으로 key를 병합한다(§3.2).
    func fetchNotJoinedGroups(offset: Int, limit: Int, completion: @escaping (Resource<[GroupItem]>) -> Void) {
        completion(.loading)
        requestGroupList(offset: offset, limit: limit) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                guard let self = self else {
                    completion(.success([]))
                    return
                }
                let items = self.parseGroupSegments(from: html, idMode: .find)

                self.mergeFirebaseGroupKeys(into: items, completion: completion)
            }
        }
    }

    // Android getJoinRequestGroupList 대응(가입 대기 그룹, 신청중 화면). 그룹 ID는 request 모드
    // (onclick을 '로 split)로 뽑는다. Android 결함 1(실 필터링 없이 LMS 전체를 노출)을 수정해
    // UserGroupList/{uid}에서 value==false인 키와 실제 교차 필터링한 항목만 반환한다(§3.2).
    func fetchJoinRequestGroups(offset: Int, limit: Int, completion: @escaping (Resource<[GroupItem]>) -> Void) {
        completion(.loading)
        requestGroupList(offset: offset, limit: limit) { [weak self] result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                guard let self = self else {
                    completion(.success([]))
                    return
                }
                let items = self.parseGroupSegments(from: html, idMode: .request)

                self.filterJoinRequestGroups(items, completion: completion)
            }
        }
    }

    // find/request 공통 POST — Android 두 메소드의 getBody()가 동일한 파라미터 집합(panel_id=1,
    // gubun=select_share_total, start/display/encoding)을 쓴다.
    private func requestGroupList(offset: Int, limit: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = [
            "panel_id": "1",
            "gubun": "select_share_total",
            "start": String(offset),
            "display": String(limit),
            "encoding": "utf-8"
        ]

        HttpClient.request(EndPoint.groupList, method: "POST", headers: ["Cookie": cookie], formParams: formParams, completion: completion)
    }

    // MARK: - 그룹 멤버 목록 (Task 14: Tab3View)

    // Android는 이 요청만 유일하게 Repository/DataSource 계층 없이 viewmodel.Tab3ViewModel.fetchMemberList(offset)이
    // 직접 Volley StringRequest(GET, EndPoint.MEMBER_LIST + "?CLUB_GRP_ID=..&startM=..&displayM=40")를 쏜다
    // (1차분 GroupRemoteDataSource.java에는 멤버 목록 코드가 아예 없다 — Tab3ViewModel.java에서 직접 확인했다).
    // 이 포팅은 브리프가 지시한 DataSource→Repository→ViewModel 계층 구조를 지켜 여기로 옮기되, 요청 방식은
    // Android 그대로 GET+쿼리스트링을 쓴다(리뷰 조정: 이 태스크 브리프는 GET→POST 전환을 승인하지 않았고,
    // share_member_list.acl 엔드포인트를 여기서 직접 검증할 수 없어 POST 수용 여부를 확인할 방법이 없다 —
    // 이 코드베이스에 이미 GET+쿼리스트링 전례가 있다: UserRemoteDataSource.swift의 myInfo/getUserImage
    // 요청이 같은 패턴이다). 파라미터 이름(CLUB_GRP_ID/startM/displayM)과 페이지 크기(LIMIT=40)는 Android
    // Tab3ViewModel.java 그대로. groupId는 숫자형이 보통이지만 방어적으로 쿼리 퍼센트 인코딩을 거친다.
    func fetchMembers(groupId: String, offset: Int, completion: @escaping (Resource<[MemberItem]>) -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let encodedGroupId = groupId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? groupId
        let url = "\(EndPoint.memberList)?CLUB_GRP_ID=\(encodedGroupId)&startM=\(offset)&displayM=40"

        HttpClient.request(url, method: "GET", headers: ["Cookie": cookie]) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let html):
                completion(.success(GroupRemoteDataSource.parseMembers(from: html)))
            }
        }
    }

    // MARK: - 가입신청/신청취소 (Task 2: 2차 데이터층, GroupInfoDialogView)

    // Android GroupInfoViewModel.sendRequest(TYPE_REQUEST) + insertGroupToFirebase 대응. LMS는
    // performRemoval을 그대로 재사용한다(POST CLUB_GRP_ID 1개 + JSON isError 판정 — leaveGroup/
    // deleteGroup과 동일 패턴). LMS 성공 후 key/uid가 모두 있을 때만 Firebase를 갱신한다(key==nil,
    // 즉 Firebase 미등록/미구성이면 LMS 성공만 반영하고 갱신을 생략 — 브리프 Step 4).
    // Android 결함 4(이미 멤버면 members map을 새로 비우는 버그)는 이식하지 않는다: 아래
    // runMembershipTransaction은 트랜잭션이 읽어온 현재 members 맵을 그대로 두고 uid 한 키만
    // upsert한다(map 전체를 새로 만들지 않는다).
    func registerGroup(groupId: String,
                        key: String?,
                        joinType: String,
                        fallback: GroupItem?,
                        completion: @escaping (Resource<Bool>) -> Void) {
        performRemoval(endpoint: EndPoint.registerGroup, groupId: groupId, completion: completion) { [weak self] in
            guard let self = self,
                  let key = key,
                  let uid = PreferenceManager.shared.user?.uid,
                  let root = FirebaseRef.database() else {
                return
            }
            // "0"(자동 승인) → true(즉시 정식 가입), "1"(운영자 승인) → false(승인 대기) — 스펙 §3.3.
            let isApproved = joinType == "0"

            self.runMembershipTransaction(key: key, fallback: fallback, joinType: joinType) { members in
                members[uid] = isApproved
            }
            root.child("UserGroupList").child(uid).child(key).setValue(isApproved)
        }
    }

    // Android GroupInfoViewModel.sendRequest(TYPE_CANCEL) + deleteUserInGroupFromFirebase 대응.
    // fallback 노드 생성은 신청 취소에는 의미가 없으므로(취소할 신청 자체가 없는 상태) fallback/joinType
    // 모두 nil로 트랜잭션을 호출한다 — Groups/{key}가 없으면 아무것도 만들지 않고 넘어간다.
    func cancelJoinRequest(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void) {
        performRemoval(endpoint: EndPoint.withdrawalGroup, groupId: groupId, completion: completion) { [weak self] in
            guard let self = self,
                  let key = key,
                  let uid = PreferenceManager.shared.user?.uid,
                  let root = FirebaseRef.database() else {
                return
            }
            self.runMembershipTransaction(key: key, fallback: nil, joinType: nil) { members in
                members.removeValue(forKey: uid)
            }
            root.child("UserGroupList").child(uid).child(key).removeValue()
        }
    }

    // MARK: - 탈퇴/삭제 (Task 15에서 사용)

    // Android removeGroup(isAdmin=false) 대응. key는 Android 원본과 동일하게 Firebase Groups 노드 정리에
    // 필요하다(브리프의 leaveGroup(groupId:completion:) 표기는 key가 빠져 있었으나, Android 원본이 탈퇴/삭제
    // 모두 key를 요구하므로 시그니처에 포함했다 — task-10-report.md 참고).
    func leaveGroup(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void) {
        performRemoval(endpoint: EndPoint.withdrawalGroup, groupId: groupId, completion: completion) { [weak self] in
            self?.cleanupFirebaseOnLeave(key: key)
        }
    }

    // Android removeGroup(isAdmin=true) 대응.
    func deleteGroup(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void) {
        performRemoval(endpoint: EndPoint.deleteGroup, groupId: groupId, completion: completion) { [weak self] in
            self?.cleanupFirebaseOnDelete(key: key)
        }
    }

    private func performRemoval(endpoint: String,
                                 groupId: String,
                                 completion: @escaping (Resource<Bool>) -> Void,
                                 onSuccess: @escaping () -> Void) {
        completion(.loading)
        let cookie = CookieStore.shared.cookieHeader ?? ""
        let formParams = ["CLUB_GRP_ID": groupId]

        HttpClient.request(endpoint, method: "POST", headers: ["Cookie": cookie], formParams: formParams) { result in
            switch result {
            case .failure(let error):
                completion(.error(error.localizedDescription))
            case .success(let body):
                guard let data = body.data(using: .utf8),
                      let response = try? JSONDecoder().decode(RemovalResponse.self, from: data),
                      !response.isError else {
                    completion(.error("처리에 실패했습니다."))
                    return
                }
                onSuccess()
                completion(.success(true))
            }
        }
    }

    private struct RemovalResponse: Decodable {
        let isError: Bool
    }

    // MARK: - Firebase 매핑(가입한 그룹 → key)

    private func mergeFirebaseKeys(into items: [GroupItem], completion: @escaping (Resource<[GroupItem]>) -> Void) {
        guard let uid = PreferenceManager.shared.user?.uid, let root = FirebaseRef.database() else {
            completion(.success(items))
            return
        }
        let query = root.child("UserGroupList").child(uid).queryOrderedByValue().queryEqual(toValue: true)

        query.observeSingleEvent(of: .value, with: { snapshot in
            guard snapshot.hasChildren() else {
                completion(.success(items))
                return
            }
            var keys: [String] = []

            for case let child as DataSnapshot in snapshot.children {
                keys.append(child.key)
            }
            guard !keys.isEmpty else {
                completion(.success(items))
                return
            }
            GroupRemoteDataSource.resolveKeys(keys, groupsRef: root.child("Groups"), items: items, completion: completion)
        }, withCancel: { _ in
            // Firebase 조회 실패는 부가 매핑 실패일 뿐이므로 LMS 파싱 결과만으로 성공 처리한다.
            completion(.success(items))
        })
    }

    // UserGroupList에서 찾은 각 firebase key로 Groups/{key}.id를 조회해 LMS grp_id와 매칭되면
    // 해당 GroupItem.key를 채운다(Android fetchDataTaskFromFirebase의 재귀 매칭 대응).
    private static func resolveKeys(_ keys: [String],
                                     groupsRef: DatabaseReference,
                                     items: [GroupItem],
                                     completion: @escaping (Resource<[GroupItem]>) -> Void) {
        var result = items
        var remaining = keys.count

        for key in keys {
            groupsRef.child(key).observeSingleEvent(of: .value, with: { groupSnapshot in
                if let lmsId = groupSnapshot.childSnapshot(forPath: "id").value as? String,
                   let index = result.firstIndex(where: { $0.id == lmsId }) {
                    result[index].key = key
                }
                remaining -= 1
                if remaining == 0 {
                    completion(.success(result))
                }
            }, withCancel: { _ in
                remaining -= 1
                if remaining == 0 {
                    completion(.success(result))
                }
            })
        }
    }

    // MARK: - Firebase 병합/필터 (그룹찾기/가입신청중, Task 1)

    // 그룹찾기(find) 전용 — Android initFirebaseData(List) + fetchGroupListFromFireBase 대응.
    // 가입한 그룹처럼 "내가 속한 키 목록"이 없으므로, Groups 전체를 한 번에 orderByKey로 조회해
    // (resolveKeys처럼 key마다 개별 조회하지 않는다 — 대상 후보가 모든 그룹이라 스캔이 더 싸다)
    // LMS grp_id와 일치하는 항목만 key를 채운다. Firebase 미구성/조회 실패 시 LMS 결과 그대로 성공 처리.
    private func mergeFirebaseGroupKeys(into items: [GroupItem], completion: @escaping (Resource<[GroupItem]>) -> Void) {
        guard let root = FirebaseRef.database() else {
            completion(.success(items))
            return
        }
        var result = items

        root.child("Groups").queryOrderedByKey().observeSingleEvent(of: .value, with: { snapshot in
            for case let child as DataSnapshot in snapshot.children {
                if let lmsId = child.childSnapshot(forPath: "id").value as? String,
                   let index = result.firstIndex(where: { $0.id == lmsId }) {
                    result[index].key = child.key
                }
            }
            completion(.success(result))
        }, withCancel: { _ in
            completion(.success(items))
        })
    }

    // 가입신청중(request) 전용 — Android 결함 1 수정: Android는 UserGroupList 매칭 없이 LMS 전체를
    // 그대로 노출한다(키만 있으면 교체하고 없으면 LMS id 유지). 여기서는 UserGroupList/{uid}에서
    // value==false(승인 대기)인 키만 뽑아 각 Groups/{key}.id로 LMS 목록과 실제 교차 필터링하고,
    // 매칭되지 않은 LMS 항목은 결과에서 제외한다. Firebase 미구성/uid 없음 → 빈 목록(신청중 그룹은
    // Firebase 매칭이 곧 "대기중" 판정의 유일한 근거라 LMS 결과만으로는 답할 수 없다 — §5 참고).
    private func filterJoinRequestGroups(_ items: [GroupItem], completion: @escaping (Resource<[GroupItem]>) -> Void) {
        guard let uid = PreferenceManager.shared.user?.uid, let root = FirebaseRef.database() else {
            completion(.success([]))
            return
        }
        root.child("UserGroupList").child(uid).queryOrderedByValue().queryEqual(toValue: false)
            .observeSingleEvent(of: .value, with: { snapshot in
                var keys: [String] = []

                for case let child as DataSnapshot in snapshot.children {
                    keys.append(child.key)
                }
                guard !keys.isEmpty else {
                    completion(.success([]))
                    return
                }
                var pending: [GroupItem] = []
                var remaining = keys.count
                let finish = {
                    remaining -= 1
                    if remaining == 0 {
                        completion(.success(pending.sorted { $0.name < $1.name }))
                    }
                }

                for key in keys {
                    root.child("Groups").child(key).observeSingleEvent(of: .value, with: { groupSnapshot in
                        if let lmsId = groupSnapshot.childSnapshot(forPath: "id").value as? String,
                           var item = items.first(where: { $0.id == lmsId }) {
                            item.key = key
                            pending.append(item)
                        }
                        finish()
                    }, withCancel: { _ in finish() })
                }
            }, withCancel: { _ in completion(.success([])) })
    }

    // MARK: - Firebase 정리 (탈퇴/삭제)

    // Android deleteGroupFromFirebase(isAdmin=false) 대응 — 전체 노드를 읽어 덮어쓰는 대신 members/memberCount만
    // 표적 갱신한다(전체 GroupItem을 Codable로 왕복하지 않아 다른 필드를 덮어쓸 위험이 없다).
    private func cleanupFirebaseOnLeave(key: String?) {
        guard let key = key, let uid = PreferenceManager.shared.user?.uid, let root = FirebaseRef.database() else {
            return
        }
        let groupsRef = root.child("Groups")

        groupsRef.child(key).child("members").child(uid).removeValue()
        groupsRef.child(key).observeSingleEvent(of: .value, with: { snapshot in
            if let memberCount = snapshot.childSnapshot(forPath: "memberCount").value as? Int {
                groupsRef.child(key).child("memberCount").setValue(max(0, memberCount - 1))
            }
        })
        root.child("UserGroupList").child(uid).child(key).removeValue()
    }

    // Android deleteGroupFromFirebase(isAdmin=true) 대응 — 멤버 전원의 UserGroupList 항목,
    // 그룹의 게시글/댓글, 그룹 자체를 정리한다.
    private func cleanupFirebaseOnDelete(key: String?) {
        guard let key = key, let root = FirebaseRef.database() else {
            return
        }
        let userGroupListRef = root.child("UserGroupList")
        let articlesRef = root.child("Articles")
        let groupsRef = root.child("Groups")

        groupsRef.child(key).child("members").observeSingleEvent(of: .value, with: { snapshot in
            for case let member as DataSnapshot in snapshot.children {
                userGroupListRef.child(member.key).child(key).removeValue()
            }
        })
        articlesRef.child(key).observeSingleEvent(of: .value, with: { snapshot in
            let replysRef = root.child("Replys")

            for case let article as DataSnapshot in snapshot.children {
                replysRef.child(article.key).removeValue()
            }
            articlesRef.child(key).removeValue()
            groupsRef.child(key).removeValue()
        })
    }

    // MARK: - Firebase 트랜잭션 (가입신청/신청취소, 개선 3)

    // Android insertGroupToFirebase/deleteUserInGroupFromFirebase는 addListenerForSingleValueEvent로
    // Groups/{key} 전체를 읽어 setValue로 통째 덮어쓴다 — 동시에 두 사용자가 가입/탈퇴하면 나중에 쓴
    // 쪽이 먼저 쓴 쪽의 members 변경을 지운다(레이스). 이 포팅은 개선 3(합의됨)에 따라 통째 setValue
    // 대신 runTransactionBlock으로 members/memberCount만 원자적으로 갱신한다.
    //
    // fallback은 Groups/{key} 노드가 아직 없을 때(비앱 생성 그룹 — 결함 6)만 쓰인다: 목록 화면이
    // 이미 들고 있던 GroupItem(다이얼로그 인자)으로 최소 노드를 새로 만든다. joinType은 register가
    // 넘긴 값을 우선하고, 없으면(취소 흐름 등) fallback.joinType, 그것도 없으면 "1"(승인 필요)로
    // 보수적으로 강등한다 — Task 1 이연 사항: menu_list 스코프를 못 찾으면 fallback.joinType이 nil일
    // 수 있어 여기서 한 번 더 방어한다.
    private func runMembershipTransaction(key: String,
                                           fallback: GroupItem?,
                                           joinType: String?,
                                           mutate: @escaping (inout [String: Bool]) -> Void) {
        guard let root = FirebaseRef.database() else {
            return
        }
        root.child("Groups").child(key).runTransactionBlock { currentData in
            if var group = currentData.value as? [String: Any] {
                var members = (group["members"] as? [String: Any])?
                    .compactMapValues { ($0 as? Bool) ?? ($0 as? NSNumber)?.boolValue } ?? [:]
                mutate(&members)
                group["members"] = members
                group["memberCount"] = members.count
                currentData.value = group
            } else if let fallback = fallback {
                // 비앱 생성 그룹(Firebase 미등록) — 최소 노드 생성(스펙 §2 결함 6 수정)
                var members: [String: Bool] = [:]
                mutate(&members)
                currentData.value = [
                    "admin": false,
                    "id": fallback.id,
                    "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                    "image": fallback.image,
                    "name": fallback.name,
                    "description": fallback.description_ ?? "",
                    "joinType": joinType ?? fallback.joinType ?? "1",
                    "members": members,
                    "memberCount": members.count
                ] as [String: Any]
            }
            return TransactionResult.success(withValue: currentData)
        }
    }

    // MARK: - HTML 파싱

    private static func parseJoinedGroups(from html: String) -> [GroupItem] {
        guard let anchorRegex = try? NSRegularExpression(
            pattern: "(<a\\b[^>]*>)(.*?)</a>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }
        let matches = anchorRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var items: [GroupItem] = []

        for match in matches {
            guard let openRange = Range(match.range(at: 1), in: html),
                  let innerRange = Range(match.range(at: 2), in: html) else {
                continue
            }
            let openTag = String(html[openRange])
            let innerHtml = String(html[innerRange])

            if let item = GroupRemoteDataSource.parseAnchor(openTag: openTag, innerHtml: innerHtml) {
                items.append(item)
            }
        }
        return items
    }

    // Android groupIdExtract(onclick, 3)/adminCheck(onclick) + getFirstElement(IMG)/getFirstElement(STRONG) 대응.
    // 필요한 조각(onclick의 인자 4개 이상, img src, strong 텍스트) 중 하나라도 없으면 해당 anchor만 건너뛴다.
    //
    // onclick 값은 HTML 속성(큰따옴표)로 감싸인 채 그 안에 JS 문자열 인자(작은따옴표)를 담고 있다
    // (예: onclick="javascript:fnView('0', '12345', 'GroupName');") — attribute(_:in:)는 여는/닫는
    // 따옴표 종류를 구분하지 않아 첫 내부 작은따옴표에서 잘려버리므로(전 anchor가 스킵되어 목록이
    // 통째로 비는 버그였다), 여는 따옴표 종류를 추적하는 attributeExact(_:in:)를 대신 쓴다.
    private static func parseAnchor(openTag: String, innerHtml: String) -> GroupItem? {
        guard let onclick = HtmlUtil.attributeExact("onclick", in: openTag) else {
            return nil
        }
        let parts = onclick.components(separatedBy: "'")

        guard parts.count > 3 else {
            return nil
        }
        let id = parts[3].trimmingCharacters(in: .whitespaces)

        guard !id.isEmpty else {
            return nil
        }
        let isAdmin = parts[1].trimmingCharacters(in: .whitespaces) == "0"

        guard let imgTag = GroupRemoteDataSource.firstMatch(pattern: "<img\\b[^>]*>", in: innerHtml),
              let rawSrc = HtmlUtil.attribute("src", in: imgTag) else {
            return nil
        }
        // Jericho의 getAttributeValue는 엔티티를 디코딩해 돌려준다 — HtmlUtil.attribute는 원문 그대로
        // 반환하므로 UserRemoteDataSource.parseUid와 동일하게 HtmlUtil.text로 디코딩을 보정한다.
        let src = HtmlUtil.text(rawSrc)

        guard let strongInner = GroupRemoteDataSource.firstCapturedGroup(pattern: "<strong\\b[^>]*>(.*?)</strong>", in: innerHtml) else {
            return nil
        }
        let name = HtmlUtil.text(strongInner)

        return GroupItem(
            id: id,
            key: nil,
            name: name,
            image: EndPoint.baseURL + src,
            info: nil,
            description_: nil,
            joinType: nil,
            isAdmin: isAdmin,
            author: nil,
            authorUid: nil,
            memberCount: 0,
            timestamp: nil,
            members: nil
        )
    }

    private static func firstMatch(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range, in: html) else {
            return nil
        }
        return String(html[range])
    }

    private static func firstCapturedGroup(pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[range])
    }

    // MARK: - 그룹찾기/가입신청중 HTML 파싱 (Android getNotJoinedGroupList/getJoinRequestGroupList 대응)

    // id="accordion"을 가진 여는 태그 전부를 찾아 각 매치 시작~다음 매치 시작(마지막은 문서 끝)을
    // 세그먼트로 자른다(그룹 카드 하나 = accordion 블록 하나). 이 메소드는 minId/stopRequestMore를
    // 갱신하므로 인스턴스 메소드다 — Android가 for-break로 루프를 끝내는 것과 동일하게, 순서를 벗어난
    // id를 만나면 그 항목은 버리고 나머지 세그먼트는 처리하지 않는다(break 미러).
    private func parseGroupSegments(from html: String, idMode: GroupIdParseMode) -> [GroupItem] {
        guard let openRegex = try? NSRegularExpression(
            pattern: "<[a-zA-Z0-9]+\\b[^>]*\\bid=[\"']accordion[\"'][^>]*>",
            options: [.caseInsensitive]
        ) else {
            return []
        }
        let matches = openRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))
        var items: [GroupItem] = []

        for (index, match) in matches.enumerated() {
            guard let openRange = Range(match.range, in: html) else {
                continue
            }
            let openTag = String(html[openRange])

            // Android element.getAttributeValue("class").equals("accordion") 미러 — class가
            // 정확히 "accordion"인 세그먼트만 처리한다(다른 클래스가 섞여 있으면 건너뛴다).
            guard HtmlUtil.attribute("class", in: openTag) == "accordion" else {
                continue
            }
            let segmentEnd: String.Index
            if index + 1 < matches.count, let nextRange = Range(matches[index + 1].range, in: html) {
                segmentEnd = nextRange.lowerBound
            } else {
                segmentEnd = html.endIndex
            }
            let segment = String(html[openRange.lowerBound..<segmentEnd])

            guard let item = GroupRemoteDataSource.parseGroupSegment(segment, idMode: idMode),
                  let idValue = Int(item.id) else {
                continue
            }
            minId = (minId == 0) ? idValue : min(minId, idValue)
            if idValue > minId {
                stopRequestMore = true
                break
            }
            stopRequestMore = false
            items.append(item)
        }
        return items
    }

    // 세그먼트 하나(accordion 블록)를 GroupItem으로 변환. 그룹 ID는 idMode에 따라 onclick을
    // 다르게 split한다(파일 헤더 코멘트 참고) — Int 변환 실패 또는 인덱스 부족 시 nil을 돌려줘
    // parseGroupSegments가 해당 세그먼트만 건너뛰게 한다(parseAnchor와 동일한 원칙).
    private static func parseGroupSegment(_ segment: String, idMode: GroupIdParseMode) -> GroupItem? {
        guard let buttonTag = GroupRemoteDataSource.allTags(withAttribute: "class", equalTo: "button", in: segment).first,
              let onclick = HtmlUtil.attributeExact("onclick", in: buttonTag) else {
            return nil
        }
        let rawId: String

        switch idMode {
        case .find:
            // Android groupIdExtract(onclick): onclick.split("[(]|[)]|[,]")[1].trim()
            let parts = onclick.components(separatedBy: CharacterSet(charactersIn: "(),"))

            guard parts.count > 1 else {
                return nil
            }
            rawId = parts[1].trimmingCharacters(in: .whitespaces)
        case .request:
            // Android groupIdExtract(onclick, 1): onclick.split("'")[1].trim()
            let parts = onclick.components(separatedBy: "'")

            guard parts.count > 1 else {
                return nil
            }
            rawId = parts[1].trimmingCharacters(in: .whitespaces)
        }
        guard let idValue = Int(rawId) else {
            return nil
        }
        guard let imgTag = GroupRemoteDataSource.firstMatch(pattern: "<img\\b[^>]*>", in: segment),
              let rawSrc = HtmlUtil.attribute("src", in: imgTag) else {
            return nil
        }
        let src = HtmlUtil.text(rawSrc)

        guard let strongInner = GroupRemoteDataSource.firstCapturedGroup(pattern: "<strong\\b[^>]*>(.*?)</strong>", in: segment) else {
            return nil
        }
        let name = HtmlUtil.text(strongInner)

        // description/joinType 스코프: Android menuList.getAllElementsByClass("info") 대응.
        // menuListInfoTexts(in:) 코멘트 참고 — 부족하면(요소가 없거나 1개뿐이면) 해당 필드만 nil.
        let menuListTexts = GroupRemoteDataSource.menuListInfoTexts(in: segment)
        let description = menuListTexts.first
        var joinType: String?

        if menuListTexts.count > 1 {
            let joinTypeText = menuListTexts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            joinType = joinTypeText == "가입방식: 자동 승인" ? "0" : "1"
        }

        // info 문자열 스코프: Android element.getFirstElement(A).getAllElementsByClass("info") 대응.
        // anchorInfoTexts(in:) 코멘트 참고 — 스코프를 못 찾으면 빈 배열이라 info는 자연히 "".
        let anchorTexts = GroupRemoteDataSource.anchorInfoTexts(in: segment)
        var info = ""

        for text in anchorTexts {
            if text.contains("회원수"), let range = text.range(of: "생성일", options: .backwards) {
                info += String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
            } else {
                info += text + "\n"
            }
        }

        return GroupItem(
            id: String(idValue),
            key: nil,
            name: name,
            image: EndPoint.baseURL + src,
            info: info.trimmingCharacters(in: .whitespacesAndNewlines),
            description_: description,
            joinType: joinType,
            isAdmin: false,
            author: nil,
            authorUid: nil,
            memberCount: 0,
            timestamp: nil,
            members: nil
        )
    }

    // description/joinType 서브세그먼트 — Android menuList.getAllElementsByClass("info") 대응.
    // HtmlUtil에는 getFirstElementByClass 같은 DOM 스코프 검색이 없어서, accordion 세그먼트를 자를
    // 때와 같은 관례로 class="menu_list" 여는 태그의 시작 위치부터 세그먼트 끝까지를 서브세그먼트로
    // 삼는다(닫는 태그를 찾지 않는다 — 카드 하나에 menu_list 뒤로 다른 형제 블록이 이어지지 않는
    // 마크업을 전제한다). 못 찾으면 빈 배열(호출부가 description_/joinType을 nil로 강등).
    private static func menuListInfoTexts(in segment: String) -> [String] {
        guard let menuListStart = GroupRemoteDataSource.firstMatchRange(
            pattern: "<[a-zA-Z0-9]+\\b[^>]*\\bclass=[\"']menu_list[\"'][^>]*>",
            in: segment
        )?.lowerBound else {
            return []
        }
        return GroupRemoteDataSource.infoTexts(in: String(segment[menuListStart...]))
    }

    // info 문자열 서브세그먼트 — Android element.getFirstElement(A).getAllElementsByClass("info")
    // 대응. 세그먼트 안 첫 <a>...</a> 블록 내부만 본다(parseJoinedGroups의 anchor 캡처 그룹 패턴
    // 재사용). 닫는 </a>를 못 찾으면(마크업 변형) 첫 <a 여는 태그 위치부터 세그먼트 끝까지로
    // 폴백한다 — menu_list와 같은 위치-슬라이싱 관례. 첫 <a 자체가 없으면 빈 배열(info는 "").
    private static func anchorInfoTexts(in segment: String) -> [String] {
        if let anchorInner = GroupRemoteDataSource.firstCapturedGroup(pattern: "<a\\b[^>]*>(.*?)</a>", in: segment) {
            return GroupRemoteDataSource.infoTexts(in: anchorInner)
        }
        guard let anchorStart = GroupRemoteDataSource.firstMatchRange(pattern: "<a\\b[^>]*>", in: segment)?.lowerBound else {
            return []
        }
        return GroupRemoteDataSource.infoTexts(in: String(segment[anchorStart...]))
    }

    // firstMatch(pattern:in:)의 "매치된 문자열"이 아니라 "매치 위치(Range)"가 필요한 경우용 —
    // menuListInfoTexts/anchorInfoTexts의 위치-슬라이싱 폴백에 쓴다.
    private static func firstMatchRange(pattern: String, in html: String) -> Range<String.Index>? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)) else {
            return nil
        }
        return Range(match.range, in: html)
    }

    // class="info" 요소들의 텍스트를 문서 순서대로 반환 — menuListInfoTexts/anchorInfoTexts가 이미
    // 스코프를 좁힌 서브세그먼트를 넘겨준다는 전제다(이 함수 자체는 스코프를 모른다). elementById와
    // 같은 한계로 태그가 중첩되면 닫는 태그 짝이 정확하지 않을 수 있다.
    private static func infoTexts(in segment: String) -> [String] {
        let pattern = "<([a-zA-Z0-9]+)\\b[^>]*\\bclass=[\"']info[\"'][^>]*>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let matches = regex.matches(in: segment, range: NSRange(segment.startIndex..., in: segment))
        var texts: [String] = []

        for match in matches {
            guard let tagNameRange = Range(match.range(at: 1), in: segment),
                  let openRange = Range(match.range, in: segment) else {
                continue
            }
            let tagName = String(segment[tagNameRange])
            let closeTag = "</\(tagName)>"

            guard let closeRange = segment.range(of: closeTag,
                                                  options: [.caseInsensitive],
                                                  range: openRange.upperBound..<segment.endIndex) else {
                continue
            }
            texts.append(HtmlUtil.text(String(segment[openRange.upperBound..<closeRange.lowerBound])))
        }
        return texts
    }

    // MARK: - 멤버 목록 HTML 파싱 (Android Tab3ViewModel.fetchMemberList try 블록 대응)

    // Android는 id="member_list" 컨테이너 안에서 서로 다른 3개 셀렉터로 각각 배열을 얻은 뒤(체크박스
    // input[name=memberIdCheck], img[title=프로필], 컨테이너 전체의 모든 span) "같은 인덱스 = 같은 멤버 행"
    // 이라고 가정하고 zip한다(getAllElements(name, "memberIdCheck", false) / getAllElements(title, "프로필",
    // false) / getAllElements(HTMLElementName.SPAN)). 세 배열의 길이가 어긋나면(예: 멤버 행과 무관한 span이
    // 컨테이너 안에 더 있으면) 조용히 어긋난 데이터가 만들어지는 취약한 구조이지만, 이 포팅은 Android 파싱
    // 로직을 그대로 미러하는 것이 브리프 목표이므로 동일한 인덱스 정렬 방식을 쓴다. 다만 Android는 인덱스
    // 불일치 시 catch(NullPointerException)로도 못 잡는 IndexOutOfBoundsException으로 전체 파싱이 죽을 수
    // 있는데(onclick 파싱과 같은 기존 버그 패턴), 여기서는 parseAnchor와 같은 원칙으로 개별 인덱스만
    // 건너뛴다. stuNum/dept/div/regDate는 Android도 이 경로에서는 채우지 않는(3-인자 MemberItem 생성자만
    // 쓰는) 필드라 nil로 둔다 — UserDialogView가 옵셔널 nil-safe 처리해야 하는 이유이기도 하다.
    //
    // Android는 이 try 블록에서 getFirstElementByClass("paging")의 "현재 선택 목록" 타이틀도 함께 추출하지만
    // (`page` 지역변수), 그 값을 이후 어디에도 쓰지 않는 죽은 코드다 — 여기서는 의도적으로 이식하지 않는다.
    private static func parseMembers(from html: String) -> [MemberItem] {
        guard let container = HtmlUtil.elementById("member_list", in: html) else {
            return []
        }
        let inputTags = GroupRemoteDataSource.allTags(withAttribute: "name", equalTo: "memberIdCheck", in: container)
        let imgTags = GroupRemoteDataSource.allTags(withAttribute: "title", equalTo: "프로필", in: container)
        let names = HtmlUtil.cells(in: container, tag: "span")
        var items: [MemberItem] = []

        for i in 0..<inputTags.count {
            guard i < imgTags.count, i < names.count,
                  let rawSrc = HtmlUtil.attribute("src", in: imgTags[i]),
                  let uid = GroupRemoteDataSource.extractUid(fromImageSrc: HtmlUtil.text(rawSrc)),
                  let value = HtmlUtil.attribute("value", in: inputTags[i]) else {
                continue
            }
            items.append(MemberItem(uid: uid, name: names[i], value: value, stuNum: nil, dept: nil, div: nil, regDate: nil))
        }
        return items
    }

    // Android "imageUrl.substring(imageUrl.indexOf("id=") + "id=".length(), imageUrl.lastIndexOf("&ext"))"
    // 그대로 — EndPoint.userImage(uid:)가 만드는 "...user_image_view.acl?id={uid}&ext=.jpg" 형태를 역파싱한다.
    private static func extractUid(fromImageSrc src: String) -> String? {
        guard let idRange = src.range(of: "id="),
              let extRange = src.range(of: "&ext", options: .backwards),
              idRange.upperBound <= extRange.lowerBound else {
            return nil
        }
        return String(src[idRange.upperBound..<extRange.lowerBound])
    }

    // HtmlUtil에는 없는 "임의 태그 중 특정 속성=값을 가진 여는 태그 전부"를 찾는 로컬 헬퍼(HtmlUtil.blocks는
    // 닫는 태그를 요구해 self-closing input에는 쓸 수 없고, attribute류는 이미 찾은 태그 문자열 안에서
    // 속성값만 읽는다) — memberIdCheck 체크박스와 title=프로필 이미지 태그 조회에 함께 쓴다.
    private static func allTags(withAttribute name: String, equalTo value: String, in html: String) -> [String] {
        let pattern = "<[a-zA-Z0-9]+\\b[^>]*\\b\(name)=[\"']\(NSRegularExpression.escapedPattern(for: value))[\"'][^>]*>"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let matches = regex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        return matches.compactMap { match in
            guard let range = Range(match.range, in: html) else {
                return nil
            }
            return String(html[range])
        }
    }
}
