# YuMinigroup-iOS 마이그레이션 설계 (1차: 코어 플로우)

날짜: 2026-08-26
상태: 승인됨 (구현 계획 수립 전)

## 1. 배경과 목표

기존 YuMinigroup-iOS(구 Application, 2021~2024)는 개인 PHP 백엔드(`hong227.dothome.co.kr/hong227/v1`) 기반의 범용 SNS("OurStory")로, YuMiniGroup-Android(영남대 소모임)와 백엔드·기능이 전혀 다르다. 본 마이그레이션은 iOS 앱을 **YuMiniGroup-Android의 1:1 미러**로 전면 재작성한다.

- **UI**: SwiftUI. 공용 UI는 ParallaxTabLayout iOS 킷(`IntelliJIDEAProjects/Minigroup/ParallaxTabLayout/iOS`)을 이식.
- **백엔드**: Android와 동일 — 영남대 LMS(ilos) HTML 스크래핑 + 포털 SSO 쿠키 인증 + Firebase RTDB(`yuminigroup`) 하이브리드.
- **데이터층**: 동일 LMS 솔루션(ilos)으로 검증된 KnuMiniGroup-iOS의 `HttpClient`/`HtmlUtil`/RemoteDataSource 로직을 YU 엔드포인트·YU SSO로 번안 이식.
- **선례**: KnuMiniGroup-iOS(UIKit, Android 1:1 미러 완성)가 데이터층·동작의 기준. 단 UI 프레임워크는 SwiftUI로 함(사용자 지정).

## 2. 범위

### 1차 포함 (이번 설계의 대상)

| 흐름 | 화면 |
|---|---|
| 인증 | LoginView(학번+비밀번호 SSO), SplashView(저장 자격증명 자동 재로그인) |
| 셸 | MainView(드로어 셸: 메인화면·영대소식·시간표·도서관좌석·순환버스·로그아웃 — 코어 외 항목은 "준비중" 자리만) |
| 그룹 홈 | GroupMainView(가입 그룹 그리드 + 당겨서 새로고침 + 하단 그룹찾기/가입신청중/그룹만들기 버튼 — 3버튼은 준비중 처리) |
| 그룹 상세 | GroupView(탭호스트 + CollapsingHeader), Tab1소식·Tab2일정·Tab3맴버·Tab4설정 |
| 게시글 | ArticleView(상세+댓글), CreateArticleView(작성/수정, 이미지 첨부), UpdateReplyView, PictureView(전체보기 줌) |
| 프로필 | ProfileView(조회·LMS 동기화·사진 변경), UserDialogView(맴버 미니 프로필 시트) |

### 1차 제외 (후속 로드맵)

- **2차**: 그룹 찾기(FindGroup)/생성(CreateGroup)/가입신청중(Request)/GroupInfo 다이얼로그, Firebase 채팅(그룹/1:1, ChatView), 인기그룹 슬라이더.
- **3차**: 영대소식(UnivNotice+WebView), 시간표(학기 LMS 스크랩+모의 SQLite), 도서관 좌석, 순환버스, 유튜브 검색·첨부, 설정 화면 잔여(SettingsActivity의 회원관리/모임정보 탭).
- **이식하지 않음**: AdMob, FCM 푸시(Android도 실수신 코드 없음), 레거시 로그 엔드포인트(`knu.dothome.co.kr` — 비밀번호를 평문 전송하는 분석 핑. 보안상 제외 확정).
- 유튜브 첨부가 달린 기존 게시글은 1차에서 **썸네일 표시 + 탭 시 유튜브 앱/웹 열기**로 처리(인라인 재생 없음).

## 3. 아키텍처

### 3.1 구조 매핑 (Android 패키지 ↔ iOS 그룹)

