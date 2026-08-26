# YuMinigroup-iOS 코어 마이그레이션 구현 계획 (1차)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** YuMinigroup-iOS를 YuMiniGroup-Android의 1:1 미러(SwiftUI)로 재작성 — SSO 로그인부터 그룹상세 4탭(CollapsingHeader)·게시글·댓글·프로필까지 코어 플로우 완성.

**Architecture:** SwiftUI(iOS 15.6) + ObservableObject VM + Repository/RemoteDataSource(LMS 스크래핑+Firebase RTDB 이중기록). UI 공용부는 ParallaxTabLayout iOS 킷 이식, 데이터층은 KnuMiniGroup-iOS(동일 ilos LMS)의 검증 로직을 YU 엔드포인트로 번안.

**Tech Stack:** SwiftUI, Combine, URLSession(수동 쿠키), XMLParser, PHPickerViewController, firebase-ios-sdk(SPM: FirebaseDatabase·FirebaseAuth)

**Spec:** `docs/superpowers/specs/2026-08-26-yuminigroup-ios-migration-design.md` — 각 태스크 구현 전 해당 스펙 섹션을 먼저 읽을 것.

## Global Constraints

- 배포 타깃 **iOS 15.6** (`IPHONEOS_DEPLOYMENT_TARGET`). iOS 16 전용 API 금지: `NavigationStack`·`navigationDestination`·`PhotosPicker` 사용 불가 → `NavigationView`+`NavigationLink(isActive:)`+`StackNavigationViewStyle`, 이미지 선택은 `PHPickerViewController` representable. iOS 16 분기가 필요하면 `View/UI/Compat.swift` 패턴(`#available(iOS 16.0, *)`)만 사용.
- **이 환경(WSL)은 Swift 컴파일 불가.** 태스크별 검증 = ①인터페이스 정합(grep) ②pbxproj 등록 정합 ③참조 소스와 대조. 빌드·실행 검증은 최종 태스크의 Mac 체크리스트로 사용자에게 이관. 표준 TDD 사이클(실패 테스트 실행)은 적용 불가하므로 테스트 타깃 없음(스펙 §9, Android 미러).
- **커밋 규칙(2026-08-26 사용자 승인으로 개정)** — 작업 브랜치는 `feature/android-mirror`. 각 태스크는 수정·생성 파일을 **경로 지정 `git add` 후 해당 태스크 단위로 커밋**한다(`git add -A` 금지). 커밋 메시지는 한 줄 관례형(`feat:`/`refactor:` 등)이며 **Co-Authored-By 등 트레일러 금지**. push 금지 — develop 병합·push는 사용자. 각 태스크 마지막의 "스테이징" 단계는 "경로 지정 add + 커밋"으로 읽는다.
- 새 파일은 **LF** 개행으로 작성(현재 워크트리는 전면 LF 정규화됨).
- **pbxproj 수동 등록**: 파일 생성/삭제 태스크는 같은 태스크 안에서 `YuMinigroup.xcodeproj/project.pbxproj`의 PBXFileReference·PBXBuildFile·PBXGroup·PBXSourcesBuildPhase 4곳을 함께 갱신. ID는 기존 `0AF55...` 스타일과 충돌하지 않는 24자리 hex를 새로 발급(예: `YU000001...` 접두 순번). 등록 후 `grep`으로 4곳 모두 존재 확인.
- **미러 명명**: 클래스·메소드명은 Android(`com.hhp227.yu_minigroup`)와 동일. 비동기는 `Resource<T>`(loading/success/error) 수렴, `try!`·`fatalError` 금지.
- **레거시 로그 핑 제외**: Android `LoginViewModel`의 `CREATE_LOG`(`knu.dothome.co.kr`, 비밀번호 전송) 블록은 절대 이식하지 않는다.
- 참조 리포 경로(모두 읽기 전용): Android=`../YuMiniGroup-Android/app/src/main/java/com/hhp227/yu_minigroup/`, KNU-iOS=`../KnuMiniGroup-iOS/knu_minigroup/`, UI킷=`../ParallaxTabLayout/iOS/ParallaxTabLayout/`.

---

### Task 1: 기존 코드 철거 + 프로젝트 골격

**Files:**
- Delete: `YuMinigroup/Api/`, `YuMinigroup/Data/`, `YuMinigroup/Helper/`(전체 — Paging 포함), `YuMinigroup/Model/`, `YuMinigroup/Util/`, `YuMinigroup/View/`, `YuMinigroup/ViewModel/` 전체
- Keep: `YuMinigroup/App/YuMinigroupApp.swift`(임시 본문으로 교체), `YuMinigroup/Assets.xcassets/`, `YuMinigroup/Info.plist`, `YuMinigroup/Preview Content/`
- Modify: `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: 빈 골격 프로젝트. `YuMinigroupApp` body = `Text("YuMinigroup")` 임시. 이후 모든 태스크가 이 위에 파일을 추가한다.

- [ ] **Step 1: 파일 삭제** — `git rm -r` 로 위 Delete 목록 제거 (스테이징 동시 처리).
- [ ] **Step 2: YuMinigroupApp.swift 임시 본문**

```swift
import SwiftUI

