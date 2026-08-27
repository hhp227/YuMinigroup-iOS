//
//  CreateGroupView.swift
//  YuMinigroup
//
//  Android activity/CreateGroupActivity(activity_create_group.xml) 대응 — 그룹 만들기 화면.
//  GroupMainView가 이미 로컬 NavigationView를 열어 두었으므로(하단 3버튼 바 + emptyBanner 두 진입점
//  모두 그 NavigationView 하위로 push된다) 이 화면 자체는 FindGroupView/RequestView와 동일하게 로컬
//  NavigationView를 새로 열지 않는다 — CreateArticleView(fullScreenCover 모달)와는 다른 경우다.
//
//  카메라/갤러리 선택은 스펙 §4.3·브리프 Step 3 그대로 confirmationDialog 3항목(카메라/갤러리/이미지
//  없음)만 명시하고 "취소"는 시스템이 자동으로 붙여준다(CreateArticleView의 confirmationDialog와 달리
//  이 화면은 Button("취소", role: .cancel)을 직접 추가하지 않는다 — 브리프 지시).
//
//  갤러리 결과와 카메라 결과 모두 BitmapUtil.resized(maxSize: 200)을 거친다 — Android
//  onCameraActivityResult가 갤러리 경로(Uri)에만 bitmapResize(200)를 적용하고 카메라 캡처(썸네일
//  Bitmap)는 그대로 쓰지만, 브리프가 "카메라 썸네일도 통일"하도록 명시적으로 지시했다.
//
//  성공(viewModel.state.created가 non-nil로 바뀜) 시 이 화면 자신을 dismiss(pop)한 뒤 onCreated(group)을
//  부른다 — GroupMainView.handleCreated가 새 그룹의 GroupView push를 담당한다(이 화면은 그 내부 상태를
//  모른다). Task 3(RequestView)의 교훈과 달리 이 화면은 성공 토스트가 스펙에 없으므로(전송중
//  오버레이 → 곧장 새 그룹 화면 진입이 Android 플로우 자체) dismiss를 지연시키지 않는다.
//

import SwiftUI

struct CreateGroupView: View {
    @StateObject private var viewModel = CreateGroupViewModel()
    @Environment(\.presentationMode) private var presentationMode

    @FocusState private var isTitleFocused: Bool

    @State private var showPickerDialog = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false

    let onCreated: (GroupItem) -> Void

    init(onCreated: @escaping (GroupItem) -> Void) {
        self.onCreated = onCreated
    }

    var body: some View {
        formBody
            .navigationTitle("그룹 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("생성", action: viewModel.createGroup)
                        .disabled(viewModel.state.isLoading)
                }
            }
            .toast(message: $viewModel.state.message)
            .onAppear {
                isTitleFocused = true
            }
            .onChange(of: viewModel.state.created) { group in
                if let group = group {
                    presentationMode.wrappedValue.dismiss()
                    onCreated(group)
                }
            }
    }

    // MARK: - 본문 (activity_create_group.xml: 제목 행 + 이미지 275dp + 설명(flexible) + 가입방식(하단 고정))

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
                Color.black.opacity(0.47).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("전송중...")
                        .foregroundColorCompat(.white)
                }
            }
        }
    }

    // MARK: - 그룹이름 (et_title + iv_reset 대응)

    private var titleRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                TextField("그룹이름 입력", text: $viewModel.title)
                    .focused($isTitleFocused)

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

    // MARK: - 그룹 이미지 (iv_group_image 275dp + onCreateContextMenu 대응)

    private var imageArea: some View {
        Group {
            if let image = viewModel.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, minHeight: 275, maxHeight: 275)
                    .clipped()
            } else {
                Image("add_photo")
                    .frame(maxWidth: .infinity, minHeight: 275, maxHeight: 275)
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
