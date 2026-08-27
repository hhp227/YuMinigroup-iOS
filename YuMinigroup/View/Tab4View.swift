//
//  Tab4View.swift
//  YuMinigroup
//
//  Android fragment/Tab4Fragment(content_tab4.xml, 단일 CardView) 대응 — 설정 탭 실제 화면. Tab1View/
//  Tab3View와 같은 탭 바디 계약(viewModel:headerHeight:appBarState:isActive:scrollOffset:)을 채운다.
//  Android는 RecyclerView(itemCount=1)로 카드 하나만 감싸는데, 여기서는 그 겉포장 없이 ScrollView +
//  CollapsingHeaderSpacer(Tab2View/Tab3View와 동일 뼈대) 위에 카드 뷰 하나를 바로 얹는다.
//
//  세 섹션(사용자 설정/소모임 설정/어플리케이션 정보)을 content_tab4.xml 순서·문구 그대로 미러한다.
//  Android가 각 항목을 감싸는 카드 스타일(cardCornerRadius=4dp)은 GroupMainView.GroupGridCell과 동일한
//  배경+cornerRadius+shadow 조합으로 옮겼다.
//
//  ①사용자 설정: ll_profile 대응. 탭하면 ProfileView(Task 19)를 .fullScreenCover로 띄운다 — 이
//  화면은 자체 NavigationView+닫기(X) 버튼을 가진 자기완결형 모달이라(ProfileView.swift 헤더 참고),
//  다른 행들이 쓰는 NavigationLink push 대신 MainView 드로어 헤더 진입점과 같은 프레젠테이션으로 맞춘다.
//
//  ②소모임 설정: tv_withdrawal(라벨 "소모임" + (isAdmin ? "폐쇄" : "탈퇴"), 공백 없음 — content_tab4.xml
//  그대로) 대응. 탭하면 Android AlertDialog(메시지 "(폐쇄|탈퇴)하시겠습니까?", "예"/"아니오") 대응인
//  .alert 확인 다이얼로그를 띄우고, "예"를 누르면 Tab4ViewModel.leaveOrClose()를 호출한다. 성공 시
//  didExit가 true로 바뀌는 것을 onChange로 관찰해 presentationMode.dismiss()로 GroupView를 pop한다
//  (GroupView는 GroupMainView의 로컬 NavigationView에 NavigationLink로 push되어 있으므로, 자식 뷰인
//  이 화면에서 dismiss()를 불러도 presentationMode 환경값이 그 push 컨텍스트를 그대로 가리켜 정상
//  동작한다 — UserDialogView가 이미 같은 API로 자신의 .sheet를 닫는 전례가 있다).
//  Android는 isAdmin일 때만 보이는 ll_settings(→ SettingsActivity, 그룹 정보 수정) 행을 하나 더 갖고
//  있지만, 브리프가 명시한 3섹션 계약에는 없고 그 화면 자체가 이번 마이그레이션 범위 밖(별도 태스크
//  몫)이라 이식하지 않았다.
//
//  ③어플리케이션 정보: ll_notice(공지사항 — NoticeView로 정적 화면 구현),
//  ll_feedback(건의사항 — Android Intent.ACTION_SEND(message/rfc822) 대신 UIApplication.shared.open의
//  mailto: URL로 옮겼다. 수신자/제목/본문 필드는 Tab4ViewModel.java의 문자열 그대로),
//  ll_verinfo(버젼 정보 — Android VerInfoActivity 전체 화면 대신 CFBundleShortVersionString을 행
//  오른쪽에 바로 표시하는 한 줄로 줄였다, 새 화면을 만들지 않기 위함) 세 줄만 옮겼다. ll_appstore(평점
//  주기)/ll_share(공유하기)는 드롭했다 — 둘 다 Android 원본이 이미 플레이스토어 패키지명 URL에 기대는
//  구조라 iOS 앱스토어 등록 정보(product ID)가 아직 없고, Android ll_share의 공유 문구 자체도 죽은
//  "https://localhost/" 링크를 담은 낡은 코드라 그대로 옮길 가치가 없다고 판단했다(브리프의 "필요하면
//  드롭해도 된다" 지시를 따름). AdMob(ad_view)은 브리프가 명시적으로 제외했다.
//

import SwiftUI

