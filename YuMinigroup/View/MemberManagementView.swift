//
//  MemberManagementView.swift
//  YuMinigroup
//
//  Android fragment/MemberManagementFragment(fragment_member.xml: 회색 배경 + CardView(고정 헤더
//  4열 + SwipeRefreshLayout+ListView)) 대응 — 그룹 설정 "회원관리" 탭. 읽기 전용(액션 없음) — Android
//  앱에도 회원 승인/추방 기능이 없다(LMS 웹 전용, 스펙 §1 제외 목록).
//
//  헤더 4열(프로필/학부·학과/회원 구분/가입 일시)은 fragment_member.xml의 "1px 세로 구분선 +
//  균등폭(weight=1) 컬럼" 구조를 Divider()(HStack 안에서는 세로 hairline을 그린다)로 그대로 옮긴다 —
//  컬럼 앞마다 구분선이 하나씩 있고(4개), 마지막 컬럼 뒤에는 없다(XML 그대로).
//
//  행 렌더는 member_list_item.xml 그대로: 65pt 원형 프로필(EndPoint.USER_IMAGE — Tab3View.memberCell과
//  동일한 RemoteImage(uid) 관례, 쿠키 로딩) + 이름을 세로로 쌓은 1열 + dept/div/regDate 3열, 13pt.
//
//  .refreshable은 SeatView.swift 관례(진짜 재조회 콜백을 부르는 것으로 충분 — 스피너를 인위적으로
//  붙잡아 두는 Tab3View의 1초 대기는 Android Tab3Fragment 전용 postDelayed 사유라 여기엔 해당 없음)를
//  그대로 따라 viewModel.refresh()만 부른다(스펙 §2 결함 3 수정 — Android는 Toast만 띄우고 재조회하지
//  않는다).
//

import SwiftUI

struct MemberManagementView: View {
    @ObservedObject var viewModel: MemberManagementViewModel

    private static let columnTitles = ["프로필", "학부/학과", "회원 구분", "가입 일시"]

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                headerRow

                Divider()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.state.members) { member in
                            memberRow(member)

                            Divider()
                        }
                    }
                }
                .refreshable {
                    viewModel.refresh()
                }
            }
            .background(Color(uiColor: .systemBackground))
            .cornerRadius(4)
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .padding(10)

            // Android srl_member(SwipeRefreshLayout)와 별개로 최초 로드 동안만 보이는 중앙 스피너
            // (브리프 "첫 로딩 스피너") — Tab3View.memberCell 주변과 동일한 "비었고 로딩 중" 판정.
            if viewModel.state.members.isEmpty && viewModel.state.isLoading {
                ProgressView()
            }
        }
        .toast(message: $viewModel.state.message)
    }

    // fragment_member.xml 헤더 LinearLayout(구분선 + 컬럼) 4쌍 그대로 — 구분선이 각 컬럼 앞에 온다.
    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(MemberManagementView.columnTitles.enumerated()), id: \.offset) { _, title in
                Divider()

                Text(title)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
            }
        }
    }

    // member_list_item.xml 그대로 — 1열은 프로필+이름 세로 스택, 나머지 3열은 균등폭 텍스트.
    private func memberRow(_ member: MemberItem) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                RemoteImage(urlString: EndPoint.userImage(uid: member.uid))
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 65, height: 65)
                    .clipShape(Circle())

                Text(member.name)
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)

            Text(member.dept ?? "")
                .font(.system(size: 13))
                .frame(maxWidth: .infinity)

            Text(member.div ?? "")
                .font(.system(size: 13))
                .frame(maxWidth: .infinity)

            Text(member.regDate ?? "")
                .font(.system(size: 13))
                .frame(maxWidth: .infinity)
        }
    }
}
