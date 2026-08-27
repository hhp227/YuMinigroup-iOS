//
//  ChatViewModel.swift
//  YuMinigroup
//
//  Android viewmodel/ChatViewModel.java 대응 — 채팅 화면(그룹/1:1 공용)의 상태. Android는
//  RecyclerView.OnScrollListener + LinearLayoutManager.scrollToPositionWithOffset으로 스크롤을
//  명령했지만, SwiftUI에는 그 자리에 ScrollCommand(Equatable, UUID token 포함)를 흘려보내
//  ChatView가 .onChange(of:)로 받아 ScrollViewReader.scrollTo를 호출하게 한다(같은 key로 다시
//  스크롤해야 하는 경우에도 onChange가 재발화하도록 token을 매번 새로 발급한다).
//
//  fetchMessages(previousCount:previousCursor:)의 성공 처리(onFetchSuccess)는 Android
//  fetchMessageList의 onSuccess 로직(insertPosition/firstMessageKey/addedCount)을 그대로 옮기되,
//  knownKeys(Set<String>)로 낙관적 전송분/childAdded 재생분과의 key 중복을 추가로 걸러낸다(스펙 §3.5
//  개선 2 — Android는 이 중복 제거가 없다).
//
//  isChatAvailable은 Android의 "mReceiver != null"보다 엄격하다 — Firebase 미구성(repository.isAvailable
//  false)이거나 로그인 사용자의 uid가 없으면 애초에 화면을 못 쓰게 막는다(스펙 §4.4 "Firebase
//  미구성이면... 채팅을 사용할 수 없습니다").
//
//  startObserving()은 초기 로드(fetchMessages(previousCount: 0, ...))가 끝나기 전에 호출될 수 있다
//  (ChatView.onAppear는 SwiftUI 뷰 마운트와 거의 동시에 발화하는 반면, Firebase 콜백은 네트워크/캐시
//  라운드트립 뒤라 보통 더 늦다). 이때 곧바로 observeNewMessages(afterKey: state.messages.last?.key)를
//  부르면 messages가 아직 비어 있어 afterKey가 nil이 되고, ChatRemoteDataSource가 필터 없는 bare
//  reference로 childAdded를 붙이게 된다 — Firebase의 childAdded는 리스너 부착 시 기존 자식 전체를
//  즉시 재생하므로, 대화방 전체 이력이 한 번에 밀려들어와 LIMIT=15 페이징이 사실상 무력화된다(스펙
//  §3.5 "초기 로드 후" 전제 위반). 그래서 isInitialLoadComplete/isObservingRequested 두 플래그로 실제
//  observeNewMessages 호출을 초기 로드 완료 시점까지 미룬다 — startObserving/stopObserving의 시그니처와
//  ChatView 호출부(onAppear/onDisappear)는 브리프 그대로다.
//
//  Task 12(3차): isInitialLoadComplete는 초기 로드가 "성공"했을 때만 true가 된다(fetchMessages의
//  .success 분기). 실패 시에도 무조건 완료 처리하면 messages가 여전히 비어 있는 채로 afterKey가
//  nil이 되어 위와 같은 전체 재생 문제가 실패 케이스에서도 그대로 발생하므로, 실패 시에는 관찰을
//  보류하고 재진입(화면 재생성)으로 초기 로드가 다시 성공할 때까지 기다린다. 실패 토스트는 기존대로
//  노출한다.
//

import Foundation

final class ChatViewModel: ObservableObject {
    struct ScrollCommand: Equatable {
        enum Kind: Equatable {
            case forceBottom    // 초기 로드 완료 / 내가 보낸 메시지
            case softBottom     // 실시간 수신 — 바닥 근처일 때만 스크롤
            case preserveTop    // 이전 페이지 로드 — 기존 첫 항목 위치로 보정
        }

        let kind: Kind
        let key: String    // 스크롤 기준 메시지 key
        let token: UUID     // 값이 같아도 onChange가 재발화하도록 매번 새로 발급
    }

    struct State {
        var messages: [MessageItem] = []
        var message: String?             // 토스트
        var scrollCommand: ScrollCommand?
    }

    @Published var state = State()
    @Published var inputMessage = ""

    let receiver: String?
    let isGroupChat: Bool
    let chatName: String

    private static let limit = 15

    private var cursor: String?
    private var firstMessageKey: String?
    private var hasRequestedMore = false
    private var knownKeys = Set<String>()      // 낙관적 전송/childAdded 재생분 중복 제거(개선 2)
    private var observerHandle: UInt?
    private var isInitialLoadComplete = false  // 초기 로드 완료 전 observeNewMessages 지연(위 헤더 코멘트)
    private var isObservingRequested = false

    private let repository: ChatRepository

    init(receiver: String?, isGroupChat: Bool, chatName: String, repository: ChatRepository = ChatRepository()) {
        self.receiver = receiver
        self.isGroupChat = isGroupChat
        self.chatName = chatName
        self.repository = repository
        if isChatAvailable {
            fetchMessages(previousCount: 0, previousCursor: nil)
        } else {
            isInitialLoadComplete = true   // 애초에 로드할 게 없으니 지연 없이 바로 완료 처리
        }
    }

    // Android "mReceiver != null" 대응 확장 — Firebase 미구성/로그인 사용자 없음도 함께 막는다.
    var isChatAvailable: Bool {
        receiver != nil && repository.isAvailable && PreferenceManager.shared.user?.uid != nil
    }

    // Android ChatActivity.onCreate의 액션바 타이틀 조립 대응.
    var navigationTitle: String {
        chatName + (isGroupChat ? " 그룹채팅방" : "")
    }

