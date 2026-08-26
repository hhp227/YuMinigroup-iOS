//
//  PictureView.swift
//  YuMinigroup
//
//  Android activity/PictureActivity(activity_picture.xml, 검정 배경 + 투명 툴바 + ViewPager + "N / M"
//  카운트) 대응 — 게시글 이미지 풀스크린 뷰어. ViewPager+PicturePagerAdapter는 TabView(.page)로,
//  페이지별 ZoomImageView(Matrix 기반 핀치/팬)는 아래 ZoomableImage(MagnificationGesture+DragGesture
//  기반)로 옮긴다 — ZoomImageView의 Matrix 클램핑(이미지가 화면 밖으로 나가지 않도록 정밀 보정)까지
//  픽셀 단위로 재현하지는 않지만, 같은 동작(핀치로 확대/축소, 확대 상태에서 드래그로 팬, 더블탭으로
//  1배 리셋)을 SwiftUI 표준 제스처로 재현한다.
//
//  RemoteImage(Helper/RemoteImage.swift)는 View라서 스케일/오프셋 제스처를 직접 얹을 UIImage를 얻을
//  수 없고, 브리프도 RemoteImage를 건드리지 말라고 명시한다 — 그래서 RemoteImage.load()와 같은
//  쿠키 부착 URLSession 로딩을 이 파일 안에 로컬로 복제한다(LMS 이미지는 세션 쿠키 없이는 404/
//  리다이렉트되므로 CookieStore.shared.cookieHeader를 "Cookie" 헤더로 직접 부착 — RemoteImage.swift
//  코멘트와 동일한 이유, iOS 15 대응을 위해 AsyncImage도 쓰지 않는다).
//
//  article.images는 ArticleRemoteDataSource가 이미 완전한 이미지 URL로 파싱해 둔 배열이라(
//  ArticleView.imageList/ArticleListCell이 그 문자열을 그대로 RemoteImage(urlString:)에 넘기는 것과
//  동일하게) 이 화면도 별도 URL 조립 없이 그대로 사용한다.
//
//  Android의 tv_count(imageList.size() > 1일 때만 노출)와 홈 버튼(뒤로가기)을 각각 카운트 라벨 +
//  좌상단 닫기(X) 버튼으로 옮긴다 — 이 화면은 ArticleView가 fullScreenCover로 띄우는 모달이라
//  NavigationView의 back 버튼이 없으므로 명시적 닫기 버튼이 필요하다(CreateArticleView의 "취소"
//  버튼과 같은 이유).
//

import SwiftUI

struct PictureView: View {
    @StateObject private var viewModel: PictureViewModel
    @Environment(\.presentationMode) private var presentationMode

    init(images: [String], initialIndex: Int) {
        _viewModel = StateObject(wrappedValue: PictureViewModel(images: images, initialIndex: initialIndex))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $viewModel.state.index) {
                ForEach(Array(viewModel.state.images.enumerated()), id: \.offset) { index, url in
                    ZoomableImage(urlString: url)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    closeButton
                    Spacer()
                }
                Spacer()
            }

            if viewModel.state.images.count > 1 {
                VStack {
                    countLabel
                    Spacer()
                }
            }
        }
        .statusBar(hidden: true)
    }

    private var closeButton: some View {
        Button(action: { presentationMode.wrappedValue.dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColorCompat(.white)
                .padding(14)
        }
    }

    // Android tv_count("position + 1 + ' / ' + imageList.size()") 대응.
    private var countLabel: some View {
        Text("\(viewModel.state.index + 1) / \(viewModel.state.images.count)")
            .font(.system(size: 16, weight: .bold))
            .foregroundColorCompat(.white)
            .padding(.top, 20)
    }
}

// MARK: - 핀치 줌 + 쿠키 부착 로딩 페이지 (Android ZoomImageView 상당)

private struct ZoomableImage: View {
    let urlString: String

    @State private var uiImage: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private static let cache = NSCache<NSString, UIImage>()
    private static let minScale: CGFloat = 1
    private static let maxScale: CGFloat = 5

    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(scale)
        .offset(offset)
        .gesture(magnification)
        .simultaneousGesture(pan)
        .onTapGesture(count: 2, perform: resetZoom)
        .onAppear(perform: load)
    }

    // 핀치로 확대/축소 — Android matrixTurning의 "10배 이상 커지지 않는다" 클램프를 5배로 단순화하고,
    // 1배 밑으로는 내려가지 않게 한다(Android도 "원본보다 작아지지 않는다"는 동일한 방향의 제약을 둔다).
    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, ZoomableImage.minScale), ZoomableImage.maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= ZoomableImage.minScale {
                    resetZoom()
                }
            }
    }

    // 확대된 상태에서만 팬 — TabView(.page) 자체의 스와이프 페이징과 동시에 인식되도록
    // simultaneousGesture로 붙인다(1배일 때는 onChanged가 아무 것도 바꾸지 않아 페이징을 방해하지 않는다).
    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > ZoomableImage.minScale else {
                    return
                }
                offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    // Android onTouch의 더블탭 리셋 상당(ZoomImageView 자체엔 더블탭이 없지만 브리프가 명시적으로
    // 요구한다) — 1배로 되돌리고 팬 오프셋도 함께 초기화한다.
    private func resetZoom() {
        withAnimation {
            scale = ZoomableImage.minScale
            lastScale = ZoomableImage.minScale
            offset = .zero
            lastOffset = .zero
        }
    }

    // RemoteImage.load()와 동일한 쿠키 부착 로딩(파일 상단 코멘트 참고) — 로컬 NSCache로 재요청을 줄인다.
    private func load() {
        guard uiImage == nil, let url = URL(string: urlString) else {
            return
        }
        if let cached = ZoomableImage.cache.object(forKey: urlString as NSString) {
            uiImage = cached
            return
        }
        var request = URLRequest(url: url)

        if let cookieHeader = CookieStore.shared.cookieHeader {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard error == nil, let data = data, let image = UIImage(data: data) else {
                return
            }
            ZoomableImage.cache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                self.uiImage = image
            }
        }.resume()
    }
}
