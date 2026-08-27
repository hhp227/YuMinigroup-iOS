//
//  UserDialogView.swift
//  YuMinigroup
//
//  Android fragment/UserDialogFragment(fragment_user.xml, 배경 투명 DialogFragment) 대응 — 맴버 그리드
//  탭 시 뜨는 미니 프로필. iOS 15.6 호환을 위해 커스텀 다이얼로그 대신 표준 .sheet로 띄운다(Tab3View가
//  호출부).
//
//  fragment_user.xml은 학번/학과 TextView 두 칸을 레이아웃에만 두고 실제로 데이터 바인딩을 걸지 않는다
//  (android:text가 비어 있음 — Android 자체가 이 화면에서 학번/학과를 그리지 않는, 즉 죽은 마크업이다).
//  MemberItem.stuNum/dept는 이 화면이 실제로 쓰는 fetchMembers 경로에서 애초에 nil로만 채워지므로
//  (GroupRemoteDataSource.parseMembers 참고), 아래 학번/학과 줄은 값이 있을 때만 그리는 nil-safe
//  방어로 남겨둔다(향후 멤버 상세 API가 두 필드를 채우게 되면 자동으로 나타난다).
//
//  "메시지 보내기" 버튼은 Android UserDialogFragment.onSendClick가 ChatActivity로 바로 연결하는 것과
//  동일하게, 탭하면 onSendMessage()를 호출해 호출부(Tab3View)가 ChatView(1:1)를 push하도록 위임한다.
//  본인 프로필(viewModel.isSelf)이면 Android가 b_send를 GONE 처리하는 것과 같이 버튼 자체를 숨기고
//  "닫기"만 전폭으로 보인다.
//

import SwiftUI

struct UserDialogView: View {
    @ObservedObject var viewModel: UserViewModel
    let onSendMessage: () -> Void
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        VStack(spacing: 0) {
            header
            infoRow
            Divider()
            actionBar
        }
    }

    // Android iv_user(배경 이미지) + 반투명 스크림 위 "맴버 정보" 타이틀 대응 — 브랜드 이미지 에셋이
    // 없어 GroupView 헤더 로고 모드와 같은 accentColor 배경을 재사용한다.
    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            Color.accentColor
                .frame(height: 90)

            Text("맴버 정보")
                .font(.headline)
                .foregroundColorCompat(Color.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.47))
        }
    }

    // Android ll_container(iv_profile_image + tv_name + 학번/학과 두 줄) 대응.
    private var infoRow: some View {
        HStack(alignment: .top, spacing: 8) {
            RemoteImage(urlString: EndPoint.userImage(uid: viewModel.member.uid))
                .aspectRatio(1, contentMode: .fill)
                .frame(width: 60, height: 60)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.member.name)
                    .font(.system(size: 16))

                if let stuNum = viewModel.member.stuNum, !stuNum.isEmpty {
                    Text(stuNum)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                if let dept = viewModel.member.dept, !dept.isEmpty {
                    Text(dept)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
    }

    // Android b_send(본인이면 GONE)/b_close 대응.
    private var actionBar: some View {
        HStack(spacing: 0) {
            if !viewModel.isSelf {
                Button(action: onSendMessage) {
                    Text("메시지 보내기")
                        .font(.system(size: 14))
                        .foregroundColorCompat(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }

                Divider()
            }

            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Text("닫기")
                    .font(.system(size: 14))
                    .foregroundColorCompat(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
