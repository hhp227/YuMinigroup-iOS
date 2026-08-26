//
//  ArticleListCell.swift
//  YuMinigroup
//
//  Android adapter/ArticleListAdapter(item_article.xml) 대응 — 소식 탭 한 줄 카드. 아바타(RemoteImage +
//  EndPoint.userImage(uid:)) + 이름 + 상대 시각(DateUtil.relative) + 제목 + 본문 4줄 + 첫 이미지 +
//  댓글 수. title은 브리프의 Produces 요약엔 없지만 ArticleItem에 이미 있는 필드이자 게시글 카드에서
//  당연히 필요한 정보라 GroupGridCell(그룹 이름 표시)과 같은 맥락으로 함께 넣었다.
//

import SwiftUI

struct ArticleListCell: View {
    let article: ArticleItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RemoteImage(urlString: EndPoint.userImage(uid: article.uid), placeholder: Image(systemName: "person.crop.circle.fill"))
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())

                Text(article.name)
                    .font(.subheadline.weight(.medium))

                if let timestamp = article.timestamp {
                    Text(DateUtil.relative(timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(article.title)
                .font(.headline)
                .lineLimit(1)

            if !article.content.isEmpty {
                Text(article.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }

            if let firstImage = article.images.first {
                RemoteImage(urlString: firstImage)
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(6)
            }

            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.caption)
                Text("\(article.replyCount)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
    }
}
