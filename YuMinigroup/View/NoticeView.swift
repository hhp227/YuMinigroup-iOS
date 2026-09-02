//
//  NoticeView.swift
//  YuMinigroup
//
//  Android activity_notice.xml(toolbar+title "앱 공지사항"+본문 텍스트) 대응 — 정적 공지사항 화면.
//  push 자식(시스템 네비바)으로 표시되며, 상단 여백 후 중앙 정렬로 제목과 본문을 배치한다.
//

import SwiftUI

struct NoticeView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 30)

            Text("앱 공지사항")
                .font(.headline)

            Spacer()
                .frame(height: 30)

            Text("내용 : 영남대 소모임앱을 이용해주셔서 감사합니다. \n 문의사항은 구글 플레이스토어에 게시되어있는 \n 개발자 연락처로 주세요. \n \n 기능 추가에 관한 문의를 주셔도 됩니다. \n 많은 이용부탁드립니다. 감사합니다.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()
        }
        .navigationTitle("공지사항")
        .navigationBarTitleDisplayMode(.inline)
    }
}
