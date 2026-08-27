//
//  ChatRemoteDataSource.swift
//  YuMinigroup
//
//  Android data/remote/ChatRemoteDataSource.java 대응 — Firebase Realtime Database "Messages" 노드
//  CRUD/관찰. 경로 규약(스펙 §3.5): 그룹은 Messages/{groupKey}/{pushId}, 1:1은
//  Messages/{내uid}/{상대uid}/{pushId}이고 전송 시 Messages/{상대uid}/{내uid}/{pushId}에도 동일
//  pushId로 원자 미러 기록한다.
//
//  FirebaseRef.database()가 nil(GoogleService-Info.plist 미구성)이면 조회는 빈 배열/nil로,
//  관찰/전송은 아무 것도 하지 않고 nil을 돌려준다 — GroupRemoteDataSource와 동일한 무병합 관례.
//
//  updateChildren(Android/Web API명)은 Firebase iOS SDK에서 updateChildValues다(GroupRemoteDataSource.
//  insertGroupToFirebase, 자매 KnuMiniGroup-iOS ChatRemoteDataSource.sendMessage와 동일 선례) —
//  1:1 전송의 양쪽 경로 원자 기록에 이 API를 쓴다.
//
//  observeNewMessages/removeObserver는 같은 threadRef(경로만, 쿼리 필터 없이)로 handle을 등록/해제한다
//  (KnuMiniGroup-iOS가 필터 적용 전 bare reference를 저장해두고 그 reference로 removeObserver를 호출하는
//  것과 동일한 원리 — Firebase 리스너 해제는 핸들이 등록된 경로 노드 기준이라 쿼리 필터(queryStarting 등)
//  유무와 무관하게 같은 경로의 참조면 충분하다). afterKey가 있으면 queryStarting(atValue:)를 쓰는데
//  이는 inclusive라 재생분(afterKey 자신)이 다시 올 수 있다 — 호출부(Task 8, ChatViewModel)가 key로
//  중복 제거한다(스펙 §3.5 "전송: ... childAdded 수신분과 key로 중복 제거").
//
//  Task 10: fetchChatRooms(ChatListView 전용, Android에 없는 신설 화면 — 스펙 §3.6)를 추가한다.
//  그룹채팅방(UserGroupList equalTo(true) 병합)과 1:1(Messages/{uid} 1회 조회)을 DispatchGroup
//  fan-in으로 병합한다 — GroupRemoteDataSource.resolveKeys/filterJoinRequestGroups의 remaining
//  카운터 관례를 그대로 재사용한다(파일 하단 "MARK: - 채팅방 목록" 참고).
//

import Foundation
import FirebaseDatabase

final class ChatRemoteDataSource {
    var isAvailable: Bool {
        FirebaseRef.isConfigured
    }

    // key 오름차순(오래된→최신) 반환. cursor 있으면 endAt(cursor) — inclusive라 호출부가 중복 제거.
    func fetchMessages(currentUid: String,
                        receiver: String,
                        isGroupChat: Bool,
                        cursor: String?,
                        limit: Int,
                        completion: @escaping (Result<[MessageItem], Error>) -> Void) {
        guard let ref = threadRef(currentUid: currentUid, receiver: receiver, isGroupChat: isGroupChat) else {
            completion(.success([]))
            return
        }
        var query: DatabaseQuery = ref.queryOrderedByKey()

        if let cursor = cursor {
            query = query.queryEnding(atValue: cursor)
        }
        query = query.queryLimited(toLast: UInt(limit))

        query.observeSingleEvent(of: .value, with: { snapshot in
            var items: [MessageItem] = []

            for case let child as DataSnapshot in snapshot.children {
                if let item = ChatRemoteDataSource.decode(child) {
                    items.append(item)
                }
            }
            completion(.success(items))
        }, withCancel: { error in
            completion(.failure(error))
        })
    }

