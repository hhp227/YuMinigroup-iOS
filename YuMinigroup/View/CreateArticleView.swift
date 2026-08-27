//
//  CreateArticleView.swift
//  YuMinigroup
//
//  Android activity/CreateArticleActivity(activity_create_article.xml) 대응 — 게시글 작성/수정 화면.
//  GroupView의 탭0 FAB(작성)과 ArticleView의 "수정" 메뉴(수정) 두 진입점이 .fullScreenCover로 이
//  화면을 띄운다 — 둘 다 별도 NavigationView 안에 있지 않은(GroupView는 이미 GroupMainView의 로컬
//  NavigationView에 push되어 있고, ArticleView도 그 안에 push되어 있다) 모달로 새로 띄우는 것이므로,
//  이 화면 자체가 로컬 NavigationView를 하나 더 열어 취소/등록(수정) 버튼이 달린 자기완결형 툴바를
//  갖는다(GroupMainView가 이미 쓰는 "이 화면은 로컬 NavigationView를 연다" 패턴과 동일).
//
//  카메라/앨범 선택은 Android onCreateContextMenu(ib_image 롱프레스 → "갤러리"/"카메라")를
//  .confirmationDialog(하단 사진 버튼 탭)로 옮겼다 — iOS에는 롱프레스 컨텍스트 메뉴 관례가 없고,
//  브리프도 confirmationDialog를 명시한다. 카메라는 CameraPicker(UIImagePickerController)를
//  fullScreenCover로, 앨범은 PhotoPicker(PHPickerViewController, 다중 선택)를 sheet로 띄운다 —
//  카메라는 전체화면이 표준 UX이고(Apple HIG), 앨범 피커는 시트로도 충분히 자연스럽다.
//
//  유튜브 첨부(3차 Task 10)는 confirmationDialog에 항목을 얹지 않고 "동영상 첨부" 버튼을 사진 버튼
//  옆에 별도로 뒀다 — Android CreateArticleActivity를 다시 보면 ib_image(갤러리/카메라 두 항목 메뉴)와
//  ib_video(유튜브 한 항목 메뉴)가 애초에 서로 다른 두 버튼이라(onCreateContextMenu의 두 case), 사진
//  버튼의 confirmationDialog에 "동영상" 항목을 끼워 넣는 쪽보다 별도 버튼이 오히려 더 가까운 미러다.
//  Android는 버튼을 누른 시점에 hasYoutubeItem()으로 막아 검색 화면 자체를 안 띄우지만, 이 뷰는
//  브리프가 못박은 attachYoutube(_:) 시그니처(1개 제한 체크가 함수 내부에 있음)를 그대로 따라 버튼은
//  항상 sheet를 열고, 검색에서 실제로 하나를 고른 시점(onPicked)에 viewModel.attachYoutube가 제한을
//  검사해 토스트를 띄운다 — 이미 첨부돼 있어도 재검색 자체는 막지 않는 사소한 UX 차이(더 관대한 쪽).
//
//  성공(viewModel.state.resultArticle이 non-nil로 바뀜) 시 onCompleted(article)을 부른 뒤 자신을
//  dismiss한다 — 작성/수정 두 진입점 모두 이 한 콜백만으로 충분하도록, "Tab1 반영"과 "헤더 재확장"은
//  전부 호출부(GroupView/ArticleView)의 onCompleted 클로저 안에서 처리한다(이 화면은 그 두 화면의
//  내부 상태(tab1ViewModel/appBarState/viewModel.state.article)를 전혀 모른다).
//

import SwiftUI

struct CreateArticleView: View {
    @StateObject private var viewModel: CreateArticleViewModel
    @Environment(\.presentationMode) private var presentationMode

    let onCompleted: (ArticleItem) -> Void

    @State private var showPickerDialog = false
    @State private var showCameraPicker = false
    @State private var showPhotoPicker = false
    @State private var showYoutubeSearch = false