```
YuMinigroup/
├─ App/          YuMinigroupApp.swift   — @main, 조건부 FirebaseApp.configure()
│                EndPoint.swift         — 전체 URL 상수 (↔ app/EndPoint.java)
├─ Dto/          User, GroupItem, ArticleItem, ReplyItem, MemberItem   (↔ dto/, 동일 클래스명·필드)
├─ Data/         ArticleRepository, GroupRepository, ReplyRepository, UserRepository  (↔ data/, 순수 위임)
│  └─ Remote/    ArticleRemoteDataSource, GroupRemoteDataSource, ReplyRemoteDataSource,
│                UserRemoteDataSource   — LMS 파싱 + Firebase 이중기록 실로직 (↔ data/remote/)
├─ Helper/       HttpClient(URLSession+쿠키 관리 ↔ Volley/AppController), HtmlUtil(↔ Jericho),
│                MultipartRequest, PreferenceManager(UserDefaults 세션), Resource,
│                DateUtil, BitmapUtil(리사이즈·EXIF 회전), Toast
├─ ViewModel/    LoginViewModel, SplashViewModel, MainViewModel, GroupMainViewModel,
│                GroupViewModel, Tab1~Tab4ViewModel, ArticleViewModel, CreateArticleViewModel,
│                UpdateReplyViewModel, PictureViewModel, ProfileViewModel, UserViewModel
└─ View/         LoginView, SplashView, MainView, GroupMainView, GroupView, Tab1~Tab4View,
   │             ArticleView, CreateArticleView, UpdateReplyView, PictureView, ProfileView, UserDialogView
   └─ UI/        ParallaxTabLayout 킷 이식: CollapsingListScaffold(+CollapsingHeaderSpacer,
                 ScrollOffsetPreferenceKey), AppToolbar, DrawerScaffold, RefreshableLazyColumn,
                 FloatingActionButton, Compat
```

### 3.2 규약

- **배포 타깃 iOS 15.6** (KNU-iOS 15.6·실기기 iPhone 7과 일치). `NavigationView`+`StackNavigationViewStyle`+Compat 헬퍼 사용. iOS 16 전용 API(`NavigationStack`, `navigationDestination`, `PhotosPicker`) 금지 — 이미지 선택은 `PHPickerViewController` representable.
- **ViewModel**: `ObservableObject` + 단일 `@Published var state: State`(중첩 struct) 관용구. 클래스명·메소드명은 Android ViewModel과 동일하게. 인자는 Swift식 init 파라미터로 전달(Android SavedStateHandle 미러는 생략).
- **비동기 계약**: Android `Callback<T>`(onSuccess/onFailure/onLoading) ↔ `Resource<T>`(.loading/.success/.error) 방출. 데이터소스→리포지토리→VM 전 구간 `Resource` 수렴, KNU-iOS 관례를 따름.
- **페이징**: AndroidX Paging 미러 없음(Android도 미사용). 데이터소스 내부 offset 상태(`stopRequestMore` 상당) + 리스트 끝 감지 시 append — Android Tab1/Tab3와 동일 방식.
- **DI**: 프레임워크 없음. VM이 리포지토리를 직접 생성(Android 미러). 기존 InjectorUtils는 삭제.

## 4. 네트워킹·인증

### 4.1 SSO 로그인 시퀀스 (Android LoginViewModel/SplashViewModel 미러)

1. `POST lms.yu.ac.kr/ilos/lo/login_sso.acl` → 응답 `Set-Cookie`에서 `SESSION_IMAX` 추출.
2. `POST portal.yu.ac.kr/sso/login_process.jsp` — form: `userId`, `password`, `cReturn_Url`, `type=lms`, `login_gb=0`, 고정 `p=` 블롭. **`Referer: http://portal.yu.ac.kr/sso/login.jsp` 헤더 필수.** 응답에서 `ssotoken` 추출.
3. `SESSION_IMAX`+`ssotoken` 쿠키로 `login_sso.acl` 재호출 → 세션 확립.
4. `GET myinfo_form.acl` 스크랩(이름·학과·학번·이메일·전화), `GET myinfo_update_photo.acl`의 사진 URL `id=` 파라미터에서 **uid** 추출(Firebase 키 겸용).
5. `PreferenceManager.storeUser()`로 자격증명 저장 → SplashViewModel이 콜드 스타트마다 1~3 재실행.

