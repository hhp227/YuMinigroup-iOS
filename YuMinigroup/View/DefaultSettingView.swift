//
//  DefaultSettingView.swift
//  YuMinigroup
//
//  Android fragment/DefaultSettingFragment(fragment_default_setting.xml + menu/modify.xml) 대응 —
//  그룹 설정 "모임정보" 탭. CreateGroupView의 폼 구성(제목 행+클리어 / 이미지 275pt / 설명
//  TextEditor / 하단 가입방식 라디오)을 그대로 미러하되 두 가지가 다르다:
//
//  ①이미지: 새로 선택된 이미지가 없으면(viewModel.image == nil) CreateGroupView처럼 "add_photo"
//  플레이스홀더를 보여주지 않고 기존 그룹 이미지(viewModel.existingImageURL, 쿠키 로딩 RemoteImage)를
//  보여준다 — 이 화면엔 "이미 이미지가 있는 그룹"이 전제이기 때문이다. confirmationDialog의 "이미지
//  없음" 버튼도 같은 이유로 "그룹에 이미지가 없어짐"이 아니라 "새로 고른 이미지 선택을 취소하고 기존
//  이미지로 되돌아감"으로 동작한다(브리프 "새 선택 취소=기존 유지" — 서버에 이미지 삭제 API가 없어
//  실제로 지울 방법이 없다, 스펙 §5.4 "이미지 없음 선택 시 업로드 생략(이미지 필드 유지)"). viewModel.
//  image = nil로 되돌리기만 하면 이 imageArea 분기가 자동으로 기존 이미지를 다시 보여준다.
//
//  ②로딩 오버레이: CreateGroupView가 붙인 "전송중..." 캡션+딤 배경 스크림은 이 화면에는 없다 —
//  Android fragment_default_setting.xml의 ProgressBar도 캡션/스크림 없이 그냥 중앙 스피너이고
//  (line 125-132), 이 화면의 isLoading은 초기 GET 로드와 POST 저장 두 단계를 모두 아우르므로
//  "전송중"이라는 저장 전용 문구가 항상 맞지는 않는다 — Android 원본 그대로 캡션 없는 스피너만 둔다.
//
//  toolbar "수정"(menu/modify.xml action_send) 탭 → viewModel.updateGroup(). 성공(viewModel.state.
//  updated가 non-nil) 시 DefaultSettingViewModel 헤더 코멘트가 설명하는 대로 message(토스트)는 즉시,
//  onUpdated 호출+pop은 1.2초 뒤(FindGroupView 관례) — presentationMode.dismiss()는 이 화면 자신이
//  아니라 SettingsView를 pop한다: DefaultSettingView는 SettingsView 안에서 탭 전환(if/else)으로만
//  나타나는 평범한 자식 뷰라 별도 push/sheet 경계를 새로 열지 않으므로, presentationMode 환경값이
//  SettingsView가 push된 그 경계를 그대로 가리킨다(Tab4View가 GroupView를 pop하는 것과 동일한 전례).
//

import SwiftUI

struct DefaultSettingView: View {
    @ObservedObject var viewModel: DefaultSettingViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var showPickerDialog = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false

    let onUpdated: (_ name: String, _ description: String, _ joinType: String, _ imageURL: String?) -> Void

    var body: some View {
        formBody
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("수정", action: viewModel.updateGroup)
                        .disabled(viewModel.state.isLoading)
                }
            }
            .toast(message: $viewModel.state.message)
            .onChange(of: viewModel.state.updated) { updated in
                guard let updated = updated else {
                    return
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    presentationMode.wrappedValue.dismiss()
                    onUpdated(updated.name, updated.description, updated.joinType, updated.imageURL)
                }
            }
    }

    // MARK: - 본문 (fragment_default_setting.xml: 제목 행 + 이미지 275dp + 설명(flexible) + 가입방식)

    private var formBody: some View {
        ZStack {
            VStack(spacing: 0) {
                titleRow

                Divider()

                imageArea

                Divider()

                descriptionArea

                Divider()

                joinTypeBar
            }

            if viewModel.state.isLoading {
                ProgressView()
            }
        }
    }

    // MARK: - 그룹이름 (et_title + iv_reset 대응, CreateGroupView.titleRow와 동일 — <requestFocus/>는 없음)

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TextField("그룹이름 입력", text: $viewModel.title)

                Button(action: { viewModel.title = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColorCompat(viewModel.title.isEmpty ? Color(uiColor: .systemGray3) : Color(uiColor: .darkGray))
                }
            }
            .padding(12)

            if let titleError = viewModel.state.titleError {
                Text(titleError)
                    .font(.caption)
                    .foregroundColorCompat(.red)
                    .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - 그룹 이미지 (iv_group_image 275dp — 새 선택 전엔 기존 URL, onCreateContextMenu 대응)

    private var imageArea: some View {
        Group {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 275, maxHeight: 275)
                    .clipped()
            } else {
                RemoteImage(urlString: viewModel.existingImageURL)
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, minHeight: 275, maxHeight: 275)
                    .clipped()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showPickerDialog = true
        }
        .confirmationDialog("이미지 선택", isPresented: $showPickerDialog, titleVisibility: .visible) {
            Button("카메라") {
                showCameraPicker = true
            }
            Button("갤러리") {
                showPhotoPicker = true
            }
            Button("이미지 없음") {
                viewModel.image = nil
                viewModel.state.message = "이미지 없음 선택"
            }
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker { image in
                viewModel.image = BitmapUtil.resized(image, maxSize: 200)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker(selectionLimit: 1) { images in
                if let first = images.first {
                    viewModel.image = BitmapUtil.resized(first, maxSize: 200)
                }
            }
        }
    }

    // MARK: - 그룹 설명 (et_description, weight=1 → flexible 대응)

    private var descriptionArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .topLeading) {
                if viewModel.descriptionText.isEmpty {
                    Text("그룹 설명을 입력하세요.")
                        .foregroundColor(Color(uiColor: .placeholderText))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 20)
                }
                TextEditor(text: $viewModel.descriptionText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
            }
            .frame(maxHeight: .infinity)

            if let descriptionError = viewModel.state.descriptionError {
                Text(descriptionError)
                    .font(.caption)
                    .foregroundColorCompat(.red)
                    .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - 가입방식 (rg_jointype, layout_constraintBottom_toBottomOf="parent" → 하단 고정 대응)

    private var joinTypeBar: some View {
        HStack(spacing: 16) {
            Text("가입방식")
                .font(.subheadline)

            Spacer()

            joinTypeButton(title: "자동 승인", isSelected: viewModel.isAutoJoin) {
                viewModel.isAutoJoin = true
            }
            joinTypeButton(title: "승인 확인", isSelected: !viewModel.isAutoJoin) {
                viewModel.isAutoJoin = false
            }
        }
        .padding(12)
    }

    private func joinTypeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColorCompat(isSelected ? .accentColor : .secondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundColorCompat(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
