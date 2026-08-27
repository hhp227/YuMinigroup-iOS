# Mac 빌드/인수 체크리스트 — YuMinigroup-iOS 코어 마이그레이션

이 문서는 사용자 Mac에서 실행하는 체크리스트입니다. 개발 환경(WSL)은 Swift 컴파일이 불가능하므로, 이 체크리스트가 실제 빌드·런타임 검증의 유일한 통로입니다.

관련 문서: `docs/superpowers/specs/2026-08-26-yuminigroup-ios-migration-design.md`(설계 §9 검증 계획 원본), `.superpowers/sdd/2026-08-26-yuminigroup-ios-core-migration/progress.md`(태스크별 진행 로그·미결 사항 전체).

## 1. SPM resolve

1. `YuMinigroup.xcodeproj`를 Xcode에서 엽니다.
2. **File → Packages → Resolve Package Versions**를 실행해 `firebase-ios-sdk`(FirebaseCore/FirebaseDatabase/FirebaseAuth)를 내려받습니다.
3. 패키지 그래프 오류 없이 완료되는지 확인합니다.

## 2. 빌드 (⌘B)

이 환경은 Swift 컴파일을 검증할 수 없었기 때문에 **처음 빌드할 때 타입 오류가 나올 가능성**이 있습니다. 오류가 나면 아래 순서로 우선 확인하세요(위험도 높은 순):

1. **`YuMinigroup/Data/Remote/UserRemoteDataSource.swift`의 SSO 파싱** — SSO 3단계 시퀀스(`login_sso.acl` → `portal.yu.ac.kr/sso/login_process.jsp` → `login_sso.acl` 재호출)와 `myinfo_form`/`myinfo_update_photo` 스크래핑. 실 HTML 마크업에 의존하는 로직이라 컴파일 오류뿐 아니라 파싱 실패 가능성도 가장 높은 지점입니다.
2. **`YuMinigroup/View/GroupView.swift`(+ `View/UI/CollapsingHeader.swift`)의 CollapsingHeader** — ParallaxTabLayout 킷 이식 + 파라미터화 지점. `#available(iOS 16.0, *)` 분기(`View/UI/Compat.swift`)를 포함해 프리뷰/빌드 타깃 SDK 버전에 따라 경고·오류가 날 수 있습니다.
3. **페이징 탭들(`Tab1View`/`Tab3View` + 각 ViewModel)** — offset 기반 무한 스크롤 상태 관리. `Tab1View`의 `Dictionary(uniquingKeysWith:)` 안전 생성자 등 커스텀 로직이 있습니다.

빌드가 성공하면 3번으로, 실패하면 위 우선순위대로 원인 파일을 열어 확인합니다.

## 3. 런타임 인수 체크리스트 (실기기 iPhone, iOS 15.x 권장)

시뮬레이터로도 대부분 확인 가능하지만, 카메라 촬영 첨부(⑤)와 실제 LMS 네트워크 왕복은 실기기에서 확인하는 것을 권장합니다.

- [ ] **① 실계정 SSO 로그인 → 그룹 그리드**: 학번+비밀번호로 로그인 → 가입된 그룹이 2열 그리드로 표시됨.
- [ ] **② 그룹 진입 → CollapsingHeader 4항목**:
  - [ ] 아래로 스크롤 시 헤더가 접힘(collapse), 최상단에서 당기면 펼쳐짐(expand + 바운스)
  - [ ] 탭 전환 시 새 탭이 스크롤 중간 상태면 헤더가 강제로 접힘(collapse offset이 탭 간 공유됨)
  - [ ] 커버 사진 있는 그룹 / 없는 그룹(기본 배경 + YU 로고) 양쪽 헤더 모드 확인
  - [ ] FAB(플로팅 작성 버튼)이 **소식 탭에서만** 노출되고 다른 탭(일정/맴버/설정)에서는 숨겨짐
