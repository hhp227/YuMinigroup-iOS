//
//  ProfileView.swift
//  YuMinigroup
//
//  Android activity_profile.xml + ProfileActivity 대응 — LMS 프로필 화면. 드로어 헤더(MainView, Task 9)
//  탭과 Tab4View "프로필" 행(Task 15) 두 진입점이 모두 이 화면을 .fullScreenCover로 띄운다(자체
//  NavigationView + 좌상단 닫기(X) 버튼을 갖는 자기완결형 모달 — CreateArticleView/PictureView와 같은
//  패턴). 드로어 헤더는 DrawerScaffold 바깥에 있어 NavigationLink push 컨텍스트가 없고, Tab4View의
//  "프로필" 행도 이 화면과 짝을 맞추기 위해 NavigationLink 대신 같은 .fullScreenCover를 쓴다.
//
//  아바타 탭 → PhotoPicker(selectionLimit: 1, 앨범만 — Android 컨텍스트 메뉴의 "카메라" 옵션은 브리프가
//  요구하지 않아 옮기지 않았다)로 고른 이미지를 즉시 미리보기로 보여주고, "적용" 버튼(고른 사진이 있을
//  때만 노출)을 눌러야 실제로 서버에 반영된다 — Android의 "고르기(onCameraActivityResult)"와
//  "반영(옵션 메뉴 action_send → uploadImage(false))" 2단계 그대로.
//
//  필드 6종(이름/학과/학번/학년/이메일/전화)은 값이 nil이거나 빈 문자열이면 "-"로 표시한다(Dto/User.swift
//  전 필드가 Optional String이라 nil-safe 처리가 필수).
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.presentationMode) private var presentationMode

    @State private var showPhotoPicker = false

    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        avatarSection
                        fieldList
                        actionButtons
                    }
                    .padding(.vertical, 24)
                }

                if viewModel.state.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
            }
            .toast(message: $viewModel.state.message)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear(perform: viewModel.load)
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectionLimit: 1) { images in
                if let image = images.first {
                    viewModel.pickImage(image)
                }
            }
        }
    }

    // Android onProfileImageClick(컨텍스트 메뉴 "앨범"/"카메라") 대응 — 브리프가 PhotoPicker(앨범)만
    // 요구하므로 카메라 옵션은 옮기지 않는다.
    private var avatarSection: some View {
        Button(action: { showPhotoPicker = true }) {
            ZStack(alignment: .bottomTrailing) {
                avatarImage
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())

                Image(systemName: "camera.fill")
                    .font(.system(size: 13))
                    .foregroundColorCompat(Color.white)
                    .padding(6)
                    .background(Circle().fill(Color.accentColor))
            }
        }
        .buttonStyle(.plain)
    }

    // pickedImage(적용 대기 미리보기)가 있으면 그것을, 없으면 appliedImage(이 화면에서 방금 적용에
    // 성공한 사진 — RemoteImage의 uid 고정 URL 캐시가 최신화되지 않아도 서버 재조회 없이 곧바로 보여줄
    // 수 있다, ProfileViewModel.applyPhoto() 코멘트 참고)를, 둘 다 없으면 서버 아바타
    // (EndPoint.userImage(uid:))를 보여준다.
    @ViewBuilder
    private var avatarImage: some View {
        if let pickedImage = viewModel.state.pickedImage {
            Image(uiImage: pickedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let appliedImage = viewModel.state.appliedImage {
            Image(uiImage: appliedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RemoteImage(
                urlString: viewModel.state.user?.uid.map(EndPoint.userImage(uid:)),
                placeholder: Image(systemName: "person.crop.circle.fill")
            )
            .aspectRatio(contentMode: .fill)
        }
    }

    // Android activity_profile.xml의 이름/학과/학번/학년/이메일/전화번호 필드 6종 그대로(값이 없으면 "-").
    private var fieldList: some View {
        VStack(spacing: 0) {
            fieldRow(title: "이름", value: viewModel.state.user?.name)
            Divider().padding(.leading, 16)
            fieldRow(title: "학과", value: viewModel.state.user?.department)
            Divider().padding(.leading, 16)
            fieldRow(title: "학번", value: viewModel.state.user?.number)
            Divider().padding(.leading, 16)
            fieldRow(title: "학년", value: viewModel.state.user?.grade)
            Divider().padding(.leading, 16)
            fieldRow(title: "이메일", value: viewModel.state.user?.email)
            Divider().padding(.leading, 16)
            fieldRow(title: "전화", value: viewModel.state.user?.phoneNumber)
        }
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        .padding(.horizontal, 16)
    }

    private func fieldRow(title: String, value: String?) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 56, alignment: .leading)

            Text(displayValue(value))
                .font(.system(size: 15))
                .foregroundColorCompat(.primary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private func displayValue(_ value: String?) -> String {
        guard let value = value, !value.isEmpty else {
            return "-"
        }
        return value
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            if viewModel.state.pickedImage != nil {
                Button(action: viewModel.applyPhoto) {
                    Text("적용")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.state.isLoading)
            }

            Button(action: viewModel.sync) {
                Text("LMS 동기화")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.state.isLoading)
        }
        .padding(.horizontal, 16)
    }
}
