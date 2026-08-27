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
        guard let pushId = messagesRef.child(uid).child(receiver).childByAutoId().key else { return nil }
        messagesRef.updateChildValues(["\(receiver)/\(uid)/\(pushId)": map,   // 상대 쪽
                                        "\(uid)/\(receiver)/\(pushId)": map])  // 내 쪽 — 동일 pushId 원자 미러
        return MessageItem(key: pushId, from: uid, name: user.name ?? "", message: text,
                           type: "text", seen: false, timestamp: timestamp)
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