- 쿠키는 `HttpClient`가 수동 보관하고 **모든 요청·이미지 로딩에 `Cookie` 헤더 부착**(LMS 보호 이미지 로딩 필수 — Android BindingAdapters의 GlideUrl+LazyHeaders 상당).
- URLSession은 `URLSessionConfiguration`에서 기본 쿠키 처리를 끄고 수동 관리(리다이렉트 시 Set-Cookie 소실 방지, KNU-iOS 방식).
- 테스트 계정 `22000000/TestUser`는 LMS 대신 Firebase Auth(`TestUser@yu.ac.kr`) 폴백(Android 미러).
- ATS: LMS가 http이므로 `NSAllowsArbitraryLoads=true` 유지.

### 4.2 HTML 파싱·업로드

- `HtmlUtil`: KNU-iOS의 것을 이식(동일 ilos 마크업으로 검증됨). id/태그 셀렉터·substring 유틸 제공. 파싱 코드는 Android RemoteDataSource의 메소드 단위 구조를 그대로 미러.
- 주요 엔드포인트: `share_group_list`(내 그룹), `share_list`(게시글, `?CLUB_GRP_ID&startL&displayL` LIMIT 10), `share_insert/update/delete`, `share_comment_insert/update/delete`, `share_member_list`, `myinfo_form/sync`, `file_upload_pop`(멀티파트 이미지 업로드 — 게시글·프로필 공용), `pop_academic_timetable_form`(3차).
- 학사일정: `homep.yu.ac.kr/_app/calendarxml_u.php` XML → `XMLParser`로 파싱(Tab2).

## 5. Firebase

- SPM `firebase-ios-sdk`(FirebaseDatabase, FirebaseAuth)를 pbxproj에 수동 등록(KNU-iOS의 등록 예시를 참조).
- **`GoogleService-Info.plist`는 Firebase 콘솔 `yuminigroup` 프로젝트에 iOS 앱(`com.hhp227.yu-minigroup`)을 추가해 받아야 함 — 사용자 액션.** 루트의 기존 plist는 KNU용(hhp227-ed727)이므로 사용 불가. plist 부재 시 configure 생략하고 LMS 단독 동작(이미지 목록·타임스탬프 보강만 빠짐) — KNU-iOS 방식.
- RTDB 경로(Android 미러): `Articles/{groupKey}`, `Replys/{articleKey}`, `Groups`, `UserGroupList`, `Users`, `Messages`(2차).
- 쓰기 이중화: LMS POST 성공 → 목록 재조회로 신규 id 획득 → Firebase 기록. 삭제 시 `Articles/{groupKey}/{articleKey}`와 `Replys/{articleKey}` 동시 제거. (비트랜잭션 한계는 Android와 동일함을 인지하고 수용.)

## 6. 화면별 설계

### 6.1 LoginView / SplashView
- LoginView: 학번·비밀번호 필드 + 유효성 에러 + 로딩 오버레이. 저장된 User가 있으면 앱 진입 시 SplashView 경유.
- SplashView: 1.25초 스플래시 동안 저장 자격증명으로 SSO 재실행. 실패 시 LoginView로 강등.

### 6.2 MainView (드로어 셸)
- `DrawerScaffold`(ParallaxTabLayout 킷) 기반. 드로어 헤더=프로필 이미지·이름(탭 → ProfileView), 메뉴=메인화면/영대소식/시간표/도서관좌석/순환버스/로그아웃. 코어 외 메뉴는 "준비중" 뷰. 라우팅은 enum(문자열 라우팅 금지).