    // Android ChatViewModel.fetchPreviousPage() 대응 — 커서 없거나 이미 요청 중이면 무시.
    func fetchPreviousPage() {
        guard !hasRequestedMore, cursor != nil else {
            return
        }
        let previousCursor = cursor

        hasRequestedMore = true
        fetchMessages(previousCount: state.messages.count, previousCursor: previousCursor)
        cursor = nil
    }

    // Android ChatViewModel.actionSend() 대응 — 검증 순서(빈 입력 → 대상 없음 → 전송 불가)까지 동일.
    func actionSend() {
        let trimmed = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            state.message = "메시지를 입력하세요."
            return
        }
        guard let receiver = receiver else {
            state.message = "채팅 대상 정보가 없습니다."
            return
        }
        guard let user = PreferenceManager.shared.user,
              let sent = repository.sendMessage(user: user, receiver: receiver, isGroupChat: isGroupChat, text: trimmed) else {
            state.message = "채팅을 사용할 수 없습니다."
            return
        }
        knownKeys.insert(sent.key)
        state.messages.append(sent)
        state.scrollCommand = ScrollCommand(kind: .forceBottom, key: sent.key, token: UUID())
        inputMessage = ""
    }

    // ChatView.onAppear 대응 — 초기 로드 이후 마지막 key 다음부터 실시간 수신(스펙 §3.5 개선 2).
    // 실제 부착은 초기 로드가 끝난 뒤로 미룬다(위 헤더 코멘트 — afterKey nil 전체 재생 방지).
    func startObserving() {
        isObservingRequested = true
        attachObserverIfNeeded()
    }

    // ChatView.onDisappear 대응 — 화면 이탈 시 옵저버 해제(재진입 시 startObserving이 다시 등록).
    func stopObserving() {
        isObservingRequested = false
        guard let handle = observerHandle,
              let receiver = receiver,
              let uid = PreferenceManager.shared.user?.uid else {
            return
        }
        repository.removeObserver(currentUid: uid, receiver: receiver, isGroupChat: isGroupChat, handle: handle)
        observerHandle = nil
    }

    private func attachObserverIfNeeded() {
        guard isObservingRequested, isInitialLoadComplete, observerHandle == nil,
              let receiver = receiver,
              let uid = PreferenceManager.shared.user?.uid else {
            return
        }
        observerHandle = repository.observeNewMessages(currentUid: uid, receiver: receiver, isGroupChat: isGroupChat, afterKey: state.messages.last?.key) { [weak self] item in
            guard let self = self, !self.knownKeys.contains(item.key) else {
                return
            }
            self.knownKeys.insert(item.key)
            self.state.messages.append(item)
            self.state.scrollCommand = ScrollCommand(kind: .softBottom, key: item.key, token: UUID())
        }
    }

    private func fetchMessages(previousCount: Int, previousCursor: String?) {
        guard let receiver = receiver, let uid = PreferenceManager.shared.user?.uid else {
            return
        }
        let isInitialLoad = previousCount == 0 && previousCursor == nil

        repository.fetchMessages(currentUid: uid, receiver: receiver, isGroupChat: isGroupChat, cursor: previousCursor, limit: ChatViewModel.limit) { [weak self] result in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let fetched):
                self.onFetchSuccess(fetched, previousCount: previousCount, previousCursor: previousCursor)
                // Task 12(3차) — 초기 로드 성공 시에만 관찰을 시작한다. 실패 시에도 무조건 완료
                // 처리하면 messages가 비어 있어(fetch 실패로 아무것도 안 들어옴) afterKey가 nil이
                // 되고, ChatRemoteDataSource가 필터 없는 bare reference로 childAdded를 붙여 대화방
                // 전체 이력이 한 번에 재생되는 문제(위 헤더 코멘트 §3.5)가 실패 케이스에서도 그대로
                // 발생한다. 실패는 관찰을 보류해 재시도(fetchPreviousPage 등)나 재진입으로 다시 초기
                // 로드가 성공할 때까지 기다린다 — 실패 토스트(아래 .failure 분기)는 그대로 유지.
                if isInitialLoad {
                    self.isInitialLoadComplete = true
                    self.attachObserverIfNeeded()
                }
            case .failure(let error):
                self.hasRequestedMore = false
                self.state.message = error.localizedDescription
            }
        }
    }

    // Android ChatViewModel.fetchMessageList(...).onSuccess 이식 — 순서·조건 임의 변경 금지(브리프 원문).
    private func onFetchSuccess(_ fetched: [MessageItem], previousCount: Int, previousCursor: String?) {
        let insertPosition = max(state.messages.count - previousCount, 0)
        var addedCount = 0
        var newCursor: String?

        for item in fetched {                                   // key 오름차순
            if newCursor == nil { newCursor = item.key }        // 배치의 최고(最古) key
            if let first = firstMessageKey, first == item.key { continue }
            if firstMessageKey == nil { firstMessageKey = item.key }
            if item.key == previousCursor { continue }          // endAt inclusive 중복 제거
            if knownKeys.contains(item.key) { continue }        // 낙관적/childAdded 중복 제거(개선 2)
            knownKeys.insert(item.key)
            state.messages.insert(item, at: insertPosition + addedCount)
            addedCount += 1
        }
        hasRequestedMore = false
        if let newCursor = newCursor { cursor = newCursor }
        guard addedCount > 0 else { return }
        if previousCount == 0, let last = state.messages.last {
            state.scrollCommand = ScrollCommand(kind: .forceBottom, key: last.key, token: UUID())
        } else if state.messages.indices.contains(addedCount) {
            // Android scrollToPositionWithOffset(addedCount, 10) — 이전에 맨 위였던 메시지를 상단에 유지
            state.scrollCommand = ScrollCommand(kind: .preserveTop, key: state.messages[addedCount].key, token: UUID())
        }
    }
}
