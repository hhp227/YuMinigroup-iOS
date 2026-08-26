//
//  SplashView.swift
//  YuMinigroup
//
//  Android SplashActivity(1250ms 지연 후 loginLMS 재개) 대응. iOS 쪽은 최소 1.25초 노출 타이머와
//  autoLogin 네트워크 호출을 동시에 시작해, 둘 다 끝난 뒤에만 화면을 전환한다(먼저 끝난 쪽이 있어도
//  기다린다 — 브리프의 "병행" 지시).
//

import SwiftUI

struct SplashView: View {
    private static let minimumDisplayDuration: TimeInterval = 1.25

    @StateObject private var viewModel = SplashViewModel()

    let onLoginSuccess: () -> Void
    let onLoginFailure: () -> Void

    @State private var timerElapsed = false

    var body: some View {
        ZStack {
            Color("LaunchScreenBackgroundColor")
                .ignoresSafeArea()

            Image(systemName: "graduationcap.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 186, height: 110)
                .foregroundColor(.white)
        }
        .toast(message: $viewModel.message)
        .onAppear {
            viewModel.autoLogin()
            DispatchQueue.main.asyncAfter(deadline: .now() + SplashView.minimumDisplayDuration) {
                timerElapsed = true
                proceedIfReady()
            }
        }
        .onChange(of: viewModel.result) { _ in
            proceedIfReady()
        }
    }

    // 타이머와 autoLogin 둘 다 끝났을 때만 전환한다(하나만 끝난 상태로는 대기).
    private func proceedIfReady() {
        guard timerElapsed, let result = viewModel.result else {
            return
        }
        switch result {
        case .success:
            onLoginSuccess()
        case .failure:
            onLoginFailure()
        }
    }
}
