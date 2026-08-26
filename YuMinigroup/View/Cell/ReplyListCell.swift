//
//  ReplyListCell.swift
//  YuMinigroup
//
//  Android adapter/ReplyListAdapter(reply_item.xml) 대응 — 게시글 상세의 댓글 한 줄. 아바타
//  (RemoteImage + EndPoint.userImage(uid:)) + 이름(굵게) + 댓글 본문, 우하단에 상대 시각(timestamp가
//  있으면 DateUtil.relative, 파싱에 실패해 없으면 Android가 그대로 보여주는 원본 date 문자열로 대체).
//
//  Android는 ListView의 registerForContextMenu(길게 클릭 → 복사/수정/삭제 컨텍스트 메뉴, 본인 댓글만
//  수정·삭제 노출)를 쓰지만, SwiftUI에는 그 자리에 꼭 맞는 표준 API가 .contextMenu(길게 눌러 뜨는 메뉴)라
//  그걸 그대로 쓴다 — iOS 13부터 있어 15.6 호환.
//

import SwiftUI

struct ReplyListCell: View {
    let reply: ReplyItem
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RemoteImage(urlString: EndPoint.userImage(uid: reply.uid), placeholder: Image(systemName: "person.crop.circle.fill"))
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(reply.name)
                    .font(.subheadline.weight(.bold))

                Text(reply.reply)
                    .font(.subheadline)
            }

            Spacer()

            if let dateText = dateText {
                Text(dateText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
        .contextMenu {
            // Android onCreateContextMenu의 "내용 복사"는 위치와 무관하게 항상 노출된다.
            Button(action: onCopy) {
                Label("복사", systemImage: "doc.on.doc")
            }

            // "댓글 수정"/"댓글 삭제"는 Android처럼 본인 댓글일 때만 노출한다.
            if reply.isAuth {
                Button(action: onEdit) {
                    Label("수정", systemImage: "pencil")
                }

                Button(role: .destructive, action: onDelete) {
                    Label("삭제", systemImage: "trash")
                }
            }
        }
    }

    private var dateText: String? {
        if let timestamp = reply.timestamp {
            return DateUtil.relative(timestamp)
        }
        return reply.date
    }
}