### 6.3 GroupMainView
- 가입 그룹 2열 그리드(`share_group_list` 파싱) + 당겨서 새로고침 + 빈 상태 배너. 하단 그룹찾기/가입신청중/그룹만들기 버튼은 배치만 하고 준비중 안내. 그룹 탭 → GroupView(admin·grp_id·grp_nm·grp_img·key 전달, Android Intent extras 미러).

### 6.4 GroupView — CollapsingHeader 탭호스트 (핵심)

ParallaxTabLayout iOS의 `CollapsingListScaffold`를 이식하되 파라미터화한다.

- **치수**: 헤더 확장 높이 200pt(Android `CollapsingToolbarLayout` 200dp 미러, 예제의 256에서 조정), 툴바 56pt, 탭바 48pt. 그룹명은 핀 툴바에 고정(`titleEnabled=false` 미러 — 축소 애니메이션 타이틀 없음).
- **헤더 2모드**(Android `share_nophoto` 분기 미러):
  - 커버 사진 있음 → 쿠키 헤더로 커버 이미지 로드 + 하단 그라디언트 스크림(`bg_gradient` 상당), 엣지투엣지(상태바 투명).
  - 없음 → 기본 헤더 배경 + YU 로고 센터, 그라디언트 없음.
- **동작**(예제 그대로): 위 스크롤 시 헤더 먼저 collapse, 최상단 바운스 당김으로 expand, 접힘 비율로 이미지 페이드아웃, 접힘 시 내비바 배경 `colorPrimary`·틴트 흰색 전환. collapse offset은 탭 간 공유, 탭 전환 시 새 탭 리스트가 비최상단이면 강제 collapse(`ignoresNextExpansion` 로직 유지).
- **FAB**: 소식 탭에서만 노출(글쓰기 → CreateArticleView). 게시글 작성/새로고침 후 헤더 재확장+최상단 스크롤(Android `appbarLayoutExpand` 미러).
- **pull-to-refresh**: 헤더 펼침 상태에서만 활성(`RefreshableLazyColumn` 게이트).

### 6.5 탭 4종

| 탭 | 내용 |
|---|---|
| **Tab1 소식** | 게시글 피드. LMS `share_list` offset 페이징(10개) + Firebase `Articles/{groupKey}` 병합(이미지 목록·타임스탬프·uid). 무한 스크롤 + 로더 셀, 빈 상태 "글쓰기" 블록. 셀=아바타·이름·시간·본문 4줄·첫 이미지·댓글 수. 탭 → ArticleView. |
| **Tab2 일정** | 상단 월 캘린더 그리드(자체 SwiftUI 구현: 이전/다음 달 이동, 일정 있는 날 표시) + 해당 월 학사일정 리스트. 데이터는 학사일정 XML(그룹 데이터 아님 — Android 미러). |
| **Tab3 맴버** | `share_member_list` 파싱 멤버 그리드(4열) + 무한 스크롤 + 당겨서 새로고침. 탭 → UserDialogView 시트(이름·학번·학과, "메시지 보내기"는 준비중 비활성). |
| **Tab4 설정** | 카드형 목록: 사용자 설정(프로필), 소모임 설정(탈퇴/폐쇄 — 관리자 여부 분기 + 확인 다이얼로그 → `share_auth_drop_me`/`share_group_delete` + Firebase 정리), 어플리케이션 정보(공지·건의 mailto·버전). AdMob 없음. |

### 6.6 ArticleView / CreateArticleView / UpdateReplyView / PictureView
- ArticleView: 게시글 헤더 셀 + 이미지들(탭 → PictureView) + 유튜브 썸네일(외부 열기) + 댓글 리스트 + 하단 댓글 입력바. 작성자 본인이면 수정/삭제 메뉴(게시글·댓글 각각). 댓글 등록 시 목록 갱신 + Firebase `Replys` 기록.
- CreateArticleView: 제목·본문 + 이미지 첨부(카메라/앨범, `BitmapUtil` 리사이즈 후 멀티파트 업로드) + 작성/수정 모드(type 0/1). 성공 시 dismiss + Tab1 갱신(수정은 해당 항목 in-place 패치 — Android 결과 플럼빙 미러).
- UpdateReplyView: 단일 댓글 수정.
- PictureView: 가로 페이저 + 핀치 줌(`ZoomImageView` 상당을 SwiftUI로).