    // afterKey 있으면 queryStarting(atValue:) — inclusive 재생분은 호출부가 key로 중복 제거. 미구성 시 nil.
    func observeNewMessages(currentUid: String,
                             receiver: String,
                             isGroupChat: Bool,
                             afterKey: String?,
                             onMessage: @escaping (MessageItem) -> Void) -> UInt? {
        guard let ref = threadRef(currentUid: currentUid, receiver: receiver, isGroupChat: isGroupChat) else {
            return nil
        }
        let query: DatabaseQuery

        if let afterKey = afterKey {
            query = ref.queryOrderedByKey().queryStarting(atValue: afterKey)
        } else {
            query = ref
        }

        // Firebase 콜백은 메인 큐에서 호출되므로 별도 디스패치 없이 그대로 onMessage에 전달한다.
        return query.observe(.childAdded, with: { snapshot in
            if let item = ChatRemoteDataSource.decode(snapshot) {
                onMessage(item)
            }
        })
    }

    func removeObserver(currentUid: String, receiver: String, isGroupChat: Bool, handle: UInt) {
        guard let ref = threadRef(currentUid: currentUid, receiver: receiver, isGroupChat: isGroupChat) else {
            return
        }
        ref.removeObserver(withHandle: handle)
    }

    // push 선발급 key로 만든 로컬 MessageItem 반환(미구성/uid 없음 → nil). 1:1은 양쪽 경로 원자 미러 기록.
    @discardableResult
    func sendMessage(user: User, receiver: String, isGroupChat: Bool, text: String) -> MessageItem? {
        guard let root = FirebaseRef.database(), let uid = user.uid else { return nil }
        let messagesRef = root.child("Messages")
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let map: [String: Any] = ["from": uid, "name": user.name ?? "", "message": text,
                                  "type": "text", "seen": false, "timestamp": timestamp]

        if isGroupChat {
            let ref = messagesRef.child(receiver).childByAutoId()

            guard let key = ref.key else { return nil }
            ref.setValue(map)
            return MessageItem(key: key, from: uid, name: user.name ?? "", message: text,
                               type: "text", seen: false, timestamp: timestamp)
        }
        // 최종 리뷰 수정(Finding 2) — receiver == uid(자기 자신에게 1:1 전송)면 아래
        // updateChildValues 딕셔너리 리터럴의 두 키("\(receiver)/\(uid)/\(pushId)"와
        // "\(uid)/\(receiver)/\(pushId)")가 같은 문자열이 되어 런타임 트랩이 난다. 평소엔 UI가
        // isSelf로 이 진입 자체를 막지만, 레거시 Messages/{uid}/{uid} 스레드가 채팅 목록에 노출되면
        // 이 경로에 도달할 수 있어 방어적으로 조용히 실패 처리한다.
        guard receiver != uid else { return nil }
        guard let pushId = messagesRef.child(uid).child(receiver).childByAutoId().key else { return nil }
        messagesRef.updateChildValues(["\(receiver)/\(uid)/\(pushId)": map,   // 상대 쪽
                                        "\(uid)/\(receiver)/\(pushId)": map])  // 내 쪽 — 동일 pushId 원자 미러
        return MessageItem(key: pushId, from: uid, name: user.name ?? "", message: text,
                           type: "text", seen: false, timestamp: timestamp)
    }

    // MARK: - 채팅방 목록 (Task 10, ChatListView 전용 조회 — 스펙 §3.6)

    // 그룹채팅방(UserGroupList equalTo(true) 병합)과 1:1(Messages/{uid} 1회 조회)을 DispatchGroup으로
    // 병렬 조회한 뒤 정렬해 돌려준다. Firebase 미구성/uid 없음이면 조회 자체를 생략하고 .success([])
    // (Android는 이 화면이 아예 없으므로 대응 원본 없음 — 스펙 §3.6이 원전).
    func fetchChatRooms(currentUid: String, completion: @escaping (Result<[ChatRoomItem], Error>) -> Void) {
        guard let root = FirebaseRef.database() else {
            completion(.success([]))
            return
        }
        let group = DispatchGroup()
        var groupRooms: [ChatRoomItem] = []
        var directRooms: [ChatRoomItem] = []

        group.enter()
        ChatRemoteDataSource.fetchGroupChatRooms(root: root, currentUid: currentUid) { rooms in
            groupRooms = rooms
            group.leave()
        }

        group.enter()
        ChatRemoteDataSource.fetchDirectChatRooms(root: root, currentUid: currentUid) { rooms in
            directRooms = rooms
            group.leave()
        }

        // 두 갈래 콜백 모두 정확히 한 번씩만 group.leave()를 호출하므로(각 하위 헬퍼가 성공/취소
        // 경로 모두에서 completion을 정확히 1회 호출하도록 짜여 있다) notify는 정확히 한 번만 실행된다.
        group.notify(queue: .main) {
            completion(.success(ChatRemoteDataSource.sortRooms(groupRooms + directRooms)))
        }
    }

