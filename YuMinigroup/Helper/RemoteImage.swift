//
//  RemoteImage.swift
//  YuMinigroup
//
//  KNU-iOS Helper/ImageLoader.swift의 NSCache 로딩 로직을 SwiftUI 뷰로 재구성.
//  LMS가 내려주는 이미지는 세션 쿠키 없이는 404/리다이렉트되므로, CookieStore.shared.cookieHeader를
//  "Cookie" 요청 헤더로 직접 부착해 URLSession으로 로딩한다 (iOS 15 대응을 위해 AsyncImage는 쓰지 않는다).
//

import SwiftUI

struct RemoteImage: View {
    private let urlString: String?
    private let placeholder: Image

    @State private var uiImage: UIImage?

    private static let cache = NSCache<NSString, UIImage>()

    init(urlString: String?, placeholder: Image = Image(systemName: "photo")) {
        self.urlString = urlString
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                placeholder
                    .resizable()
            }
        }
        .onAppear(perform: load)
        .onChange(of: urlString) { _ in
            // 뷰 정체성은 그대로인 채 urlString만 바뀌는 경우(리스트 셀 재사용 등) .onAppear가 다시
            // 불리지 않으므로, 값이 바뀔 때 캐시된 이미지를 비우고 새로 로드한다(리뷰 IMPORTANT 5).
            uiImage = nil
            load()
        }
    }

    private func load() {
        guard uiImage == nil, let urlString = urlString, let url = URL(string: urlString) else {
            return
        }
        if let cached = RemoteImage.cache.object(forKey: urlString as NSString) {
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
            RemoteImage.cache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                self.uiImage = image
            }
        }.resume()
    }
}