### 6.7 ProfileView
- LMS `myinfo_form` 조회 값 표시 + "동기화"(`myinfo_sync`) + 프로필 사진 변경(미리보기 → 업로드). 변경 시 그룹 화면들 아바타 갱신 신호(Android의 result 플럼빙을 Combine 신호로 대체).

## 7. 에러 처리

- `try!`/`fatalError` 전면 금지. 모든 네트워크·파싱 실패는 `Resource.error(message)`로 수렴, 화면에서 토스트/스낵바 상당으로 표출.
- 파싱 실패(마크업 변화)는 빈 결과 + 에러 메시지로 강등. 크래시 금지.
- 세션 만료 감지(응답이 로그인 페이지) 시 저장 자격증명으로 1회 자동 재로그인 후 재시도, 실패 시 LoginView 강등.
- 이미지 업로드 실패 시 게시글 등록 중단 + 사용자 안내(부분 업로드 상태 방지).

## 8. 기존 코드 정리 (전면 삭제)

- `YuMinigroup/Api/` 전체, `YuMinigroup/Data/` 전체(구 PHP 리포지토리), `YuMinigroup/Helper/Paging/`(~2,700줄), `Helper/SavedStateHandle.swift`, `Util/`(URLs·InjectorUtils·ImagePicker·ReachabilityService — DateUtil은 신규로 재작성), `Model/` 전체(Resource는 Helper/Resource로 재작성), `View/`·`ViewModel/` 전체.
- 유지: 에셋 일부(`add_photo`, `profile_img_circle`, `hamburger-menu-icon`, AccentColor 등), 프로젝트 설정(번들 ID `com.hhp227.yu-minigroup`).
- pbxproj에서 삭제 파일 참조 제거 + 신규 파일 수동 등록(그룹 구조 일치).

## 9. 검증 계획

- 이 개발 환경(WSL)에서는 Swift 컴파일 불가 → **빌드·실행 검증은 사용자 Mac(Xcode)**. 실기기 iPhone 7(iOS 15.x).
- 체크리스트: ① 실계정 SSO 로그인 → 그룹 그리드 표시 ② 그룹 진입 → 4탭·CollapsingHeader 동작(접힘/펼침/탭 전환/FAB) ③ 소식 페이징·게시글 상세·댓글 CRUD ④ 이미지 첨부 게시글 작성 ⑤ 스플래시 자동 로그인 ⑥ plist 없이도 기동(LMS 단독).
- 테스트 타깃 없음(Android 미러). 커밋 정책: 스테이징까지만, 커밋·push는 사용자.

## 10. 리스크·전제

- **LMS 마크업 의존**: 파서는 위치 기반 — YU LMS 개편 시 파손. KNU 검증 파서 재사용으로 완화하되, YU 실응답 대조는 사용자 실기기 검증에 의존.
- **YU SSO `p=` 블롭**: Android에 하드코딩된 매직 값 재사용. 포털 정책 변경 시 로그인 파손 가능.
- **Firebase plist**: `yuminigroup` 프로젝트 iOS 앱 등록·plist 다운로드는 사용자 액션. 지연 시 Firebase 보강 기능 검증이 밀림.
- **평문 자격증명 저장**: Android 미러상 유지(UserDefaults). Keychain 전환은 후속 개선 후보로 기록만.
- pbxproj 수동 등록 실수 → 빌드 파손: 파일 추가/삭제 시 등록 목록을 산출물로 남겨 검증.
