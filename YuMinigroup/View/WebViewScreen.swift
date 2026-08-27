//
//  WebViewScreen.swift
//  YuMinigroup
//
//  Android activity.WebViewActivity(push용, 액션바 title+back) + fragment.BusFragment(드로어 인라인,
//  자체 toolbar) 대응 — 두 Android 화면이 같은 WebView 설정(JS on·loadWithOverviewMode·useWideViewPort)을
//  각자 복제해 쓰던 것을 iOS에서는 컨테이너만 다른 공통 컴포넌트 하나로 합친다. onMenuClick nil이면
//  push된 자식(WebViewActivity 대응 — 시스템 네비바 타이틀), onMenuClick이 있으면 드로어 루트
//  (BusFragment 대응 — AppToolbar 자체 배선, MainContentRouter가 NavigationView 조상 없이 직접
//  렌더하므로 GroupMainView/ChatListView와 달리 로컬 NavigationView가 불필요하다 — 이 화면 자신은
//  더 push할 자식이 없는 리프이기 때문).
//
//  줌(setBuiltInZoomControls/setSupportZoom)과 wide viewport(setUseWideViewPort)는 WKWebView가 기본
//  적용한다 — UIScrollView 핀치줌은 항상 가능하고, 페이지의 viewport 메타 태그 해석도 기본 켜져 있어
//  Android처럼 별도 WKWebpagePreferences 설정이 필요 없다. JS만 WKWebpagePreferences.allowsContentJavaScript
//  (iOS 14+, 이 타깃 iOS 15.6 안전)로 명시한다 — WKWebView는 기본으로도 JS가 켜져 있지만 Android 원본이
//  명시적으로 setJavaScriptEnabled(true)를 호출하므로 의도를 그대로 남긴다.
//

import SwiftUI
import WebKit

struct WebViewScreen: View {
    let urlString: String
    let title: String
    let onMenuClick: (() -> Void)?

    init(urlString: String, title: String, onMenuClick: (() -> Void)? = nil) {
        self.urlString = urlString
        self.title = title
        self.onMenuClick = onMenuClick
    }

    @State private var isLoading = true

    var body: some View {
        if let onMenuClick = onMenuClick {
            VStack(spacing: 0) {
                AppToolbar(title: title, navigationIcon: .menu, onNavigationClick: onMenuClick)

                webView
            }
        } else {
            webView
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var webView: some View {
        ZStack {
            WebView(urlString: urlString, isLoading: $isLoading)

            if isLoading {
                ProgressView()
            }
        }
    }

    // Android WebSettings(JS on·overview mode·wide viewport)를 WKWebView 기본값 + allowsContentJavaScript로
    // 대응한다(위 헤더 주석 참고). navigationDelegate는 didFinish/didFail/didFailProvisionalNavigation
    // 셋 다에서 isLoading을 내려 로딩 오버레이가 실패 시에도 계속 남지 않게 한다.
    //
    // updateUIView는 isLoading이 바뀔 때마다(로딩 완료 시 오버레이 제거로 상위 body가 재평가되면서) 다시
    // 불릴 수 있으므로, Coordinator에 마지막으로 로드를 요청한 urlString을 남겨 같은 URL을 반복 load하는
    // 재요청 루프를 막는다.
    private struct WebView: UIViewRepresentable {
        let urlString: String
        @Binding var isLoading: Bool

        func makeUIView(context: Context) -> WKWebView {
            let webView = WKWebView()
            webView.navigationDelegate = context.coordinator
            webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            return webView
        }

        func updateUIView(_ uiView: WKWebView, context: Context) {
            guard context.coordinator.lastLoadedURLString != urlString else { return }
            guard let url = URL(string: urlString) else {
                isLoading = false
                return
            }
            context.coordinator.lastLoadedURLString = urlString
            uiView.load(URLRequest(url: url))
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(isLoading: $isLoading)
        }

        final class Coordinator: NSObject, WKNavigationDelegate {
            @Binding var isLoading: Bool
            var lastLoadedURLString: String?

            init(isLoading: Binding<Bool>) {
                _isLoading = isLoading
            }

            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                isLoading = false
            }

            func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
                isLoading = false
            }

            func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
                isLoading = false
            }
        }
    }
}
