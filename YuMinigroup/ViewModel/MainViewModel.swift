//
//  MainViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.MainViewModel + activity.MainActivity 대응 — 드로어 라우팅 상태 + 로그아웃
//  (PreferenceManager.removeUser + CookieStore.clear, Android CookieManager.removeAllCookies의
//  수동 쿠키 저장소 버전). 로그아웃 후 .login 화면으로의 전환은 이 VM이 직접 하지 않는다 — ContentView가
//  PreferenceManager.userPublisher를 구독해 user가 nil이 되는 순간을 감지해 처리한다(Task 9 결정,
//  task-9-report.md 참고). user는 Task 19 ProfileView 왕복까지 포함해 항상 PreferenceManager의
//  현재 값을 반영하도록 userPublisher를 구독해 채운다(초기값도 CurrentValueSubject라 즉시 채워진다).
//

import Foundation
import Combine

// Android res/menu/activity_main_drawer.xml 항목 순서 그대로(로그아웃은 라우트가 아니라 액션이라 제외).
// Task 10: chatList는 Android 드로어 메뉴에 없는 신설 항목이라(스펙 §4.5) 대응 원본 순서가 없다 —
// 스펙이 지시한 대로 groupMain 바로 다음에 끼워 넣는다(CaseIterable 순서 = 드로어 노출 순서).
enum MainRoute: CaseIterable, Equatable {
    case groupMain
    case chatList
    case univNotice
    case timetable
    case librarySeat
    case shuttleBus
}

final class MainViewModel: ObservableObject {
    @Published var route: MainRoute = .groupMain

    @Published var user: User?

    private var cancellables = Set<AnyCancellable>()

    init() {
        PreferenceManager.shared.userPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.user = user
            }
            .store(in: &cancellables)
    }

    // Android MainViewModel.logout() 대응. 화면 전환은 ContentView의 userPublisher 구독이 처리한다.
    func logout() {
        PreferenceManager.shared.removeUser()
        CookieStore.shared.clear()
    }
}
