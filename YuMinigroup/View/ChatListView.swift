//
//  ChatListView.swift
//  YuMinigroup
//
//  Task 10: 채팅방 목록(신설, Android에 없는 화면 — 스펙 §4.5가 원전) — 드로어 "채팅" 메뉴로 진입한다.
//  GroupMainView와 동일한 뼈대(로컬 NavigationView + AppToolbar(.menu) + navigationBarHiddenCompat +
//  StackNavigationViewStyle)를 미러한다 — MainView/DrawerScaffold 트리에는 NavigationView가 없어
//  NavigationLink(→ ChatView push)를 쓰려면 이 화면이 직접 NavigationView 조상을 둬야 한다.
//
//  isChatAvailable == false(Firebase 미구성/로그인 사용자 없음)와 rooms.isEmpty(대화 없음)는 서로 다른
//  안내 문구를 쓴다(스펙 §4.5/§5) — GroupMainView의 emptyBanner 구조를 확장해 "가용 여부" 분기를
//  바깥에 하나 더 둔다.
//
//  onAppear 가드(hasAppeared): ChatListViewModel.init()이 이미 즉시 fetchRooms()를 부르므로, 이 화면이
//  새로 만들어질 때(최초 드로어 진입이든, 드로어를 다른 라우트로 옮겼다 "채팅"으로 되돌아와 이
//  View/@StateObject가 통째로 다시 생성되는 경우든) 첫 onAppear에서 또 fetchRooms()를 부르면 같은
//  순간에 조회가 두 번 겹쳐 발사된다(레이스 — state.isLoading 토글 순서가 꼬일 수 있다). 반면 이
//  화면 자신은 다시 만들어지지 않고 그 안에서 push한 ChatView만 pop되어 돌아오는 "진짜 재진입"에는
//  fetchRooms()가 필요하다(방금 보낸/받은 메시지로 목록 미리보기·시각을 새로고침). hasAppeared 플래그로
//  이 두 경우를 구분한다: 이 View 인스턴스의 첫 onAppear는 건너뛰고(@State도 인스턴스와 함께 새로
//  만들어지므로 항상 false로 시작), 그 다음 onAppear(=ChatView pop 후 재등장)부터만 fetchRooms()를 부른다.
//

import SwiftUI

struct ChatListView: View {
    @StateObject private var viewModel = ChatListViewModel()

    @State private var hasAppeared = false

    // 커스텀 init 없이 합성 멤버와이즈 init에 맡긴다 — GroupMainView와 동일 관례(@StateObject는
    // 기본값 표현식이 독립적으로 처리되므로 onMenuClick만 있는 이 형태에는 커스텀 init이 불필요하다).
    let onMenuClick: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppToolbar(title: "채팅", navigationIcon: .menu, onNavigationClick: onMenuClick)

                ZStack {
                    if viewModel.isChatAvailable {
                        ScrollView {
                            if viewModel.state.rooms.isEmpty && !viewModel.state.isLoading {
                                emptyNotice
                            } else {
                                LazyVStack(spacing: 0) {
                                    ForEach(viewModel.state.rooms) { room in
                                        NavigationLink(destination: ChatView(receiver: room.receiver, isGroupChat: room.isGroupChat, chatName: room.title)) {
                                            ChatRoomRow(room: room)
                                        }
                                        .buttonStyle(.plain)

                                        Divider().padding(.leading, 76)
                                    }
                                }
                            }
                        }
                        .refreshable {
                            viewModel.fetchRooms()
                        }
                    } else {
                        unavailableNotice
                    }

                    if viewModel.isChatAvailable && viewModel.state.isLoading && viewModel.state.rooms.isEmpty {
                        ProgressView()
                    }
                }
            }
            .navigationBarHiddenCompat()
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .toast(message: $viewModel.state.message)
        .onAppear {
            // 헤더 코멘트 참고 — 최초 onAppear(=init()과 같은 마운트)는 건너뛰고 그 다음부터만 재조회.
            if hasAppeared {
                viewModel.fetchRooms()
            }
            hasAppeared = true
        }
    }

    private var unavailableNotice: some View {
        VStack {
            Spacer()
            Text("채팅을 사용할 수 없습니다")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyNotice: some View {
        VStack {
            Spacer()
            Text("대화가 없습니다.")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// 목록 한 행 — 이미지 48pt(1:1 원형/그룹 라운드) + 제목(15pt bold)/미리보기(13pt secondary, 1줄) +
// 시각(caption2, MessageRow.timeStamp 재사용).
private struct ChatRoomRow: View {
    let room: ChatRoomItem

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(room.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColorCompat(Color.primary)
                    .lineLimit(1)

                if let preview = room.preview {
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let timestamp = room.timestamp {
                Text(MessageRow.timeStamp(timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatar: some View {
        let image = RemoteImage(
            urlString: room.imageURL,
            placeholder: Image(systemName: room.isGroupChat ? "person.3.fill" : "person.crop.circle.fill")
        )
        .aspectRatio(contentMode: .fill)
        .frame(width: 48, height: 48)
        .clipped()

        if room.isGroupChat {
            image.cornerRadius(8)
        } else {
            image.clipShape(Circle())
        }
    }
}