- [ ] **③ 소식 페이징 + 게시글 상세 + 댓글 CRUD**: 소식 탭 하단 스크롤 시 다음 페이지 로드 → 게시글 탭 → 상세 화면 진입 → 댓글 작성/수정/삭제가 반영됨(목록 갱신 확인).
- [ ] **④ 이미지 첨부 게시글 작성**: 카메라 촬영 + 앨범 선택 양쪽 경로로 이미지 첨부 후 작성 → 업로드 성공 → 소식 목록에 반영됨. 카메라 권한 프롬프트에 `NSCameraUsageDescription`("게시글 사진 촬영에 사용됩니다") 문구가 뜨는지 확인.
- [ ] **⑤ 스플래시 자동 로그인**: 로그인 상태에서 앱을 완전 종료 후 재실행 → 스플래시 화면(약 1.25초) 동안 저장 자격증명으로 자동 재로그인 → 그룹 그리드로 바로 진입(로그인 화면 재노출 안 됨).
- [ ] **⑥ GoogleService-Info.plist 없이 기동**: 타깃에서 plist를 빼고(또는 빌드 스킴에서 제외하고) 실행 → 앱이 크래시 없이 정상 기동하고 로그인·그룹·게시글 등 LMS 기반 기능이 그대로 동작함(Firebase 보강 정보인 이미지 목록/타임스탬프만 일부 빠질 수 있음).
- [ ] **⑦ 테스트 계정 Firebase Auth 폴백**: `22000000`/`TestUser`로 로그인 → 실 SSO를 건너뛰고 `TestUser@yu.ac.kr` Firebase Auth 경로로 로그인됨(⑥에서 plist를 뺀 상태면 이 항목은 스킵되거나 실패하는 것이 정상 — plist를 다시 넣은 빌드에서 확인).
- [ ] **⑧ 프로필 조회/동기화/사진 변경**: ProfileView 진입 → LMS 조회 값(이름/학과/학번/이메일/전화) 표시 확인 → "동기화" 버튼 → 사진 변경(미리보기 → 적용) → **적용 직후 새 사진이 바로 반영되는지 확인**(프로필 화면 자체는 Task 19에서 이 케이스가 수정되었으나, 드로어 헤더·Tab4 등 다른 화면의 아바타는 캐시로 인해 지연될 수 있음 — 아래 "알려진 제약" 참고).

## 4. 알려진 제약 / 실기기에서 특히 확인할 사항

`.superpowers/sdd/2026-08-26-yuminigroup-ios-core-migration/progress.md`(태스크별 진행 로그)에 기록된 항목 중, 실제 사용에 영향을 줄 수 있는 것들입니다. 버그가 아니라 **Android 미러 설계상 의도된 동작이거나, 실 LMS 마크업/응답으로만 검증 가능한 항목**입니다.

