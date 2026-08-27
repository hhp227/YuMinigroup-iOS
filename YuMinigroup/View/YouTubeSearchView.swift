//
//  YouTubeSearchView.swift
//  YuMinigroup
//
//  Android activity/YouTubeSearchActivity.java(+res/layout/youtube_item.xml, res/menu/search.xml)
//  대응 — 자기완결형 모달(ProfileView 관례: 자체 NavigationView + 좌상단 닫기 X). Android는 액션바에
//  SearchView 하나만 올리고 별도 타이틀이 없지만(onCreateOptionsMenu), 이 리포의 모달 관례상 네비게이션
//  타이틀이 필요해 "동영상 검색"을 쓴다(브리프 지시 — Android가 액션바 SearchView뿐이라 타이틀은
//  자유).
//
//  검색바는 Android SearchView(res/menu/search.xml, hint "검색어를 입력하세요.") 대신 TextField+
//  돋보기 버튼 — onSubmit과 버튼 둘 다 viewModel.submitSearch()로 이어진다(Android
//  onQueryTextSubmit(query) → mViewModel.setQuery(query) 대응). 목록은 ScrollView+LazyVStack(이
//  리포 전역 컨벤션 — UnivNoticeView/SeatView와 동일, List 미사용). 행은 youtube_item.xml 그대로:
//  160×90 썸네일(RemoteImage) + 제목 16pt bold 4줄 + 채널 12pt 1줄(재생시간 duration 뱃지는 Android도
//  값을 채우지 않는 빈 TextView라 옮기지 않는다).
//
//  행 탭 → onPicked(item) 후 자체 dismiss(Android
//  intent.putExtra("youtube", youTubeItem); setResult(RESULT_OK, intent); finish() 대응 — Task 10에서
//  CreateArticleView가 .sheet/.fullScreenCover로 이 화면을 띄우고 onPicked로 선택 결과를 돌려받는다).
//

import SwiftUI

struct YouTubeSearchView: View {
    @StateObject private var viewModel = YoutubeSearchViewModel()
    @Environment(\.presentationMode) private var presentationMode
    @FocusState private var isSearchFocused: Bool

    let onPicked: (YouTubeItem) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    searchBar

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.state.items) { item in
                                Button(action: {
                                    onPicked(item)
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    YouTubeSearchRow(item: item)
                                }
                                .buttonStyle(.plain)

                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }

                if viewModel.state.isLoading {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    ProgressView()
                }
            }
            .navigationTitle("동영상 검색")
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
    }

    // Android res/menu/search.xml의 SearchView(queryHint "검색어를 입력하세요.") 대응.
    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("검색어를 입력하세요.", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .onSubmit {
                    isSearchFocused = false
                    viewModel.submitSearch()
                }

            Button(action: {
                isSearchFocused = false
                viewModel.submitSearch()
            }) {
                Image(systemName: "magnifyingglass")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// Android youtube_item.xml 대응 — FrameLayout(160×90 썸네일) + 제목/채널 텍스트 컬럼.
private struct YouTubeSearchRow: View {
    let item: YouTubeItem

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RemoteImage(urlString: item.thumbnail, placeholder: Image(systemName: "photo"))
                .aspectRatio(contentMode: .fill)
                .frame(width: 160, height: 90)
                .clipped()

            VStack(alignment: .leading, spacing: 5) {
                Text(item.title)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(4)
                    .foregroundColorCompat(.primary)

                Text(item.channelTitle)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
    }
}