    // UserGroupList/{uid}에서 value==true인 key들 → 각 key마다 Groups/{key}(이름·이미지)와
    // Messages/{key}의 마지막 메시지(limitToLast(1))를 순차 조회해 합친다. 순서는 입력 keys 순서를
    // 유지한다(fan-in 완료 순서가 아니라 dictionary에 key로 적재 후 keys 순회로 복원 — 정렬은
    // sortRooms가 최종적으로 다시 하므로 이 순서 자체는 결과에 영향 없다).
    private static func fetchGroupChatRooms(root: DatabaseReference,
                                             currentUid: String,
                                             completion: @escaping ([ChatRoomItem]) -> Void) {
        root.child("UserGroupList").child(currentUid).queryOrderedByValue().queryEqual(toValue: true)
            .observeSingleEvent(of: .value, with: { snapshot in
                var keys: [String] = []

                for case let child as DataSnapshot in snapshot.children {
                    keys.append(child.key)
                }
                guard !keys.isEmpty else {
                    completion([])
                    return
                }
                var rooms: [String: ChatRoomItem] = [:]
                var remaining = keys.count
                let finish = {
                    remaining -= 1
                    if remaining == 0 {
                        completion(keys.compactMap { rooms[$0] })
                    }
                }

                for key in keys {
                    ChatRemoteDataSource.fetchGroupRoom(root: root, key: key) { room in
                        rooms[key] = room
                        finish()
                    }
                }
            }, withCancel: { _ in completion([]) })
    }

    // 한 그룹 key에 대해 이름/이미지(Groups/{key})와 마지막 메시지(Messages/{key} limitToLast(1))를
    // 채운 ChatRoomItem 하나를 만든다. 두 단계 모두 성공/취소 경로에서 정확히 한 번만 completion을
    // 부른다(Groups 조회 실패 시 이름은 key로 강등, Messages 조회 실패/없음 시 preview/timestamp는 nil).
    private static func fetchGroupRoom(root: DatabaseReference, key: String, completion: @escaping (ChatRoomItem) -> Void) {
        root.child("Groups").child(key).observeSingleEvent(of: .value, with: { groupSnapshot in
            let name = groupSnapshot.childSnapshot(forPath: "name").value as? String ?? key
            let image = groupSnapshot.childSnapshot(forPath: "image").value as? String

            root.child("Messages").child(key).queryOrderedByKey().queryLimited(toLast: 1)
                .observeSingleEvent(of: .value, with: { messagesSnapshot in
                    var preview: String?
                    var timestamp: Int64?

                    for case let child as DataSnapshot in messagesSnapshot.children {
                        preview = child.childSnapshot(forPath: "message").value as? String
                        timestamp = (child.childSnapshot(forPath: "timestamp").value as? NSNumber)?.int64Value
                    }
                    completion(ChatRoomItem(receiver: key, isGroupChat: true, title: name, imageURL: image, preview: preview, timestamp: timestamp))
                }, withCancel: { _ in
                    completion(ChatRoomItem(receiver: key, isGroupChat: true, title: name, imageURL: image, preview: nil, timestamp: nil))
                })
        }, withCancel: { _ in
            completion(ChatRoomItem(receiver: key, isGroupChat: true, title: key, imageURL: nil, preview: nil, timestamp: nil))
        })
    }