@main
struct YuMinigroupApp: App {
    var body: some Scene {
        WindowGroup {
            Text("YuMinigroup")
        }
    }
}
```

- [ ] **Step 3: pbxproj 정리** — 삭제된 모든 파일의 PBXFileReference/PBXBuildFile/PBXGroup 자식/Sources 항목 제거. 그룹 트리는 `App`, `Assets.xcassets`, `Info.plist`, `Preview Content`만 남긴다.
- [ ] **Step 4: 검증** — `grep -c "\.swift" project.pbxproj` 결과가 YuMinigroupApp.swift 관련 2건(FileRef+BuildFile)뿐인지, `find YuMinigroup -name "*.swift"`가 1개인지 확인.
- [ ] **Step 5: 스테이징** — `git add YuMinigroup.xcodeproj/project.pbxproj YuMinigroup/App/YuMinigroupApp.swift` (삭제는 Step 1에서 이미 스테이징됨).

---

### Task 2: ParallaxTabLayout UI 킷 이식

**Files:**
- Create: `YuMinigroup/View/UI/Compat.swift`, `AppToolbar.swift`, `FloatingActionButton.swift`, `DrawerScaffold.swift`, `RefreshableLazyColumn.swift`, `CollapsingHeader.swift`
- Modify: `project.pbxproj` (View/UI 그룹 신설+6파일 등록)

**Interfaces:**
- Produces:
  - `CollapsingListScaffold(title:navigationIcon:onNavigationClick:showTabs:tabTitles:[String],selectedTab:Binding<Int>,collapseOffset:Binding<CGFloat>,onTabSelected:(Int)->Void,imageHeight:CGFloat = 256,headerBackground:()->HeaderBG,content:(_ headerHeight: CGFloat,_ appBarState: CollapsingAppBarState)->Content)` — 원본에서 **일반화 2가지**: ①탭 라벨 하드코딩("First"/"Second") → `tabTitles: [String]` ②`HeaderBackground()`(그라디언트) → `@ViewBuilder headerBackground` 주입 + `imageHeight` 파라미터화(기본 256, 그룹상세는 200 전달)
  - `CollapsingAppBarState { isExpanded: Bool; setExpanded: (Bool)->Void }`, `CollapsingHeaderSpacer`, `ScrollOffsetPreferenceKey`, `collapsingScrollCoordinateSpace`
  - `AppToolbar(title:navigationIcon:onNavigationClick:transparent:)`, `NavigationIcon`(.back/.menu 등 — 원본 enum 그대로)
  - `DrawerScaffold`, `RefreshableLazyColumn(items:headerHeight:isRefreshEnabled:isScrollTrackingEnabled:content:)`, `FloatingActionButton`
  - Compat: `navigationBarHiddenCompat()`, `foregroundColorCompat(_:)`, `navigationBarTintColorCompat(_:)`, `navigationBarBackgroundColorCompat(_:)`

- [ ] **Step 1: 원본 6파일 복사** — `../ParallaxTabLayout/iOS/ParallaxTabLayout/UI/{Compat,AppToolbar,DrawerScaffold,FloatingActionButton,RefreshableLazyColumn,CollapsingHeader}.swift` → `YuMinigroup/View/UI/`. 파일 헤더 주석의 프로젝트명은 `YuMinigroup`으로.
- [ ] **Step 2: CollapsingHeader 일반화** — 위 Produces 시그니처대로 `tabTitles`/`headerBackground`/`imageHeight`를 파라미터로 승격. `HeaderView`의 `TabButton` 나열을 `ForEach(tabTitles.indices)`로, `HeaderBackground()` 호출을 주입 뷰로 교체. 나머지 collapse 로직(`ignoresNextExpansion`, bounce 처리)은 **한 줄도 변경 금지**.
- [ ] **Step 3: pbxproj 등록** (View/UI 그룹 신설) → 4곳 grep 검증.
- [ ] **Step 4: 자체 점검** — 원본과 diff하여 의도한 일반화 외 변경이 없는지 확인.
- [ ] **Step 5: 스테이징** — 6파일+pbxproj 경로 지정 add.

---

### Task 3: Helper 기반 계층

**Files:**
- Create: `YuMinigroup/Helper/Resource.swift`, `AppError.swift`, `HttpClient.swift`, `CookieStore.swift`, `HtmlUtil.swift`, `MultipartRequest.swift`, `PreferenceManager.swift`, `DateUtil.swift`, `BitmapUtil.swift`, `Toast.swift`, `RemoteImage.swift`
- Modify: `project.pbxproj`

**Interfaces:**
- Produces:
  - `enum Resource<T> { case loading; case success(T); case error(String, T? = nil) }` (KNU-iOS `Helper/Resource.swift` 포트)
  - `struct AppError: LocalizedError { let message: String }`
  - `enum HttpClient`:
    - `request(_ urlString:, method: String = "GET", headers: [String:String] = [:], formParams: [String:String]? = nil, completion: @escaping (Result<String,Error>)->Void)` — 본문 문자열 반환(UTF-8→EUC-KR 폴백)
    - `requestWithHeaders(...same..., completion: @escaping (Result<(body: String, setCookies: [String]),Error>)->Void)` — SSO용: `HTTPURLResponse.value(forHTTPHeaderField:)`가 Set-Cookie를 병합하므로 **`allHeaderFields`를 순회해 "Set-Cookie" 원본 배열 수집**
    - 내부 `URLSession`은 `URLSessionConfiguration.ephemeral` + `httpCookieAcceptPolicy = .never` + `httpShouldSetCookies = false` (쿠키 전면 수동) + **redirect 미추적 delegate**(SSO 응답의 Set-Cookie 소실 방지) + portal 호스트 한정 TLS 예외 delegate(`urlSession(_:didReceive challenge:)`에서 host == "portal.yu.ac.kr"일 때만 `.useCredential` — Android `SSLConnect` 미러)
  - `final class CookieStore { static let shared; func store(_ cookie: String); var cookieHeader: String? ; func clear() }` — `SESSION_IMAX`/`ssotoken` 등 name=value 조각을 딕셔너리로 유지, `cookieHeader`는 "; " 조인. Android의 `CookieManager.getCookie(EndPoint.LOGIN_LMS)` 대응.
  - `enum HtmlUtil` — KNU-iOS `Helper/HtmlUtil.swift`를 그대로 포트하고 3개 추가: `elementById(_ id: String, in html: String) -> String?`(id 속성 요소 블록), `attribute(_ name: String, in tag: String) -> String?`, `links(in html: String) -> [(href: String, text: String)]` (YU 파서들이 사용)
  - `enum MultipartRequest { static func upload(_ urlString:, headers:, fileField: String, fileName: String, mimeType: String, fileData: Data, formParams: [String:String], completion: @escaping (Result<String,Error>)->Void) }` — boundary 수동 조립(Android `volley/util/MultipartRequest.java` 미러)
  - `final class PreferenceManager { static let shared; var user: User?; func storeUser(_:); func removeUser(); var userPublisher: AnyPublisher<User?,Never> }` — UserDefaults key `"user"`, `CurrentValueSubject` 기반
  - `enum DateUtil { static func timestamp(from: String) -> Date?; static func relative(_ date: Date) -> String; static func format(_ date: Date, pattern: String) -> String }`
  - `enum BitmapUtil { static func resized(_ image: UIImage, maxSize: CGFloat) -> UIImage }` — EXIF 회전 보정 포함(Android `BitmapUtil` 미러)
  - `Toast` — KNU-iOS `Helper/UIViewToast.swift`를 SwiftUI로: `View.toast(message: Binding<String?>)` modifier(2초 자동 소멸 캡슐)
  - `struct RemoteImage: View { init(urlString: String?, placeholder: Image = ...) }` — **쿠키 헤더 부착** URLSession 로딩 + `NSCache` (KNU-iOS `Helper/ImageLoader.swift`의 캐시 로직을 SwiftUI 뷰로 재구성; LMS 보호 이미지 필수)

- [ ] **Step 1: KNU-iOS 원본 읽기** — `../KnuMiniGroup-iOS/knu_minigroup/Helper/{Resource,HtmlUtil,HttpClient,ImageLoader,PreferenceManager,DateUtil,UIViewToast}.swift` 정독.
- [ ] **Step 2: 파일 작성** — 위 인터페이스대로. HttpClient는 KNU판(67줄)에 쿠키 수동화·Set-Cookie 수집·redirect 차단·portal TLS 예외를 추가한 확장판.
- [ ] **Step 3: Android 대조** — `MultipartRequest.java`·`BitmapUtil.java`·`PreferenceManager.java`와 필드·동작 대조(저장 항목: userId, password, name, department, number, grade, email, uid, phoneNumber).
- [ ] **Step 4: pbxproj 등록**(Helper 그룹) → grep 4곳 검증.
- [ ] **Step 5: 스테이징** — 11파일+pbxproj.

---

### Task 4: App 층 — EndPoint + 앱 진입

**Files:**
- Create: `YuMinigroup/App/EndPoint.swift`, `YuMinigroup/App/FirebaseRef.swift`
- Modify: `YuMinigroup/App/YuMinigroupApp.swift`, `project.pbxproj`

**Interfaces:**
- Produces:
  - `enum EndPoint` — Android `app/EndPoint.java` 1차분 전체 미러(아래 코드). `{UID}`/`{FILE}` 치환 헬퍼 `static func userImage(uid: String) -> String`, `static func groupImage(file: String) -> String`
  - `enum FirebaseRef { static var isConfigured: Bool; static func database() -> DatabaseReference? }` — plist 부재 시 nil (사용처는 nil이면 Firebase 병합 생략)
  - `YuMinigroupApp`: `init`에서 `GoogleService-Info.plist` 존재 시에만 `FirebaseApp.configure()`; `ContentView`가 `PreferenceManager.userPublisher` 구독해 user==nil → `LoginView`, user!=nil → `SplashView` 라우팅 (Task 8에서 실뷰 연결, 본 태스크는 `Text` 자리)

- [ ] **Step 1: EndPoint.swift 작성**

```swift
enum EndPoint {
    static let yuPortalLoginURL = "https://portal.yu.ac.kr/sso/login_process.jsp"
    static let baseURL = "http://lms.yu.ac.kr"
    static let loginLMS = baseURL + "/ilos/lo/login_sso.acl"
    static let groupList = baseURL + "/ilos/m/community/share_group_list.acl"
    static let withdrawalGroup = baseURL + "/ilos/community/share_auth_drop_me.acl"
    static let deleteGroup = baseURL + "/ilos/community/share_group_delete.acl"
    static let groupArticleList = baseURL + "/ilos/community/share_list.acl"
    static let writeArticle = baseURL + "/ilos/community/share_insert.acl"
    static let imageUpload = baseURL + "/ilos/tinymce/file_upload_pop.acl"
    static let deleteArticle = baseURL + "/ilos/community/share_delete.acl"
    static let modifyArticle = baseURL + "/ilos/community/share_update.acl"
    static let insertReply = baseURL + "/ilos/community/share_comment_insert.acl"
    static let deleteReply = baseURL + "/ilos/community/share_comment_delete.acl"
    static let modifyReply = baseURL + "/ilos/community/share_comment_update.acl"
    static let memberList = baseURL + "/ilos/community/share_member_list.acl"
    static let getUserImage = baseURL + "/ilos/mp/myinfo_update_photo.acl"
    static let myInfo = baseURL + "/ilos/mp/myinfo_form.acl"
    static let syncProfile = baseURL + "/ilos/mp/myinfo_sync.acl"
    static let profileImagePreview = baseURL + "/ilos/mp/myinfo_file_update.acl"
    static let profileImageUpdate = baseURL + "/ilos/mp/myinfo_insert.acl"
    static let schedule = "https://homep.yu.ac.kr/_app/calendarxml_u.php"