    init(mode: CreateArticleMode, onCompleted: @escaping (ArticleItem) -> Void) {
        _viewModel = StateObject(wrappedValue: CreateArticleViewModel(mode: mode))
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationView {
            formBody
                .navigationTitle(viewModel.navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("취소") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(viewModel.actionTitle) {
                            viewModel.send()
                        }
                        .disabled(viewModel.state.isLoading)
                    }
                }
                .toast(message: $viewModel.state.message)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onChange(of: viewModel.state.resultArticle) { article in
            if let article = article {
                onCompleted(article)
                presentationMode.wrappedValue.dismiss()
            }
        }
    }

    // MARK: - 본문 (activity_create_article.xml: 제목/본문 헤더 + rv_write 대응)

    private var formBody: some View {
        ZStack {
            VStack(spacing: 0) {
                TextField("제목을 입력하세요.", text: $viewModel.state.title)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(12)

                Divider()

                contentEditor

                if !viewModel.state.existingImageUrls.isEmpty || !viewModel.state.images.isEmpty || viewModel.state.youtubeItem != nil {
                    Divider()
                    thumbnailStrip
                }

                Divider()

                photoButtonBar
            }

            if viewModel.state.isLoading {
                Color.black.opacity(0.05).ignoresSafeArea()
                ProgressView()
            }
        }
    }

    // TextEditor는 SwiftUI 표준 placeholder가 없어 빈 문자열일 때만 안내 텍스트를 겹쳐 그린다
    // (RemoteImage/기존 화면들이 이미 쓰는 ZStack 오버레이 관례).
    private var contentEditor: some View {
        ZStack(alignment: .topLeading) {
            if viewModel.state.content.isEmpty {
                Text("내용을 입력하세요.")
                    .foregroundColor(Color(uiColor: .placeholderText))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
            }
            TextEditor(text: $viewModel.state.content)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - 첨부 썸네일 (Android WriteListAdapter의 String/Bitmap 항목 대응)

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(viewModel.state.existingImageUrls.enumerated()), id: \.offset) { index, url in
                    thumbnail(onRemove: { viewModel.removeExistingImage(at: index) }) {
                        RemoteImage(urlString: url)
                            .aspectRatio(contentMode: .fill)
                    }
                }
                ForEach(Array(viewModel.state.images.enumerated()), id: \.offset) { index, image in
                    thumbnail(onRemove: { viewModel.removeNewImage(at: index) }) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                }
                if let youtubeItem = viewModel.state.youtubeItem {
                    thumbnail(onRemove: { viewModel.removeYoutube() }) {
                        ZStack {
                            RemoteImage(urlString: youtubeItem.thumbnail, placeholder: Image(systemName: "photo"))
                                .aspectRatio(contentMode: .fill)

                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColorCompat(.white)
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    @ViewBuilder
    private func thumbnail<Content: View>(onRemove: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(width: 72, height: 72)
                .clipped()
                .cornerRadius(6)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColorCompat(.white)
                    .background(Circle().fill(Color.black.opacity(0.5)))
            }
            .padding(2)
        }
    }

    // MARK: - 하단 사진/동영상 버튼 (Android ib_image/ib_video onCreateContextMenu 대응)

    private var photoButtonBar: some View {
        HStack(spacing: 20) {
            Button(action: { showPickerDialog = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20))
                    Text("사진 첨부")
                        .font(.subheadline)
                }
            }
            .foregroundColorCompat(.primary)

            Button(action: { showYoutubeSearch = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.rectangle")
                        .font(.system(size: 20))
                    Text("동영상 첨부")
                        .font(.subheadline)
                }
            }
            .foregroundColorCompat(.primary)

            Spacer()
        }
        .padding(12)
        .confirmationDialog("이미지 선택", isPresented: $showPickerDialog, titleVisibility: .visible) {
            Button("카메라") {
                showCameraPicker = true
            }
            Button("앨범") {
                showPhotoPicker = true
            }
            Button("취소", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCameraPicker) {
            CameraPicker { image in
                viewModel.addImage(image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPicker { images in
                viewModel.addImages(images)
            }
        }
        .sheet(isPresented: $showYoutubeSearch) {
            YouTubeSearchView(onPicked: viewModel.attachYoutube)
        }
    }
}