- **당겨서 새로고침(pull-to-refresh)은 대부분의 탭에서 장식적입니다.** `RefreshableLazyColumn` 킷 원본이 `refresh()` 콜백을 실제로 호출하지 않는 구조라, 목록을 갱신하려면 화면을 재진입(탭 이동 후 복귀 등)해야 합니다. 여러 탭에 공통된 동작이며, Android도 동일한 UX는 아니지만 이번 마이그레이션의 알려진 후속 과제입니다.
- **LMS HTML 파싱은 실 마크업으로 검증되지 않았습니다.** 그룹 목록(`share_group_list`), 게시글 목록(`share_list`), 맴버 목록(`share_member_list`), 내 정보(`myinfo_form`) 파서는 KNU-iOS의 검증된 파서를 YU 엔드포인트로 번안한 것이라, LMS가 개편되었거나 YU와 KNU의 마크업이 미묘하게 다르면 파싱이 깨질 수 있습니다. 특히 `myinfo_form`은 `content_text` 앵커가 없을 때 전체 HTML fallback으로 훑기 때문에, 무관한 영역(nav/footer)에서 이름/전화/이메일이 잘못 추출될 가능성이 이론상 있습니다. ①③⑧을 실제 계정으로 확인할 때 함께 봐주세요.
- **SSO `p=` 블롭 + Cookie 교차 송신**: 로그인 2단계(`portal.yu.ac.kr/sso/login_process.jsp`)에서 `SESSION_IMAX` 쿠키를 포털 쪽에 교차 송신합니다. Android에 하드코딩된 매직 값을 그대로 재사용한 것이라, 포털 정책이 바뀌면 로그인이 깨질 수 있습니다. ①이 실패하면 가장 먼저 의심할 지점입니다.
- **LMS `.acl` 엔드포인트마다 요청 메소드가 실서버에서 그대로 통할지는 미검증입니다.** `share_member_list.acl`(맴버 탭 Tab3, `GroupRemoteDataSource.swift:87`)만 의도적으로 GET을 씁니다(Android/KNU-iOS 선례 미러). 그 외 `share_list.acl`(게시글 목록 — `ArticleRemoteDataSource.swift:88,195,479`, `ReplyRemoteDataSource.swift:66`)과 `share_group_list.acl`(가입 그룹 목록 — `GroupRemoteDataSource.swift:54`)은 전부 POST입니다. 즉 화면별로 메소드가 갈리는 게 아니라 **맴버 목록만 GET, 나머지 목록류는 전부 POST**로 고정되어 있습니다. Mac 실테스트에서 맴버 탭(Tab3) 그리드가 비어 오면 그 GET을, 게시글/그룹 목록(①③)이 비어 오면 그 POST를 먼저 의심하세요.
- **`updateProfileImage`가 LMS 응답이 실패 메시지("실패했습니다" 등)여도 `.success`를 반환할 수 있습니다.** ProfileView의 "적용됨" 판정이 이 응답을 신뢰하므로, 실제로는 사진 변경이 실패했는데 성공한 것처럼 보일 가능성이 있습니다. ⑧에서 사진이 실제로 바뀌었는지(다음 로그인/새로고침 후에도 유지되는지) 함께 확인해주세요.
- **아바타 캐시가 화면 간에 즉시 동기화되지 않습니다.** `RemoteImage`는 이미지 URL 문자열을 키로 쓰는 `NSCache`를 쓰는데, 프로필 화면 자체는 새 사진 적용을 즉시 반영하도록 고쳐졌지만(Task 19) 드로어 헤더나 Tab4(설정 탭) 등 다른 화면은 캐시가 갱신될 때까지 이전 사진이 보일 수 있습니다.
- **드로어가 ProfileView 뒤에 열린 채로 남아있을 수 있습니다.** MainView 진입 흐름에서 드로어를 닫는 콜백이 배선되지 않은 케이스가 있어, ProfileView를 열고 닫을 때 드로어가 배경에 열려있는 상태로 보일 수 있습니다. UX상 이상하게 보이면 알려진 이슈로 인지해주세요.
- **테스트 계정(⑦)은 GoogleService-Info.plist가 있어야 동작합니다.** Firebase Auth 폴백이라, plist를 뺀 빌드(⑥)에서는 이 항목이 실패하는 것이 정상입니다 — 버그로 오인하지 마세요.
- **게시글 이미지 업로드 응답 파싱이 취약할 수 있습니다.** `uploadImage`가 업로드 응답에서 이미지 URL을 추출하는 방식이 Android를 미러한 문자열 뒤에서부터의 추출이라, 실제 LMS 응답 포맷이 예상과 다르면 실패할 수 있습니다. ④를 확인할 때 함께 봐주세요.
- **드로어 메뉴 아이콘(SF Symbol)이 카탈로그에 존재하는지 미검증**입니다. 런타임에 특정 메뉴 아이콘이 비어 보이면(깨진 게 아니라 아이콘만 없는 것) 이름 교체로 간단히 고칠 수 있는 코스메틱 이슈입니다.

이 목록에 없는 세부 사항(더 마이너한 것들 포함)은 `.superpowers/sdd/2026-08-26-yuminigroup-ios-core-migration/progress.md`의 각 태스크 항목에 전부 기록되어 있습니다.

## 5. 2차 (second 브랜치) 추가 체크리스트

이 섹션은 2차(그룹 라이프사이클 + 채팅, `second` 브랜치, 베이스 `434bc6a`)에서 추가된 항목입니다. 신규 파일은 17종(뷰/ViewModel 14 + Dto 1 + Data 2, pbxproj ID 152~185)입니다. 관련 문서: `docs/superpowers/specs/2026-08-27-phase2-groups-chat-design.md`(설계), `docs/superpowers/plans/2026-08-27-phase2-groups-chat.md`(계획), `.superpowers/sdd/2026-08-27-phase2-groups-chat/progress.md`(태스크별 진행 로그·리뷰 이연 사항 전체).

### 5.1 빌드 (⌘B) — 위험도 높은 순

1. **`YuMinigroup/Data/Remote/ChatRemoteDataSource.swift`의 Firebase 쿼리·트랜잭션 시그니처** — `queryStarting(atValue:)` / `queryEnding(atValue:)` / `queryEqual(toValue:)` / `runTransactionBlock` / `updateChildValues`. 계획서 원문의 `updateChildren`(Android/Web API명)은 iOS SDK 실명인 `updateChildValues`로 이미 교정되어 있으니 혼동하지 마세요.
2. **`YuMinigroup/View/GroupView.swift`의 툴바(채팅 진입 버튼 추가) + CollapsingHeader 공존** — 1차 CollapsingHeader와 2차 툴바 변경이 같은 화면에서 충돌 없이 컴파일되는지.

