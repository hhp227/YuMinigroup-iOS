//
//  ChatView.swift
//  YuMinigroup
//
//  Android activity/ChatActivity(activity_chat.xml) 대응 — 채팅 화면(그룹/1:1 공용). Android는
//  RecyclerView.OnScrollListener(맨 위 도달 시 fetchPreviousPage, onLayoutChange로 "가까이 있을 때만"
//  스크롤)를 쓰지만, SwiftUI에는 그 자리에 ScrollViewReader + 행별 onAppear/onDisappear로 같은 효과를
//  낸다: 첫 행 onAppear가 "맨 위 도달"을, 마지막 행 onAppear/onDisappear가 "바닥 근처 여부"(isNearBottom,
//  KnuMiniGroup-iOS 채팅 키보드 픽스와 동일한 판정 기준)를 각각 대신한다.
//
//  separated/showsTimestamp는 인덱스 기반으로 매 렌더마다 다시 계산한다(Android MessageListAdapter가
//  bind 시점에 계산하는 것과 동일 — 별도로 캐싱하지 않아도 messages 배열이 60개 안팎인 채팅 특성상
//  비용이 크지 않다).
//
//  scrollCommand 처리: forceBottom은 첫 발생(초기 로드)에는 애니메이션 없이, 이후(전송)에는
//  withAnimation으로 부드럽게 내려간다. softBottom(실시간 수신)도 "이후" 스크롤과 같은 성격이라
//  withAnimation을 쓴다. preserveTop(이전 페이지 로드 후 위치 보정)은 Android
//  scrollToPositionWithOffset과 같은 즉시 보정이라 애니메이션을 주지 않는다 — 여기 애니메이션 여부는
//  브리프가 명시한 "forceBottom 초기 1회 무-애니메이션" 규칙을 자연스럽게 확장한 판단이다.
//

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel

    @State private var isNearBottom = true
    @State private var didPerformInitialScroll = false

    init(receiver: String?, isGroupChat: Bool, chatName: String) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(receiver: receiver, isGroupChat: isGroupChat, chatName: chatName))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isChatAvailable {
                messageList
            } else {
                unavailableNotice
            }

            Divider()

            composer
        }
        .navigationTitle(viewModel.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toast(message: $viewModel.state.message)
        .onAppear {
            viewModel.startObserving()
        }
        .onDisappear {
            viewModel.stopObserving()
        }
    }

    // MARK: - 채팅 불가 안내 (Firebase 미구성/로그인 사용자 없음/receiver 없음)

    private var unavailableNotice: some View {
        VStack {
            Spacer()

            Text("채팅을 사용할 수 없습니다")
                .foregroundColor(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.957, green: 0.980, blue: 1.0))
    }

    // MARK: - 메시지 목록 (rv_message 대응)

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.state.messages.enumerated()), id: \.element.key) { index, message in
                        MessageRow(
                            item: message,
                            isMine: message.from == PreferenceManager.shared.user?.uid,
                            separated: isSeparated(at: index),
                            showsTimestamp: showsTimestamp(at: index)
                        )
                        .id(message.key)
                        .onAppear {
                            if index == 0 {
                                viewModel.fetchPreviousPage()
                            }
                            if index == viewModel.state.messages.count - 1 {
                                isNearBottom = true
                            }
                        }
                        .onDisappear {
                            if index == viewModel.state.messages.count - 1 {
                                isNearBottom = false
                            }
                        }
                    }
                }
            }
            .background(Color(red: 0.957, green: 0.980, blue: 1.0))
            .onChange(of: viewModel.state.scrollCommand) { command in
                guard let command = command else {
                    return
                }
                switch command.kind {
                case .forceBottom:
                    if didPerformInitialScroll {
                        withAnimation {
                            proxy.scrollTo(command.key, anchor: .bottom)
                        }
                    } else {
                        proxy.scrollTo(command.key, anchor: .bottom)
                        didPerformInitialScroll = true
                    }
                case .softBottom:
                    if isNearBottom {
                        withAnimation {
                            proxy.scrollTo(command.key, anchor: .bottom)
                        }
                    }
                case .preserveTop:
                    proxy.scrollTo(command.key, anchor: .top)
                }
            }
        }
    }

    // Android MessageListAdapter.isSeparated(position, messageItem) 대응 — i==0이거나 이전 메시지와
    // 같은 분("a h:mm")·같은 발신자가 아니면 묶음의 첫 메시지.
    private func isSeparated(at index: Int) -> Bool {
        guard index > 0 else {
            return true
        }
        let messages = viewModel.state.messages
        let previous = messages[index - 1]
        let current = messages[index]

        return MessageRow.timeStamp(previous.timestamp) != MessageRow.timeStamp(current.timestamp) || previous.from != current.from
    }

    // Android MessageListAdapter.isTimestampVisible(position, messageItem) 대응 — 마지막이거나 다음
    // 메시지와 같은 분·같은 발신자가 아니면 묶음의 마지막 메시지.
    private func showsTimestamp(at index: Int) -> Bool {
        let messages = viewModel.state.messages

        guard index + 1 < messages.count else {
            return true
        }
        let current = messages[index]
        let next = messages[index + 1]

        return MessageRow.timeStamp(current.timestamp) != MessageRow.timeStamp(next.timestamp) || current.from != next.from
    }

    // MARK: - 입력 바 (et_input_msg/cv_btn_send 대응)

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("메시지를 입력하세요.", text: $viewModel.inputMessage)
                .textFieldStyle(.plain)

            Button(action: {
                viewModel.actionSend()
            }) {
                Text("전송")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isInputEmpty ? .secondary : .white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isInputEmpty ? Color(uiColor: .secondarySystemBackground) : Color.accentColor)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .disabled(!viewModel.isChatAvailable)
    }

    private var isInputEmpty: Bool {
        viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
