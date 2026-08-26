//
//  ContentView.swift
//  YuMinigroup
//
//  루트 게이트 — PreferenceManager에 저장된 사용자 유무로 최초 phase를 정한다(있으면 .splash로
//  자동 로그인을 시도, 없으면 바로 .login). LoginView/SplashView가 로그인에 성공하면 .main으로
//  전환하고, Splash의 자동 로그인이 자격증명 거부로 실패하면 .login으로 되돌린다.
//  MainView(드로어의 로그아웃 항목)는 PreferenceManager.removeUser를 호출할 뿐 화면을 직접 전환하지
//  않는다 — 여기서 PreferenceManager.userPublisher를 구독해 user가 nil이 되는 순간(로그아웃 완료)을
//  감지하고 .login으로 되돌리는 쪽이, MainView/MainViewModel에 onLogout 콜백을 별도로 배선하는 것보다
//  PreferenceManager를 단일 진실 공급원으로 유지할 수 있어 더 단순하다고 판단했다(Task 9 결정).
//

import SwiftUI
import Combine

struct ContentView: View {
    private enum Phase: Equatable {
        case login
        case splash
        case main
    }

    @State private var phase: Phase

    init() {
        _phase = State(initialValue: PreferenceManager.shared.user == nil ? .login : .splash)
    }

    var body: some View {
        Group {
            switch phase {
            case .login:
                LoginView(onLoginSuccess: { phase = .main })
            case .splash:
                SplashView(onLoginSuccess: { phase = .main }, onLoginFailure: { phase = .login })
            case .main:
                MainView()
            }
        }
        .onReceive(PreferenceManager.shared.userPublisher) { user in
            if user == nil && phase == .main {
                phase = .login
            }
        }
    }
}