### 5.2 런타임 인수 체크리스트 (실기기 권장)

- [ ] **⑨ 그룹찾기 목록**: 그룹찾기 탭 진입 → 목록 노출 확인(실마크업 1순위 검증 — accordion 셀렉터) → 하단 스크롤 시 다음 페이지 로드(페이징) → 가입신청을 자동승인 그룹 1회, 운영자승인 그룹 1회 각각 실행한 뒤 Firebase 콘솔에서 `UserGroupList/{내uid}/{key}` 값이 각각 true/false로 기록되는지 확인. **Firebase에 미등록된 그룹(비앱 그룹)으로도 1회 수행** — LMS ID 폴백 경로 검증.
- [ ] **⑩ 가입신청중 목록**: 승인 대기 중인 그룹만 노출되는지(정식 가입 그룹은 미노출) → 신청취소 실행 → 목록에서 즉시 제거되는지(갱신) 확인.
- [ ] **⑪ 그룹 만들기**: 이미지 없이 1회 + 이미지 첨부 1회(302 응답 경로) 각각 생성 → 생성 직후 새 그룹 화면으로 바로 진입하는지 → LMS(학교 커뮤니티에 신규 그룹 노출)와 Firebase(`Groups/{key}`, `UserGroupList/{내uid}/{key}=true`) 양쪽에 등록되는지 확인.
- [ ] **⑫ 채팅 송수신**: 그룹채팅 1회 + 1:1 채팅 1회 송수신 → 두 기기(또는 기기+시뮬레이터)로 실시간 수신 확인 → 위로 스크롤 시 이전 메시지 페이징 로드 → 화면 재진입 시 중복 메시지가 없는지 확인.
- [ ] **⑬ 채팅 목록**: 그룹방 + 1:1방이 함께 노출되고 마지막 메시지 시각 기준 내림차순 정렬되는지 → 각 방의 마지막 메시지 미리보기 텍스트가 맞는지 확인.
- [ ] **⑭ Firebase 미구성 상태**: `GoogleService-Info.plist`를 제거한 빌드에서 그룹찾기/가입신청중/그룹 만들기/채팅/채팅 목록 각 화면이 크래시 없이 안내 문구를 보여주는지 확인.

### 5.3 리뷰 이연 항목 (실기기/실마크업 확인 필요)

1차 리뷰(Task 1~10)에서 코드 자체는 설계대로 확정되었으나, 실 LMS 마크업이나 실기기 체감으로만 검증 가능해 보류된 항목입니다.

