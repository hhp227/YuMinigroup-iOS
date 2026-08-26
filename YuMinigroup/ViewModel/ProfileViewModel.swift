//
//  ProfileViewModel.swift
//  YuMinigroup
//
//  Android activity.ProfileActivity + viewmodel.ProfileViewModel 대응 — LMS 프로필 조회/동기화/사진
//  변경 상태. Android는 화면 진입 시 별도 fetch 없이 PreferenceManager에 저장된 값만 보여주지만(로그인
//  때 이미 스크랩된 정보), 이 포팅은 브리프 지시대로 load()가 UserRepository.fetchMyInfo를 한 번 더
//  호출해 최신 정보로 갱신한다 — 초기 state.user는 PreferenceManager.shared.user로 즉시 채워(빈 화면 없이
//  먼저 보여준 뒤) load() 완료 시 덮어쓴다.
//
//  sync()는 Android ProfileViewModel.sync()(myinfo_sync.acl 호출 후 mUser를
//  PreferenceManager.getUser()로 재대입 — PreferenceManager 자체는 그 사이 갱신되지 않으므로 실질적으로
//  no-op 재대입이다)와 달리, 브리프가 명시한 "재로드"를 그대로 따른다: 성공 메시지를 띄운 뒤 load()를
//  다시 호출해 서버가 갱신한 학사정보를 실제로 반영한다.
//
//  applyPhoto()는 Android ProfileViewModel.uploadImage(false)→성공 시 uploadImage(true) 연쇄 호출
//  대응 — UserRepository.updateProfileImage(imageData:)가 이미 그 2단계(미리보기 myinfo_file_update.acl
//  → 반영 myinfo_insert.acl)를 캡슐화하고 있어(Task 7, UserRemoteDataSource.swift 참고) 여기서는 한 번만
//  호출한다. 성공 시 PreferenceManager.storeUser로 현재 user를 재저장해 userPublisher를 통해 드로어
//  헤더/Tab4 프로필 행 등 다른 화면에도 갱신을 알린다.
//
//  아바타 URL(EndPoint.userImage(uid:))은 uid가 바뀌지 않는 한 그대로라 RemoteImage의 NSCache가 이전
//  사진을 계속 캐시하고 있을 수 있다(RemoteImage는 이 태스크의 수정 대상이 아니다). 그래서 applyPhoto()
//  성공 시 state.pickedImage(적용 대기 미리보기)를 그냥 지우는 대신 state.appliedImage로 옮겨 담아
//  ProfileView가 "이 화면에서 방금 적용한 사진"을 서버 재조회 없이 계속 보여주게 한다 — 이 화면(같은
//  ProfileViewModel 인스턴스가 살아있는 동안)만의 로컬 보정이고, 다른 화면(드로어 헤더/Tab4)이 여전히
//  bare uid URL을 쓰다 캐시가 갱신되기 전까지 이전 사진을 보여줄 수 있는 한계는 그대로 남는다(문서화된
//  알려진 한계, task-19-report.md 참고).
//

import UIKit

final class ProfileViewModel: ObservableObject {
    struct State {
        var user: User?
        var pickedImage: UIImage?
        var appliedImage: UIImage?
        var isLoading = false
        var message: String?
    }

    @Published var state: State

    private let userRepository: UserRepository

    init(userRepository: UserRepository = UserRepository()) {
        self.userRepository = userRepository
        self.state = State(user: PreferenceManager.shared.user)
    }

    // Android ProfileActivity.onCreate 진입 시 곧바로 보여주는 PreferenceManager 값과 달리, 최신
    // 정보를 서버에서 다시 읽어온다(브리프 지시). 성공 시 PreferenceManager도 최신 값으로 갱신해
    // userPublisher를 통해 드로어 헤더 등 다른 화면에도 반영되게 한다.
    func load() {
        userRepository.fetchMyInfo { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let user):
                self.state.isLoading = false
                PreferenceManager.shared.storeUser(user)
                self.state.user = user
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }

    // Android 컨텍스트 메뉴("앨범")로 고른 이미지 대응 — 적용(applyPhoto) 전까지는 미리보기로만 쓰인다.
    func pickImage(_ image: UIImage) {
        state.pickedImage = image
    }

    // Android sync() 대응(파일 상단 코멘트 참고) — myinfo_sync.acl 호출 후 최신 정보를 다시 읽어온다.
    func sync() {
        guard !state.isLoading else {
            return
        }
        userRepository.syncProfile { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let message):
                self.state.isLoading = false
                self.state.message = message
                self.load()
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }

    // Android uploadImage(false)→uploadImage(true) 연쇄 대응(파일 상단 코멘트 참고) — Android
    // bitmapResize(uri, 200)과 동일하게 maxSize 200으로 리사이즈한 뒤 전송한다. 성공 시 리사이즈된 이미지
    // 그대로를 state.appliedImage에 담아, ProfileView가 서버 재조회 없이 "방금 적용한 사진"을 곧바로
    // 보여주게 한다(파일 상단 코멘트 참고 — RemoteImage의 uid 고정 URL 캐시로는 이 화면 자체에서도
    // 최신 사진을 보여줄 수 없기 때문).
    func applyPhoto() {
        guard !state.isLoading, let image = state.pickedImage else {
            return
        }
        let resized = BitmapUtil.resized(image, maxSize: 200)

        guard let imageData = resized.jpegData(compressionQuality: 0.8) else {
            state.message = "이미지 처리에 실패했습니다."
            return
        }
        userRepository.updateProfileImage(imageData: imageData) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let message):
                self.state.isLoading = false
                self.state.message = message
                self.state.pickedImage = nil
                self.state.appliedImage = resized
                if let user = self.state.user {
                    PreferenceManager.shared.storeUser(user)
                }
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }
}