struct Tab4View: View {
    @ObservedObject var viewModel: Tab4ViewModel
    let headerHeight: CGFloat
    let appBarState: CollapsingAppBarState
    let isActive: Bool
    @Binding var scrollOffset: CGFloat

    @Environment(\.presentationMode) private var presentationMode
    @State private var showLeaveConfirm = false
    @State private var showProfile = false

    private static let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "-"

    var body: some View {
        ScrollView {
            CollapsingHeaderSpacer(isScrollTrackingEnabled: isActive)

            card
                .padding(.top, headerHeight + 10)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
        }
        .coordinateSpace(name: collapsingScrollCoordinateSpace)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) {
            if isActive && !$0.isNaN {
                scrollOffset = $0
            }
        }
        .toast(message: $viewModel.message)
        .onChange(of: viewModel.didExit) { didExit in
            if didExit {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .alert(isPresented: $showLeaveConfirm) {
            Alert(
                title: Text(viewModel.confirmMessage),
                primaryButton: .destructive(Text("예")) { viewModel.leaveOrClose() },
                secondaryButton: .cancel(Text("아니오"))
            )
        }
        .fullScreenCover(isPresented: $showProfile) {
            ProfileView()
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("사용자 설정")
            profileRow

            sectionHeader("소모임 설정")
            groupSettingRow

            sectionHeader("어플리케이션 정보")
            appInfoRows
        }
        .padding(.vertical, 20)
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
    }

    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .padding(.leading, 15)

            Divider()
                .padding(.horizontal, 10)
        }
        .padding(.top, 10)
    }

    // Android ll_profile(iv_profile_image + tv_name + tv_yu_id) 대응.
    private var profileRow: some View {
        Button(action: { showProfile = true }) {
            HStack(spacing: 10) {
                RemoteImage(urlString: viewModel.userImageURL)
                    .aspectRatio(1, contentMode: .fill)
                    .frame(width: 45, height: 45)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.user?.name ?? "")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColorCompat(.primary)
                    Text(viewModel.user?.userId ?? "")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
    }

    // Android ll_withdrawal 대응 — 탭하면 확인 다이얼로그를 띄운다(즉시 실행하지 않는다).
    private var groupSettingRow: some View {
        Button(action: { showLeaveConfirm = true }) {
            HStack {
                Text(viewModel.actionLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColorCompat(.primary)

                Spacer(minLength: 0)

                if viewModel.isProcessing {
                    ProgressView()
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 50)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isProcessing)
    }

    // Android ll_notice/ll_feedback/ll_verinfo 대응(ll_appstore/ll_share는 위 헤더 코멘트 참고로 드롭).
    private var appInfoRows: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: NoticeView()) {
                infoRow(title: "공지사항")
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal, 10)

            Button(action: openFeedbackMail) {
                infoRow(title: "건의사항")
            }
            .buttonStyle(.plain)

            Divider().padding(.horizontal, 10)

            infoRow(title: "버젼 정보", trailing: Tab4View.appVersion)
        }
    }

    private func infoRow(title: String, trailing: String? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColorCompat(.primary)

            Spacer(minLength: 0)

            if let trailing = trailing {
                Text(trailing)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 15)
        .frame(height: 50)
    }

    // Android Tab4Holder.onClick(ll_feedback) 대응 — Intent.ACTION_SEND(message/rfc822) 대신 mailto: URL.
    // 수신자/제목/본문 문구는 Tab4ViewModel.java deleteGroup()이 아니라 onClick(ll_feedback) 그대로:
    // "hong227@naver.com" / "영남대소모임 건의사항" / "작성자 (Writer) : .. \n기기 모델 (Model) : ..
    // \n앱 버전 (AppVer) : .. \n내용 (Content) : ".
    private func openFeedbackMail() {
        let subject = "영남대소모임 건의사항"
        let body = "작성자 (Writer) : \(viewModel.user?.name ?? "")\n"
            + "기기 모델 (Model) : \(UIDevice.current.model)\n"
            + "앱 버전 (AppVer) : \(Tab4View.appVersion)\n"
            + "내용 (Content) : "
        let allowed = CharacterSet.urlQueryAllowed
        guard let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: allowed),
              let encodedBody = body.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "mailto:hong227@naver.com?subject=\(encodedSubject)&body=\(encodedBody)") else {
            return
        }
        UIApplication.shared.open(url)
    }
}
