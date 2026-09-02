//
//  ChatListViewModel.swift
//  YuMinigroup
//
//  Task 10: 채팅방 목록(신설, Android에 없는 화면) — ChatListView 전용 상태. Android 원본이 없어
//  대응 파일도 없다(스펙 §4.5가 원전). ChatRoomItem은 이 화면 전용 표시 모델이라 여기 선언한다
//  (GroupItem/MessageItem처럼 Dto/에 두지 않는다 — 브리프 지시).
//
//  init()이 즉시 fetchRooms()를 호출하고, ChatListView.onAppear도 재진입 새로고침을 위해 fetchRooms()를
//  다시 부른다(1차 재진입 새로고침 관례, GroupListContent/FindGroupView 계열과 동일 취지). 두 호출이
//  겹쳐 매 등장마다 조회가 중복 발사되지 않도록, View 쪽(ChatListView)이 "최초 onAppear는 건너뛰고
//  그 다음부터만 fetchRooms()를 부르는" 가드를 갖는다 — 이 파일이 아니라 ChatListView.swift의 몫이다
//  (VM은 단순히 "부르면 조회한다"만 책임진다).
//

import Foundation

// 화면 전용 표시 모델 — Firebase 원본 스키마가 아니라 그룹/1:1을 한 목록으로 합친 뒤의 결과 형태다.
struct ChatRoomItem: Identifiable, Hashable {
    var id: String { receiver }
    let receiver: String        // 그룹 Firebase key 또는 상대 uid
    let isGroupChat: Bool
    let title: String           // 그룹 이름 또는 상대 이름(모르면 uid)
    let imageURL: String?       // 그룹 이미지 or EndPoint.userImage(uid:)
    let preview: String?        // 마지막 메시지
    let timestamp: Int64?       // 마지막 메시지 시각(millis)
}

final class ChatListViewModel: ObservableObject {
    struct State {
        var rooms: [ChatRoomItem] = []
        var isLoading = false
        var message: String?
    }

    @Published var state = State()

    private let repository: ChatRepository

    init(repository: ChatRepository = ChatRepository()) {
        self.repository = repository
        fetchRooms()
    }

    // ChatViewModel.isChatAvailable과 동일 기준(Firebase 미구성/로그인 사용자 없음 → 사용 불가) —
    // receiver 개념이 없는 목록 화면이라 그 조건만 뺐다.
    var isChatAvailable: Bool {
        repository.isAvailable && PreferenceManager.shared.user?.uid != nil
    }

    func fetchRooms() {
        guard let uid = PreferenceManager.shared.user?.uid, repository.isAvailable else {
            state.rooms = []
            return
        }
        state.isLoading = true
        repository.fetchChatRooms(currentUid: uid) { [weak self] result in
            guard let self = self else {
                return
            }
            self.state.isLoading = false
            switch result {
            case .success(let rooms):
                self.state.rooms = rooms
            case .failure(let error):
                self.state.message = error.localizedDescription
            }
        }
    }
}