    static func userImage(uid: String) -> String {
        baseURL + "/ilos/mp/user_image_view.acl?id=\(uid)&ext=.jpg"
    }
    static func groupImage(file: String) -> String {
        baseURL + "/ilosfiles/club/photo/\(file)"
    }
}
```
(2·3차 예정 URL — CREATE_GROUP/REGISTER/MODIFY/UPDATE_GROUP/GROUP_MEMBER_LIST/GROUP_IMAGE_UPDATE/SEND_MESSAGE/TIMETABLE/영대소식/도서관/버스/유튜브 — 는 1차에서 넣지 않는다. YAGNI.)

- [ ] **Step 2: FirebaseRef.swift + 앱 진입 작성** — `canImport(FirebaseCore)` 가드 없이 SPM 상시 링크 전제(Task 6), configure만 plist 조건부.
- [ ] **Step 3: pbxproj 등록** → 검증.
- [ ] **Step 4: 스테이징.**

---

### Task 5: Dto 5종

**Files:**
- Create: `YuMinigroup/Dto/User.swift`, `GroupItem.swift`, `ArticleItem.swift`, `ReplyItem.swift`, `MemberItem.swift`
- Modify: `project.pbxproj`

**Interfaces:**
- Produces (Android `dto/*.java` 필드 미러, 전부 `Codable`·`Identifiable`·`Hashable`):

```swift
struct User: Codable, Hashable {
    var userId, password, name, department, number, grade, email, uid: String
    var phoneNumber: String
}
struct GroupItem: Codable, Identifiable, Hashable {
    var id: String            // LMS grp_id
    var key: String?          // Firebase key
    var name, image: String
    var info, description_, joinType: String?
    var isAdmin: Bool
    // Codable 키: description_ ↔ "description"
}
struct ArticleItem: Codable, Identifiable, Hashable {
    var id: String            // artl_num
    var key: String?          // Firebase key
    var uid, name, title, content: String
    var images: [String]
    var youtubeId: String?    // 1차: 썸네일 표시+외부 열기 전용
    var replyCount: Int
    var timestamp: Date?
    var isAuth: Bool          // 본인 글 여부(수정/삭제 메뉴)
}
struct ReplyItem: Codable, Identifiable, Hashable {
    var id: String            // cmt_num
    var key: String?
    var uid, name, reply: String
    var timestamp: Date?
    var isAuth: Bool
}
struct MemberItem: Codable, Identifiable, Hashable {
    var id: String { uid }
    var uid, name, value: String   // value = 프로필 이미지 식별자(Android 미러)
}
```

- [ ] **Step 1: Android dto와 필드 대조 후 작성** — `dto/{User,GroupItem,ArticleItem,ReplyItem,MemberItem}.java` 열어 위 정의와 차이나는 필드(예: GroupItem.memberCount 등) 발견 시 **Android 쪽을 기준으로 보강**.
- [ ] **Step 2: pbxproj 등록**(Dto 그룹) → 검증. **Step 3: 스테이징.**

---

### Task 6: Firebase SPM 등록

**Files:**
- Modify: `project.pbxproj` (XCRemoteSwiftPackageReference + XCSwiftPackageProductDependency: FirebaseDatabase, FirebaseAuth)

**Interfaces:**
- Produces: 앱 타깃에서 `import FirebaseCore/FirebaseDatabase/FirebaseAuth` 가능. 이후 태스크의 Firebase 코드 전제.

- [ ] **Step 1: KNU-iOS pbxproj의 firebase-ios-sdk 등록 블록 확인** — `grep -n -A5 "XCRemoteSwiftPackageReference\|XCSwiftPackageProductDependency" ../KnuMiniGroup-iOS/knu_minigroup.xcodeproj/project.pbxproj` 로 구조·버전(`upToNextMajorVersion`) 파악.
- [ ] **Step 2: 동일 구조로 이식** — packageReferences(프로젝트), packageProductDependencies(타깃), PBXBuildFile(Frameworks phase) 등록. 제품: FirebaseDatabase·FirebaseAuth(FirebaseCore는 전이 의존).
- [ ] **Step 3: 검증** — `grep -c "Firebase" project.pbxproj` ≥ 6, 섹션 4종 모두 존재. Package.resolved는 Xcode가 생성하므로 만들지 않음.
- [ ] **Step 4: 스테이징.**

---

### Task 7: UserRemoteDataSource + UserRepository (SSO 로그인)

**Files:**
- Create: `YuMinigroup/Data/Remote/UserRemoteDataSource.swift`, `YuMinigroup/Data/UserRepository.swift`
- Modify: `project.pbxproj`

**Interfaces:**
- Consumes: `HttpClient.requestWithHeaders`, `CookieStore`, `HtmlUtil`, `Resource`, `EndPoint`, `PreferenceManager`, `MultipartRequest`, FirebaseAuth
- Produces:
  - `UserRemoteDataSource.login(id: String, password: String, completion: @escaping (Resource<User>) -> Void)`
  - `.fetchMyInfo(completion: (Resource<User>)->Void)` / `.syncProfile(...)` / `.updateProfileImage(imageData: Data, completion: (Resource<String>)->Void)`
  - `UserRepository` — 위를 그대로 위임(순수 패스스루, Android 미러)

- [ ] **Step 1: Android 원본 정독** — `viewmodel/LoginViewModel.java`(SSO 3단계+파싱), `viewmodel/SplashViewModel.java`, `data/remote/UserRemoteDataSource.java`, `viewmodel/ProfileViewModel.java`(사진 변경 플로우).
- [ ] **Step 2: login 시퀀스 구현** — 정확 미러:

```
1) POST EndPoint.loginLMS (파라미터 없음)
   → setCookies 중 "SESSION_IMAX" 포함 조각 추출 → CookieStore.store
2) POST EndPoint.yuPortalLoginURL
   headers: ["Referer": "http://portal.yu.ac.kr/sso/login.jsp",
             "Cookie": CookieStore.shared.cookieHeader ?? ""]
   formParams: ["cReturn_Url": EndPoint.loginLMS, "type": "lms",
                "p": "20112030550005B055003090F570256534A010F47070C4556045E18020750110",
                "login_gb": "0", "userId": id, "password": password]
   → setCookies 중 "ssotoken" 포함 조각 추출 → CookieStore.store (없으면 .error("아이디 또는 비밀번호가 잘못되었습니다."))
3) POST EndPoint.loginLMS (headers: Cookie 부착) → 세션 확립
4) GET EndPoint.myInfo → HtmlUtil로 이름/학과/학번/학년/이메일/전화 스크랩
5) GET EndPoint.getUserImage → 사진 URL의 "id=" 값 → user.uid
6) User 조립 → completion(.success(user))  ※ 호출측(VM)이 PreferenceManager.storeUser
```
테스트 계정 분기: `id == "22000000" && password == "TestUser"`이면 위 대신 `Auth.auth().signIn(withEmail: "TestUser@yu.ac.kr", password:)`(FirebaseRef.isConfigured 아닐 땐 .error). **CREATE_LOG 블록은 이식 금지.**
- [ ] **Step 3: 파싱 셀렉터 대조** — Android가 쓰는 myinfo_form 요소 id·인덱스를 그대로 옮기고, 각 추출 실패 시 `Resource.error("프로필 파싱 실패")`로 강등(크래시 금지).
- [ ] **Step 4: pbxproj 등록**(Data/Remote 그룹 신설) → 검증. **Step 5: 스테이징.**

---

### Task 8: LoginView·SplashView + 루트 게이트

**Files:**
- Create: `YuMinigroup/ViewModel/LoginViewModel.swift`, `SplashViewModel.swift`, `YuMinigroup/View/LoginView.swift`, `SplashView.swift`, `ContentView.swift`
- Modify: `YuMinigroup/App/YuMinigroupApp.swift`(루트를 ContentView로), `project.pbxproj`

**Interfaces:**
- Consumes: `UserRepository.login`, `PreferenceManager`
- Produces:
  - `LoginViewModel: ObservableObject` — `@Published var state: State`; `struct State { var id = ""; var password = ""; var isLoading = false; var message: String?; var loggedInUser: User? }`; `func login()` (유효성: 학번 숫자·비밀번호 비어있지 않음 → 실패 시 message)
  - `SplashViewModel` — `func autoLogin()`: 저장 자격증명으로 `UserRepository.login` 재실행, `@Published var result: Result?` (`.success` → MainView 전환, `.failure` → removeUser 후 LoginView)
  - `ContentView` — `@State phase: .login/.splash/.main`; 초기값 = `PreferenceManager.shared.user == nil ? .login : .splash`; LoginView 성공·Splash 성공 시 `.main`(MainView는 Task 9까지 `Text("Main")` 자리)

- [ ] **Step 1: VM 작성** — Android `LoginViewModel.java`의 유효성 문구·흐름 미러(에러 문구 한국어 그대로), 성공 시 `PreferenceManager.storeUser` 후 state 반영.
- [ ] **Step 2: 뷰 작성** — LoginView: 로고+학번 `TextField`(.keyboardType(.numberPad))+비밀번호 `SecureField`+로그인 버튼+`toast(message:)`+로딩 오버레이. SplashView: `LaunchScreenBackgroundColor` 배경+로고, `onAppear`에서 1.25초 타이머와 autoLogin 병행(둘 다 완료 시 전환 — Android 1250ms 미러).
- [ ] **Step 3: pbxproj 등록**(ViewModel/View 그룹 신설) → 검증. **Step 4: 스테이징.**

---

### Task 9: MainView 드로어 셸

**Files:**
- Create: `YuMinigroup/ViewModel/MainViewModel.swift`, `YuMinigroup/View/MainView.swift`, `YuMinigroup/View/PlaceholderView.swift`
- Modify: `YuMinigroup/View/ContentView.swift`(.main → MainView), `project.pbxproj`

**Interfaces:**
- Consumes: `DrawerScaffold`, `AppToolbar`, `PreferenceManager.userPublisher`, `RemoteImage`
- Produces:
  - `enum MainRoute: CaseIterable { case groupMain, univNotice, timetable, librarySeat, shuttleBus }` + 로그아웃 액션(라우트 아님)
  - `MainViewModel` — `@Published var route: MainRoute = .groupMain`, `@Published var user: User?`, `func logout()`(PreferenceManager.removeUser + CookieStore.clear)
  - `MainView` — DrawerScaffold 셸. 드로어 헤더: `RemoteImage(EndPoint.userImage(uid:))`+이름+이메일(탭 → ProfileView 풀스크린, Task 19까지 자리), 메뉴 6행(메인화면/영대소식/시간표/도서관 좌석/순환버스/로그아웃 — Android `menu/activity_main_drawer` 순서 미러). groupMain 외 라우트는 `PlaceholderView(title:)`("준비중" 표시)
  - `PlaceholderView(title: String)` — AppToolbar+중앙 "준비중입니다" 텍스트

- [ ] **Step 1: DrawerScaffold 사용법 확인** — `../ParallaxTabLayout/iOS/.../UI/DrawerScaffold.swift`와 그 사용례(`ParallaxNavHost.swift`) 정독 후 동일 패턴으로 조립.
- [ ] **Step 2: 작성 + pbxproj 등록 + 검증.** **Step 3: 스테이징.**

---

### Task 10: 그룹 목록 — 데이터층 + GroupMainView

**Files:**
- Create: `YuMinigroup/Data/Remote/GroupRemoteDataSource.swift`, `YuMinigroup/Data/GroupRepository.swift`, `YuMinigroup/ViewModel/GroupMainViewModel.swift`, `YuMinigroup/View/GroupMainView.swift`
- Modify: `YuMinigroup/View/MainView.swift`(groupMain 라우트 연결), `project.pbxproj`

**Interfaces:**
- Consumes: `HttpClient`, `HtmlUtil`, `EndPoint.groupList`, `FirebaseRef`(그룹 key 매핑: RTDB `Groups`/`UserGroupList`), `Resource`, `GroupItem`
- Produces:
  - `GroupRemoteDataSource.fetchJoinedGroups(offset: Int, completion: (Resource<[GroupItem]>)->Void)` — Android `GroupRemoteDataSource.java`의 목록 파싱 미러(`share_group_list.acl` POST, `panel_type: "myclub_list"` 등 폼 파라미터는 Android 원본에서 확인해 그대로), Firebase `UserGroupList/{uid}`에서 grp_id→key 매핑 병합(FirebaseRef nil이면 생략)
  - `GroupRemoteDataSource.leaveGroup(groupId:completion:)` / `.deleteGroup(groupId:key:completion:)` (Task 15에서 사용; `withdrawalGroup`/`deleteGroup` + Firebase `Groups`·`UserGroupList` 정리)
  - `GroupRepository` — 패스스루
  - `GroupMainViewModel` — `State { var groups: [GroupItem]; var isLoading; var message: String? }`, `func fetchGroups()`(offset 페이징: Android 미러로 시작 1, 더보기 스크롤)
  - `GroupMainView` — AppToolbar(제목 "메인화면", 메뉴 아이콘=드로어 열기) + refreshable 2열 `LazyVGrid`(셀: 그룹 이미지 `RemoteImage(EndPoint.groupImage(file:))`+이름) + 빈 상태 배너 + 하단 버튼 3개(그룹찾기/가입신청중/그룹만들기 → `PlaceholderView`). 셀 탭 → `GroupView(groupItem:)` push

- [ ] **Step 1: Android 파싱 원본 정독** — `data/remote/GroupRemoteDataSource.java`에서 그룹 목록 요청 파라미터·HTML 구조(li/td 인덱스) 확보 후 HtmlUtil로 동일 추출.
- [ ] **Step 2: 작성 + pbxproj 등록 + 검증** — 파싱 실패는 `.error` 강등 확인. **Step 3: 스테이징.**

---

### Task 11: GroupView — CollapsingHeader 탭호스트 (핵심 화면)

**Files:**
- Create: `YuMinigroup/ViewModel/GroupViewModel.swift`, `YuMinigroup/View/GroupView.swift`
- Modify: `project.pbxproj`

**Interfaces:**
- Consumes: `CollapsingListScaffold`(Task 2 일반화판), `RemoteImage`, `FloatingActionButton`, `Compat`
- Produces:
  - `GroupViewModel` — `init(groupItem: GroupItem)`; `@Published var selectedTab = 0`, `@Published var collapseOffset: CGFloat = 0`, 탭별 스크롤 오프셋 4개, `let tabTitles = ["소식","일정","맴버","설정"]`; `var hasCoverPhoto: Bool { !groupItem.image.contains("share_nophoto") }`
  - `GroupView(groupItem:)` — 구조는 ParallaxTabLayout `ParallaxTabScreen.swift` 미러 + 조정:
    - `imageHeight: 200` (Android CollapsingToolbar 200dp 미러)
    - `headerBackground`: hasCoverPhoto → `RemoteImage(커버)` + 하단 그라디언트 스크림(`LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)` — Android `bg_gradient` 상당) / 아니면 기본 헤더 배경색 + 중앙 YU 로고 이미지
    - 탭 4개를 예제의 ZStack+opacity+allowsHitTesting 방식으로 유지(각 탭 뷰는 Task 12~15에서 실구현, 본 태스크는 4개 모두 `Text` 자리 + `CollapsingHeaderSpacer` 포함 스켈레톤)
    - FAB: `selectedTab == 0`일 때만, 탭 → CreateArticleView(Task 17까지 자리)
    - 탭 전환 시 비최상단 강제 collapse(`collapseOffset = .greatestFiniteMagnitude` 패턴), 접힘 시 `navigationBarBackgroundColorCompat`/`TintColorCompat` 전환 — 예제 로직 그대로
    - 상단 타이틀 = 그룹명(핀 툴바, `titleEnabled=false` 미러)

- [ ] **Step 1: 예제 재정독** — `ParallaxTabScreen.swift` + `CollapsingHeader.swift`(일반화판) 대조하며 작성.
- [ ] **Step 2: 작성 + pbxproj 등록 + 검증** — collapse 상호작용 코드가 예제와 논리 동일한지 diff 수준으로 확인. **Step 3: 스테이징.**

---

### Task 12: 소식 탭 — Article 데이터층 + Tab1

**Files:**
- Create: `YuMinigroup/Data/Remote/ArticleRemoteDataSource.swift`, `YuMinigroup/Data/ArticleRepository.swift`, `YuMinigroup/ViewModel/Tab1ViewModel.swift`, `YuMinigroup/View/Tab1View.swift`, `YuMinigroup/View/Cell/ArticleListCell.swift`
- Modify: `YuMinigroup/View/GroupView.swift`(탭0 연결), `project.pbxproj`

**Interfaces:**
- Consumes: `HttpClient`, `HtmlUtil`, `FirebaseRef`(RTDB `Articles/{groupKey}`), `RefreshableLazyColumn`, `CollapsingHeaderSpacer`
- Produces:
  - `ArticleRemoteDataSource(groupId: String, groupKey: String?)`:
    - `.fetchArticles(offset: Int, completion: (Resource<[ArticleItem]>)->Void)` — `share_list.acl` POST(`CLUB_GRP_ID`, `startL`, `displayL`=10 — Android 원본 파라미터 그대로) 파싱 후 Firebase `Articles/{groupKey}` 병합(images/youtubeId/timestamp/uid 보강; key 매칭은 artl_num)
    - `.deleteArticle(articleId:articleKey:completion:)` — LMS delete + `Articles/{groupKey}/{key}`·`Replys/{key}` 제거
    - `var stopRequestMore: Bool` (마지막 페이지 감지 — Android 미러)
  - `ArticleRepository(groupId:groupKey:)` — 패스스루
  - `Tab1ViewModel` — `State { var articles: [ArticleItem]; var isLoading; var isRefreshing; var endReached; var message }`, `func refresh()`, `func loadMore()`, `func remove(article:)`; 게시글 작성/수정 결과 반영용 `func upsert(_ article: ArticleItem)`
  - `Tab1View(viewModel:headerHeight:appBarState:isActive:scrollOffset:)` — `RefreshableLazyColumn` 사용(펼침일 때만 refresh 활성), 마지막 셀 `onAppear`에서 loadMore, 빈 상태 "글쓰기" 블록, `ArticleListCell` 탭 → ArticleView push(Task 16까지 자리)
  - `ArticleListCell(article:)` — `RemoteImage` 아바타+이름+상대시간+본문 4줄+첫 이미지+댓글 수

- [ ] **Step 1: Android 정독** — `data/remote/ArticleRemoteDataSource.java`(파싱·Firebase 병합·페이징 상태), `fragment/Tab1Fragment.java`(빈 상태·무한 스크롤 조건).
- [ ] **Step 2: 작성 + GroupView 탭0 실연결 + pbxproj 등록 + 검증.** **Step 3: 스테이징.**

---

### Task 13: 일정 탭 — Tab2 (학사일정 캘린더)

**Files:**
- Create: `YuMinigroup/Helper/CalendarXmlParser.swift`, `YuMinigroup/ViewModel/Tab2ViewModel.swift`, `YuMinigroup/View/Tab2View.swift`
- Modify: `YuMinigroup/View/GroupView.swift`(탭1 연결), `project.pbxproj`

**Interfaces:**
- Consumes: `HttpClient`, `EndPoint.schedule`, `CollapsingHeaderSpacer`
- Produces:
  - `struct ScheduleItem: Identifiable { let id = UUID(); let startDate: Date; let endDate: Date?; let title: String }`
  - `CalendarXmlParser: NSObject, XMLParserDelegate` — `static func parse(_ data: Data) -> [ScheduleItem]` (Android `Tab2Fragment`의 DocumentBuilder 파싱과 동일 노드 매핑)
  - `Tab2ViewModel` — `@Published var displayedMonth: Date`, `@Published var schedules: [ScheduleItem]`(해당 월 필터), `func fetch()`, `func moveMonth(by: Int)`
  - `Tab2View` — 상단 월 캘린더 그리드(7열 `LazyVGrid`, 이전/다음 달 화살표, 일정 있는 날 밑점 표시 — 자체 구현) + 아래 해당 월 일정 리스트(날짜 범위+제목). 스크롤 컨테이너는 다른 탭과 동일하게 `CollapsingHeaderSpacer` 포함 ScrollView

- [ ] **Step 1: Android XML 노드 확인** — `fragment/Tab2Fragment.java`의 파싱 대상 태그명 확보.
- [ ] **Step 2: 작성 + 연결 + pbxproj 등록 + 검증.** **Step 3: 스테이징.**

---

### Task 14: 맴버 탭 — Tab3 + UserDialog

**Files:**
- Create: `YuMinigroup/ViewModel/Tab3ViewModel.swift`, `YuMinigroup/View/Tab3View.swift`, `YuMinigroup/ViewModel/UserViewModel.swift`, `YuMinigroup/View/UserDialogView.swift`
- Modify: `YuMinigroup/View/GroupView.swift`(탭2 연결), `YuMinigroup/Data/Remote/GroupRemoteDataSource.swift`(멤버 목록 추가), `YuMinigroup/Data/GroupRepository.swift`, `project.pbxproj`

**Interfaces:**
- Consumes: `EndPoint.memberList`, `HtmlUtil`, `RemoteImage`
- Produces:
  - `GroupRemoteDataSource.fetchMembers(groupId: String, offset: Int, completion: (Resource<[MemberItem]>)->Void)` — Android `share_member_list.acl` 파싱 미러
  - `Tab3ViewModel` — `State { members, isLoading, isRefreshing, endReached, message }`, `refresh()/loadMore()`
  - `Tab3View(...)` — 4열 그리드(`RemoteImage(EndPoint.userImage(uid:))`+이름), 무한 스크롤, refresh 게이트. 탭 → `.sheet(UserDialogView)`
  - `UserViewModel(member: MemberItem)`, `UserDialogView` — 아바타·이름·학번·학과 + "메시지 보내기" 버튼(비활성, "준비중" 라벨 — 2차 채팅 연결점)

- [ ] **Step 1: Android 정독** — `fragment/Tab3Fragment.java`+`UserDialogFragment.java`+member 파싱.
- [ ] **Step 2: 작성 + 연결 + pbxproj 등록 + 검증.** **Step 3: 스테이징.**

---

### Task 15: 설정 탭 — Tab4

**Files:**
- Create: `YuMinigroup/ViewModel/Tab4ViewModel.swift`, `YuMinigroup/View/Tab4View.swift`
- Modify: `YuMinigroup/View/GroupView.swift`(탭3 연결), `project.pbxproj`

**Interfaces:**
- Consumes: `GroupRepository.leaveGroup/deleteGroup`(Task 10), `PreferenceManager`
- Produces:
  - `Tab4ViewModel(groupItem:)` — `func leaveOrClose(completion:)`: isAdmin → deleteGroup(폐쇄), 아니면 leaveGroup(탈퇴); `@Published var message`, `@Published var didExit`(그룹 화면 pop 신호)
  - `Tab4View` — 카드 3섹션(Android `content_tab4.xml` 미러): ①사용자 설정: "프로필" 행 → ProfileView(Task 19까지 자리) ②소모임 설정: "소모임 {탈퇴/폐쇄}" 행 → `.alert` 확인 다이얼로그 → leaveOrClose → 성공 시 GroupView pop ③어플리케이션 정보: 공지사항(자리)·건의사항(`mailto:` `UIApplication.shared.open`)·버젼 정보(`CFBundleShortVersionString` 표시). AdMob 없음

- [ ] **Step 1: Android 정독** — `fragment/Tab4Fragment.java`+`content_tab4.xml` 항목·문구 미러.
- [ ] **Step 2: 작성 + 연결 + pbxproj 등록 + 검증.** **Step 3: 스테이징.**

---

### Task 16: 게시글 상세 — Reply 데이터층 + ArticleView

**Files:**
- Create: `YuMinigroup/Data/Remote/ReplyRemoteDataSource.swift`, `YuMinigroup/Data/ReplyRepository.swift`, `YuMinigroup/ViewModel/ArticleViewModel.swift`, `YuMinigroup/View/ArticleView.swift`, `YuMinigroup/View/Cell/ReplyListCell.swift`
- Modify: `YuMinigroup/View/Tab1View.swift`(셀 탭 push 연결), `YuMinigroup/Data/Remote/ArticleRemoteDataSource.swift`(단건 조회 추가), `project.pbxproj`

**Interfaces:**
- Consumes: `EndPoint.insertReply/deleteReply/modifyReply`, `FirebaseRef`(`Replys/{articleKey}`), `RemoteImage`
- Produces:
  - `ArticleRemoteDataSource.fetchArticle(articleId:completion: (Resource<ArticleItem>)->Void)` — Android 상세 파싱 미러
  - `ReplyRemoteDataSource(groupId:articleId:articleKey:)` — `.fetchReplys(completion: (Resource<[ReplyItem]>)->Void)`, `.addReply(text:completion:)`, `.setReply(replyId:text:completion:)`, `.removeReply(replyId:replyKey:completion:)`; 쓰기 성공 시 Firebase `Replys/{articleKey}` 이중기록·삭제
  - `ReplyRepository` — 패스스루
  - `ArticleViewModel(article: ArticleItem, groupInfo...)` — `State { article, replys, inputText, isLoading, message, didDelete }`; `fetchAll()/sendReply()/deleteArticle()/deleteReply(_:)`
  - `ArticleView` — ScrollView: 게시글 헤더(아바타·이름·시간·본문·이미지들 탭 → PictureView(Task 18까지 자리)·유튜브 썸네일 탭 → `UIApplication.shared.open(youtube URL)`) + 댓글 리스트 + 하단 입력바(TextField+전송). 본인 글이면 우상단 메뉴(수정 → CreateArticleView 수정모드/삭제 → 확인 후 pop+Tab1 반영). `ReplyListCell` 롱프레스 → 복사/수정(UpdateReplyView, Task 18)/삭제(본인만)

- [ ] **Step 1: Android 정독** — `activity/ArticleActivity.java`, `viewmodel/ArticleViewModel.java`, `data/remote/ReplyRemoteDataSource.java`.
- [ ] **Step 2: 작성 + 연결 + pbxproj 등록 + 검증** — 삭제·댓글 변경이 Tab1의 `upsert/remove`로 반영되는 경로(콜백 클로저 전달) 확인. **Step 3: 스테이징.**

---

### Task 17: 게시글 작성/수정 — CreateArticleView

**Files:**
- Create: `YuMinigroup/ViewModel/CreateArticleViewModel.swift`, `YuMinigroup/View/CreateArticleView.swift`, `YuMinigroup/Helper/PhotoPicker.swift`
- Modify: `YuMinigroup/View/GroupView.swift`(FAB 연결), `YuMinigroup/View/ArticleView.swift`(수정 진입 연결), `YuMinigroup/Data/Remote/ArticleRemoteDataSource.swift`(add/set 추가), `project.pbxproj`

**Interfaces:**
- Consumes: `MultipartRequest`, `BitmapUtil`, `EndPoint.imageUpload/writeArticle/modifyArticle`, `FirebaseRef`
- Produces:
  - `PhotoPicker: UIViewControllerRepresentable` — `PHPickerViewController`(iOS 15 OK), `selectionLimit` 다중, 결과 `[UIImage]`
  - `CameraPicker: UIViewControllerRepresentable` — `UIImagePickerController(sourceType: .camera)`, 결과 `UIImage` (Android 카메라 첨부 미러). **Info.plist에 `NSCameraUsageDescription`("게시글 사진 촬영에 사용됩니다") 추가** — `GENERATE_INFOPLIST_FILE=YES`이므로 build settings `INFOPLIST_KEY_NSCameraUsageDescription`로 pbxproj에 넣는다
  - `ArticleRemoteDataSource.addArticle(title:content:imageUrls:completion:)` / `.setArticle(articleId:key:...)` — Android 미러: 이미지 각각 `imageUpload` 멀티파트 → 반환 URL 수집 → `writeArticle` POST → 목록 재조회로 신규 artl_num 획득 → Firebase `Articles/{groupKey}` 기록
  - `enum CreateArticleMode { case create(group: GroupItem); case edit(group: GroupItem, article: ArticleItem) }`
  - `CreateArticleViewModel(mode: CreateArticleMode)` — `State { title, content, images: [UIImage], existingImageUrls: [String], isLoading, message, resultArticle: ArticleItem? }`; `func send()`(업로드 실패 시 중단+메시지 — 부분 업로드 방지)
  - `CreateArticleView` — 제목 필드+본문 `TextEditor`+첨부 썸네일 가로 스트립(삭제 가능)+하단 사진 버튼(`.confirmationDialog`로 카메라/앨범 선택 → CameraPicker 또는 PhotoPicker sheet; `BitmapUtil.resized(max: 1280)` 적용)+내비바 "등록/수정". 성공 시 dismiss + `resultArticle`을 Tab1 `upsert`로 전달, 작성 모드면 `appBarState.setExpanded(true)`(Android `appbarLayoutExpand` 미러)

- [ ] **Step 1: Android 정독** — `activity/CreateArticleActivity.java`, `viewmodel/CreateArticleViewModel.java`, `ArticleRemoteDataSource.addArticle` 흐름(재조회로 id 획득 포함).
- [ ] **Step 2: 작성 + 연결 + pbxproj 등록 + 검증.** **Step 3: 스테이징.**

---

### Task 18: UpdateReplyView + PictureView

**Files:**
- Create: `YuMinigroup/ViewModel/UpdateReplyViewModel.swift`, `YuMinigroup/View/UpdateReplyView.swift`, `YuMinigroup/ViewModel/PictureViewModel.swift`, `YuMinigroup/View/PictureView.swift`
- Modify: `YuMinigroup/View/ArticleView.swift`(연결), `project.pbxproj`

**Interfaces:**
- Consumes: `ReplyRepository.setReply`, `RemoteImage`
- Produces:
  - `UpdateReplyViewModel(reply: ReplyItem, onUpdated: (ReplyItem)->Void)` — `State { text, isLoading, message, done }`, `func update()`
  - `UpdateReplyView` — `TextEditor`+내비바 전송, 성공 시 dismiss+콜백
  - `PictureViewModel(images: [String], initialIndex: Int)`; `PictureView` — `TabView(.page)` 페이저 + 핀치 줌(각 페이지 `MagnificationGesture`+`DragGesture` 스케일/팬, 더블탭 리셋 — Android `ZoomImageView` 상당), 검정 배경 풀스크린, 닫기 버튼

- [ ] **Step 1: 작성 + 연결 + pbxproj 등록 + 검증.** **Step 2: 스테이징.**

---

### Task 19: ProfileView

**Files:**
- Create: `YuMinigroup/ViewModel/ProfileViewModel.swift`, `YuMinigroup/View/ProfileView.swift`
- Modify: `YuMinigroup/View/MainView.swift`(드로어 헤더 연결), `YuMinigroup/View/Tab4View.swift`("프로필" 행 연결), `project.pbxproj`

**Interfaces:**
- Consumes: `UserRepository.fetchMyInfo/syncProfile/updateProfileImage`, `PhotoPicker`, `BitmapUtil`, `PreferenceManager`
- Produces:
  - `ProfileViewModel` — `State { user: User?, pickedImage: UIImage?, isLoading, message }`; `func load()`, `func sync()`(myinfo_sync 후 재로드), `func applyPhoto()`(preview→update 2단계, Android 미러; 성공 시 PreferenceManager user 갱신 → `userPublisher`로 전 화면 아바타 자동 반영)
  - `ProfileView` — 아바타(탭 → PhotoPicker)+이름/학과/학번/학년/이메일/전화 목록+["LMS 동기화"] 버튼+변경 사진 있을 때 "적용" 버튼

- [ ] **Step 1: Android 정독** — `activity/ProfileActivity.java`+`viewmodel/ProfileViewModel.java`(preview/update 엔드포인트 순서).
- [ ] **Step 2: 작성 + 연결 + pbxproj 등록 + 검증.** **Step 3: 스테이징.**

---

### Task 20: 최종 정합성 + 인수 체크리스트

**Files:**
- Modify: `README.md`(프로젝트 소개·요구사항·빌드 방법·plist 안내), `project.pbxproj`(잔여 오류 시)
- Create: `docs/superpowers/plans/2026-08-26-mac-build-checklist.md`

**Interfaces:**
- Produces: 사용자 Mac 빌드용 인수 문서.

- [ ] **Step 1: 전수 정합 검사**
  - `find YuMinigroup -name "*.swift"` 목록 == pbxproj PBXFileReference 목록 (diff 0)
  - 전 파일 `grep -rn "try!\|fatalError\|NavigationStack\|navigationDestination\|PhotosPicker" YuMinigroup/` → CollapsingHeader 예제 유래 코드 외 0건
  - `grep -rn "TODO\|FIXME" YuMinigroup/` → 0건
  - 타입 상호 참조 grep(각 태스크 Produces 시그니처가 사용처와 일치)
- [ ] **Step 2: README 갱신** — 앱 소개, iOS 15.6/Xcode 요구, `GoogleService-Info.plist` 배치 방법(yuminigroup 프로젝트 iOS 앱 등록 절차), Firebase 없이도 기동됨 명시.
- [ ] **Step 3: Mac 빌드 체크리스트 작성** — 스펙 §9 체크리스트를 실행 절차로: ①Xcode에서 SPM resolve ②빌드 ③실계정 로그인→그룹 그리드 ④그룹 진입 CollapsingHeader 동작 4항목(접힘/펼침/탭 전환 collapse/FAB) ⑤소식 페이징·상세·댓글 CRUD ⑥이미지 첨부 작성 ⑦스플래시 자동 로그인 ⑧plist 제거 후 기동(LMS 단독) ⑨테스트 계정 Firebase Auth 폴백.
- [ ] **Step 4: 스테이징** — 전체 신규·수정 경로 최종 `git status` 확인(전부 스테이징·미커밋 상태), 커밋 메시지 제안문 작성해 사용자에게 전달.
