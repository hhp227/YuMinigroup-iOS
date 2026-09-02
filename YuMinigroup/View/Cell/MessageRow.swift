//
//  MessageRow.swift
//  YuMinigroup
//
//  Android adapter/MessageListAdapter(message_item_left.xml/message_item_right.xml) 대응 — 채팅
//  한 줄. 좌측(상대)은 묶음의 첫 메시지(separated)에만 프로필(41pt 원형)+이름(13pt bold #777777)을
//  보이고, 우측(나)은 프로필·이름 없이 타임스탬프가 말풍선 왼쪽에 온다(스펙 §4.4). Android 원본
//  드로어블(bg_other_msg #e5e7eb/bg_my_msg #68d0fb)과 달리 이 포팅은 브리프 지시대로 좌측을 흰
//  배경, 우측을 accentColor 배경으로 그린다(의도적 색상 결정 — Android 미러 아님).
//
//  timeStamp(_:)는 static — ChatView의 separated/showsTimestamp 계산(Task 10 재사용 예정)이
//  MessageRow 인스턴스 없이도 같은 포맷으로 두 메시지의 시각 문자열을 비교할 수 있게 한다.
//
//  profileImage는 Android messageHeaderVisible(INVISIBLE — 공간 유지)을 opacity(0)으로, 타임스탬프는
//  Android timestampVisible(INVISIBLE)을 동일하게 opacity(0)으로 미러한다. 이름(tv_name)은 Android가
//  GONE(공간 없음)을 쓰므로 SwiftUI에서도 조건부로 뷰 자체를 생략해 공간을 차지하지 않게 한다.
//

import SwiftUI

struct MessageRow: View {
    let item: MessageItem
    let isMine: Bool
    let separated: Bool
    let showsTimestamp: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current            // Android Locale.getDefault() 미러 — 한국어면 "오후 3:05"
        formatter.dateFormat = "a h:mm"
        return formatter
    }()

    static func timeStamp(_ millis: Int64) -> String {
        timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(millis) / 1000))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if isMine {
                Spacer(minLength: 40)
                timestampText
                bubble(background: Color.accentColor, foreground: .white)
            } else {
                profileImage

                VStack(alignment: .leading, spacing: 2) {
                    if separated {
                        Text(item.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.467, green: 0.467, blue: 0.467))
                    }

                    HStack(alignment: .bottom, spacing: 4) {
                        bubble(background: .white, foreground: Color(red: 0.263, green: 0.263, blue: 0.263))
                        timestampText
                    }
                }

                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, separated ? 10 : 2)   // Android messageSeparated(브리프 값 10/2)
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }

    // Android iv_profile_image(41dp 원형, messageHeaderVisible) 대응.
    private var profileImage: some View {
        RemoteImage(urlString: EndPoint.userImage(uid: item.from), placeholder: Image(systemName: "person.crop.circle.fill"))
            .aspectRatio(contentMode: .fill)
            .frame(width: 41, height: 41)
            .clipShape(Circle())
            .opacity(separated ? 1 : 0)
    }

    // Android tv_message(bg_other_msg/bg_my_msg) 대응 — 브리프 지시 색상(좌 흰색/우 accentColor)으로 대체.
    private func bubble(background: Color, foreground: Color) -> some View {
        Text(item.message)
            .font(.system(size: 16))
            .foregroundColor(foreground)
            .padding(9)
            .background(background)
            .cornerRadius(8)
    }

    // Android tv_timestamp(timestampVisible → INVISIBLE) 대응 — 자리 유지를 위해 opacity(0)만 쓴다.
    private var timestampText: some View {
        Text(MessageRow.timeStamp(item.timestamp))
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .opacity(showsTimestamp ? 1 : 0)
    }
}