    // Messages/{uid} 전체를 1회 조회 — 자식(key=상대 uid) 하나가 스레드 하나다. 이미 전체가 메모리에
    // 있으므로 스레드마다 추가 네트워크 조회 없이 로컬에서만 마지막 메시지/상대 이름을 뽑는다(스펙
    // §3.6 "전체 1회 조회"). 자식 순서는 Firebase 기본 정렬(명시 orderBy가 없으면 key 오름차순 —
    // push key는 시간순으로 정렬되도록 설계돼 있어 fetchMessages의 queryOrderedByKey()와 동일한
    // 시간순을 별도 쿼리 없이도 얻는다)에 의존한다.
    private static func fetchDirectChatRooms(root: DatabaseReference,
                                              currentUid: String,
                                              completion: @escaping ([ChatRoomItem]) -> Void) {
        root.child("Messages").child(currentUid).observeSingleEvent(of: .value, with: { snapshot in
            var rooms: [ChatRoomItem] = []

            for case let threadSnapshot as DataSnapshot in snapshot.children {
                let otherUid = threadSnapshot.key
                var messages: [DataSnapshot] = []

                for case let messageSnapshot as DataSnapshot in threadSnapshot.children {
                    messages.append(messageSnapshot)
                }
                guard let lastMessage = messages.last else {
                    continue
                }
                let preview = lastMessage.childSnapshot(forPath: "message").value as? String
                let timestamp = (lastMessage.childSnapshot(forPath: "timestamp").value as? NSNumber)?.int64Value

                // 뒤에서부터 최대 10건만 역순 탐색해 from != currentUid(상대가 보낸)인 첫 메시지의
                // name을 상대 이름으로 삼는다 — 없으면(최근 10건이 전부 내가 보낸 메시지) uid로 강등.
                var title = otherUid
                let floor = max(0, messages.count - 10)

                for index in stride(from: messages.count - 1, through: floor, by: -1) {
                    guard let from = messages[index].childSnapshot(forPath: "from").value as? String, from != currentUid else {
                        continue
                    }
                    title = messages[index].childSnapshot(forPath: "name").value as? String ?? otherUid
                    break
                }
                rooms.append(ChatRoomItem(receiver: otherUid, isGroupChat: false, title: title,
                                           imageURL: EndPoint.userImage(uid: otherUid), preview: preview, timestamp: timestamp))
            }
            completion(rooms)
        }, withCancel: { _ in completion([]) })
    }

    // 정렬: timestamp 내림차순, nil(마지막 메시지 없는 그룹채팅방)은 뒤로 보내되 이름 오름차순(스펙 §3.6).
    // 동일 timestamp를 가진 항목끼리도 이름 오름차순으로 묶어 정렬 결과가 매 호출 안정적이게 한다.
    private static func sortRooms(_ rooms: [ChatRoomItem]) -> [ChatRoomItem] {
        rooms.sorted { lhs, rhs in
            switch (lhs.timestamp, rhs.timestamp) {
            case let (l?, r?):
                return l != r ? l > r : lhs.title < rhs.title
            case (nil, nil):
                return lhs.title < rhs.title
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }
    }

    // MARK: - 경로 헬퍼 + 디코드

    private func threadRef(currentUid: String, receiver: String, isGroupChat: Bool) -> DatabaseReference? {
        guard let root = FirebaseRef.database() else { return nil }
        let messages = root.child("Messages")
        return isGroupChat ? messages.child(receiver) : messages.child(currentUid).child(receiver)
    }

    private static func decode(_ snapshot: DataSnapshot) -> MessageItem? {
        guard let dict = snapshot.value as? [String: Any],
              let from = dict["from"] as? String,
              let message = dict["message"] as? String else {
            return nil
        }
        return MessageItem(key: snapshot.key,
                           from: from,
                           name: dict["name"] as? String ?? "",
                           message: message,
                           type: dict["type"] as? String ?? "text",
                           seen: (dict["seen"] as? Bool) ?? (dict["seen"] as? NSNumber)?.boolValue ?? false,
                           timestamp: (dict["timestamp"] as? NSNumber)?.int64Value ?? 0)
    }
}
