# YuMinigroup-iOS

영남대학교 소모임 앱 **YuMiniGroup**의 iOS 클라이언트입니다. [YuMiniGroup-Android](../YuMinigroup)의 **1:1 미러**로 SwiftUI 전면 재작성되었습니다 — 화면 구성·데이터 흐름·클래스명·백엔드 계약이 Android 버전과 동일하며, 기존(2021~2024년)에 있던 별도 PHP 백엔드 기반 SNS("OurStory") 코드는 이 마이그레이션에서 전량 삭제되었습니다.

## 앱 소개

- **플랫폼**: iOS 15.6+ (SwiftUI, `NavigationView` + `StackNavigationViewStyle` 기반 — iOS 16 전용 API인 `NavigationStack`/`navigationDestination`/`PhotosPicker`는 사용하지 않습니다)
- **백엔드**: 영남대 LMS(ilos) HTML 스크래핑 + 포털 SSO 쿠키 인증 + Firebase Realtime Database 하이브리드 (Android와 동일)
- **아키텍처**: Repository + Remote DataSource, `ObservableObject` 기반 ViewModel(`@Published var state`), `Resource<T>`(.loading/.success/.error) 비동기 계약. DI 프레임워크 없음 — Android 미러 관례를 그대로 따릅니다.

## 요구사항

- macOS + Xcode (iOS 15.6 배포 타깃을 지원하는 버전)
- Swift Package Manager로 `firebase-ios-sdk`를 resolve할 수 있는 네트워크 환경
- (선택) 실기기 테스트 시 iOS 15.x 기기 — 카메라 촬영 첨부 등 시뮬레이터로 확인하기 어려운 동작이 있습니다

## 빌드 방법

1. `YuMinigroup.xcodeproj`를 Xcode에서 엽니다.
2. **File → Packages → Resolve Package Versions**로 SPM 의존성(`firebase-ios-sdk` — FirebaseCore/FirebaseDatabase/FirebaseAuth)을 내려받습니다.
3. `⌘B`로 빌드합니다.
4. 실기기 또는 iOS 15.6 이상 시뮬레이터에서 실행합니다.

> 이 저장소는 WSL 환경에서 작업되어 Swift 컴파일이 검증되지 않은 상태로 커밋됩니다. 처음 빌드할 때 타입 오류가 나올 수 있으니, 자세한 절차는 `docs/superpowers/plans/2026-08-26-mac-build-checklist.md`를 참고하세요.

## GoogleService-Info.plist (Firebase)

앱은 번들에 `GoogleService-Info.plist`가 있을 때만 `FirebaseApp.configure()`를 호출합니다(`YuMinigroup/App/YuMinigroupApp.swift`):

```swift
if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
    FirebaseApp.configure()
}
```

Firebase 기능(게시글 이미지 목록/작성 타임스탬프 보강, 채팅 등)을 켜려면:

1. Firebase 콘솔에서 `yuminigroup` 프로젝트를 엽니다.
2. iOS 앱을 추가합니다 — 번들 ID는 반드시 **`com.hhp227.yu-minigroup`**.
3. 다운로드한 `GoogleService-Info.plist`를 `YuMinigroup/` 타깃(YuMinigroup 앱 타깃)에 추가합니다.

**주의**: 루트 등 다른 곳에 있을 수 있는 기존 `GoogleService-Info.plist`는 자매 프로젝트 KnuMiniGroup-iOS용(`hhp227-ed727` 프로젝트)이므로 이 앱에 그대로 쓸 수 없습니다. 반드시 `yuminigroup` 프로젝트에서 새로 발급받은 plist를 사용하세요.

**plist 없이도 앱은 정상 기동합니다.** LMS 스크래핑 기반 핵심 기능(로그인, 그룹 목록/상세, 게시글 CRUD, 댓글, 프로필)은 Firebase 없이 전부 동작하며, Firebase가 보강하는 것은 이미지 목록·작성 시각·uid 매칭 같은 부가 정보뿐입니다.

## 백엔드 모델

Android와 동일하게 세 축을 조합합니다:

- **LMS(ilos) HTML 스크래핑**: `lms.yu.ac.kr/ilos/...` 엔드포인트(`share_group_list`, `share_list`, `share_insert/update/delete`, `share_comment_*`, `share_member_list`, `myinfo_form/sync`, `file_upload_pop` 등)의 응답 HTML을 위치 기반으로 파싱합니다(`HtmlUtil`).
- **포털 SSO 쿠키 인증**: `login_sso.acl` → `portal.yu.ac.kr/sso/login_process.jsp`(고정 `p=` 블롭 + `Referer` 헤더 필수) → `login_sso.acl` 재호출의 3단계 시퀀스로 세션을 확립하고, 이후 모든 요청·이미지 로딩에 쿠키를 수동으로 부착합니다(`HttpClient`).
- **Firebase RTDB**: `yuminigroup` 프로젝트의 Realtime Database에 게시글/댓글 이중 기록(LMS 성공 후 목록 재조회로 id 획득 → Firebase 기록) — 이미지 목록·타임스탬프·uid 보강용이며 필수 경로는 아닙니다.

## 범위 (1차 코어)

**포함**: 로그인/스플래시(SSO 로그인, 저장 자격증명 자동 재로그인) → 드로어 셸(MainView) → 가입 그룹 그리드(GroupMainView) → 그룹 상세(GroupView, CollapsingHeader + 4탭: 소식/일정/맴버/설정) → 게시글 목록·상세·작성/수정·댓글 CRUD·이미지 첨부(카메라/앨범) → 프로필 조회/동기화/사진 변경.

**후속(2차)로 미룸**: 그룹 찾기/생성/가입신청중, Firebase 채팅(그룹/1:1), 대학 유틸리티(영대소식·시간표·도서관좌석·순환버스), AdMob, 푸시 알림. 드로어 메뉴에 자리는 있으나 "준비중" 화면으로 처리되어 있습니다.

자세한 설계 근거와 결정 기록은 `docs/superpowers/specs/2026-08-26-yuminigroup-ios-migration-design.md`, 태스크 단위 진행 로그는 `.superpowers/sdd/2026-08-26-yuminigroup-ios-core-migration/progress.md`를 참고하세요.