- [ ] **share_group_list 파서 완전일치 클래스 검색**: `GroupRemoteDataSource`의 `class="button"` / `class="menu_list"` 검색이 **완전일치**라, 실 마크업이 `class="button active"`처럼 멀티클래스면 해당 카드가 누락될 수 있습니다(크래시 아님). 실마크업에서 클래스 속성이 단일값인지 먼저 확인하세요(Task 1 이연).
- [ ] **menu_list 스코프 미발견 시 nil 강등**: 위와 같은 이유로 `.menu_list` 스코프를 못 찾으면 `joinType`/`description`이 nil로 강등됩니다. 실마크업에 `.menu_list` 스코프와 첫 `<a>` 스코프(info 목록) 두 곳이 예상대로 존재하는지 확인하세요(Task 1 이연).
- [ ] **가입신청 성공 토스트 지연**: 신청 성공 토스트를 보여준 뒤 1.2초 지연 후 화면을 pop합니다(`FindGroupView.swift`). 실기기에서 토스트가 충분히 읽히는 시간인지 체감 확인 후 필요하면 지연값을 튜닝하세요(Task 3 이연).
- [ ] **채팅 실시간 재진입 시 중복 수신 확인**: `afterKey`로 필터 쿼리(`queryStarting(atValue:)`)를 등록해 관찰을 시작한 뒤 화면을 이탈(무필터 `ref`로 `removeObserver` 호출)했다가 재진입할 때, 기존에 이미 수신한 메시지가 `childAdded`로 다시 중복 발생하지 않는지 확인하세요(필터 쿼리로 등록·무필터 ref로 해제하는 교차 패턴이라 이론상 위험 지점, Task 7 이연).
- [ ] **Firebase 쿼리·트랜잭션 시그니처 실기기 컴파일 확인**: `queryStarting(atValue:)` / `queryEnding(atValue:)` / `queryEqual(toValue:)` / `runTransactionBlock` / `updateChildValues`가 실제 Firebase iOS SDK 버전과 시그니처가 일치해 정상 컴파일되는지 확인하세요(5.1-1과 동일 지점, 컴파일 성공 후에도 별도로 체크).
- [ ] **가입 그룹 목록(1차) LMS ID 폴백 — 3차에서 해소(fix round 1로 커버리지 보강)**: 1차 `mergeFirebaseKeys`/`resolveKeys`(가입한 그룹, GroupMainView)에 2차 `mergeFirebaseGroupKeys`(그룹찾기, `fe945d1`)와 동일한 "매칭 실패 시 key = LMS ID" 폴백을 적용했습니다(Task 12, 3차) — `resolveKeys` 완료 콜백(성공 경로, `remaining == 0` 지점)뿐 아니라, `UserGroupList/{uid}`가 비어 있어 `resolveKeys` 자체를 호출하지 않고 조기 반환하는 두 지점(스냅샷에 자식이 없을 때 / keys가 비었을 때)에도 동일 폴백(`applyLmsIdKeyFallback`)을 적용했습니다(fix round 1, Finding 3) — 비앱 그룹만 가입한 계정(이번 부채가 가장 먼저 겨냥한 케이스)은 애초에 `UserGroupList`가 비어 있으므로 이 보강이 없으면 여전히 key==nil로 남습니다. 비앱 그룹의 그룹채팅 진입이 더 이상 key==nil 가드에 막히지 않아야 합니다. **실기기 검증**: 비앱 그룹(Firebase 미등록 LMS 그룹)"만" 가입된 계정(다른 정식 그룹은 하나도 없는 케이스 우선)으로 그룹 진입 → 그룹채팅이 "채팅을 사용할 수 없습니다" 없이 정상 진입되는지 확인 → 해당 그룹에서 게시글 작성 후 Firebase 콘솔에서 `Articles/{lmsId}` 이중기록이 함께 생기는지 확인(부수 효과). Firebase 조회 자체가 실패(withCancel)하거나 `FirebaseRef.database()`가 nil인 경우는 폴백이 적용되지 않고 현행대로 LMS 결과만으로 성공 처리되므로 별도 크래시가 없는지도 함께 확인.
- [ ] **DM 목록 REST shallow 하드닝 — fix round 1(Finding 1, 2)**: `fetchDirectChatRooms`의 REST shallow 요청(`ChatRemoteDataSource.swift`)이 ① HTTP 상태코드 200 및 응답 JSON에 `"error"` 키가 없는지까지 확인해야 진짜 성공으로 간주하고, 아니면(권한 거부 401 등 포함) `fallbackFullRead`로 강등하도록 고쳤습니다 — **실기기에서 실제 요청 URL을 1회 로깅해 확인**(`performShallowFetch`의 `urlString` 생성 직후 임시 `print`나 브레이크포인트로) ② 트레일링 슬래시 유무에 따라 `databaseURL`이 정규화되어 `.../rtdb-host/Messages/{uid}.json?shallow=true`처럼 `//`가 이중으로 붙지 않는지, ③ Firebase Auth 세션이 있는 테스트 계정(`22000000`/`TestUser`)에서는 URL 끝에 `&auth=<token>`이 붙는지, 실 SSO 계정(Firebase Auth 세션 없음 — 대다수)에서는 `&auth=` 없이 `?shallow=true`만으로 요청되는지 확인하세요. DM 방이 있는 계정으로 채팅 목록(⑬)을 열어 REST 응답이 200으로 성공하는 경우와(정상 시나리오), RTDB 규칙이 이 경로를 거부하는 경우(있다면) 양쪽 다 방 목록이 비지 않고 정상 노출되는지(후자는 `fallbackFullRead` 강등 경로) 확인하세요.

이 목록에 없는 세부 사항은 `.superpowers/sdd/2026-08-27-phase2-groups-chat/progress.md`의 각 태스크 항목에 전부 기록되어 있습니다.
