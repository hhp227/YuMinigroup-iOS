# YuMinigroup-iOS 3차 (대학유틸·그룹설정·유튜브·기술부채) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 대학유틸 4종+공지·그룹 설정(admin)·유튜브 검색/첨부/재생·기술 부채 3건을 구현해 YuMiniGroup-Android 미러를 완결한다.

**Architecture:** 1·2차 패턴 그대로 — SwiftUI(iOS 15.6) + ObservableObject VM + Repository/RemoteDataSource. 신규 공통 인프라는 WebViewScreen(WKWebView) 하나.

**Tech Stack:** SwiftUI, WKWebView(UIViewRepresentable), URLSession(HttpClient/공개 GET), FirebaseDatabase, UserDefaults(모의시간표 JSON)

**Spec:** `docs/superpowers/specs/2026-08-27-phase3-utils-settings-youtube-design.md` — 각 태스크 구현 전 해당 § 정독. Android 원본 상세(URL·셀렉터·문구 verbatim)는 스펙이 원전.

## Global Constraints

- 배포 타깃 **iOS 15.6**. iOS 16 전용 API 금지(`NavigationStack`/`navigationDestination`/`PhotosPicker`/`presentationDetents`).
- **WSL은 Swift 컴파일 불가.** 검증 = 정적(grep 정합·스펙/Android 대조). 테스트 타깃 없음(확정).
- **커밋**: 브랜치 **`second`** 이어서, 태스크별 경로 지정 add + 한 줄 커밋, **트레일러(Co-Authored-By 등) 금지**, **push 금지**. `git add -A` 금지. 새 파일 LF.
- **pbxproj 수동 등록**: 신규 파일마다 4곳(PBXBuildFile/PBXFileReference/PBXGroup/PBXSourcesBuildPhase). ID는 `YU`+22자리 순번 — **각 태스크 시작 시 `grep -o "YU000000000000000000[0-9]*" YuMinigroup.xcodeproj/project.pbxproj | sort -u | tail -1`로 현재 최대 확인 후 +1부터 발급**(3차 시작 시점 최대 = 185).
- **미러 명명**·`Resource<T>` 수렴·`try!`/`fatalError` 금지·파싱 실패는 항목 skip/`.error` 강등(크래시 금지)·Firebase 접근은 `FirebaseRef.database()` nil 가드.
- wire 계약(URL·파라미터·셀렉터·embed 태그)은 스펙 §4~7 값 그대로. 공개 엔드포인트(영대소식·좌석·유튜브·버스)는 쿠키 불필요, 학기시간표·그룹설정은 LMS 쿠키(`CookieStore.shared.cookieHeader`).
- 참조(읽기 전용): Android=`../YuMiniGroup-Android/app/src/main/java/com/hhp227/yu_minigroup/`.

---

### Task 1: WebViewScreen 공통 컴포넌트 + 셔틀버스

**Files:**
- Create: `YuMinigroup/View/WebViewScreen.swift`
- Modify: `YuMinigroup/App/EndPoint.swift`(+`shuttleBus` 상수), `YuMinigroup/View/MainView.swift`(`.shuttleBus` 분기)
- Modify: `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `AppToolbar(title:navigationIcon:onNavigationClick:)`, `MainContentRouter`의 스텁 분기
- Produces:

```swift
struct WebViewScreen: View {
    // onMenuClick nil → push된 자식(시스템 네비바 .navigationTitle(title) inline)
    // onMenuClick 있음 → 드로어 루트(AppToolbar(title, .menu, onMenuClick), 시스템 네비바 비의존)
    init(urlString: String, title: String, onMenuClick: (() -> Void)? = nil)
}
// EndPoint
static let shuttleBus = "https://hcms.yu.ac.kr/main/life/information-on-the-school-bus.do"
```

- [ ] **Step 1: Android 대조** — `activity/WebViewActivity.java`(url/title extras, JS on, 줌)·`fragment/BusFragment.java`(동일 설정의 인라인 WebView).
- [ ] **Step 2: WebViewScreen 작성** — 내부 `private struct WebView: UIViewRepresentable`(WKWebView, `javaScriptEnabled`는 `WKWebpagePreferences.allowsContentJavaScript = true`(iOS14+) 사용, navigationDelegate로 `isLoading` Binding 갱신 — didFinish/didFailProvisional 모두 해제). 본체: `onMenuClick` 있으면 `VStack { AppToolbar(...); webView }`, 없으면 `webView.navigationTitle(title).navigationBarTitleDisplayMode(.inline)`. 로딩 중 중앙 `ProgressView` 오버레이. 줌·wide viewport는 WKWebView 기본(설정 불필요 — 헤더 주석에 근거).
- [ ] **Step 3: 셔틀버스 배선** — MainContentRouter에 `case .shuttleBus: WebViewScreen(urlString: EndPoint.shuttleBus, title: "순환버스 시간표", onMenuClick: onMenuClick)` 분기 추가(기존 default 분기에서 분리).
- [ ] **Step 4: pbxproj 등록 + 검증** — 1파일. grep: `WebViewScreen` 4곳, MainView에서 `.shuttleBus`가 PlaceholderView를 타지 않는지, iOS16 API 0건.
- [ ] **Step 5: 커밋** — `feat: add shared web view screen and wire shuttle bus route`

---

### Task 2: 영대소식

**Files:**
- Create: `YuMinigroup/Dto/BbsItem.swift`, `YuMinigroup/Data/Remote/UnivNoticeRemoteDataSource.swift`, `YuMinigroup/Data/UnivNoticeRepository.swift`, `YuMinigroup/ViewModel/UnivNoticeViewModel.swift`, `YuMinigroup/View/UnivNoticeView.swift`
- Modify: `YuMinigroup/App/EndPoint.swift`, `YuMinigroup/View/MainView.swift`(`.univNotice` 분기), `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `HttpClient.request`(쿠키 없이 — headers 생략), `HtmlUtil`, `WebViewScreen`(Task 1), `Resource<T>`
- Produces:

```swift
struct BbsItem: Identifiable, Hashable { var id, title, writer, date: String }
// UnivNoticeRemoteDataSource + Repository 패스스루
func fetchNotices(offset: Int, completion: @escaping (Resource<[BbsItem]>) -> Void)  // articleLimit=10 고정
// EndPoint
static let yuNoticeList = "https://www.yu.ac.kr/main/intro/yu-news.do?mode=list"
static func yuNoticeView(articleNo: String) -> String  // ...?mode=view&articleNo={id}
// UnivNoticeViewModel: State { items/isLoading/hasRequestMore/isEndReached/message } (2차 FindGroupViewModel 모양)
// MAX 100건: fetchNextPage()는 offset < 100일 때만. offset 0에서 +10(스펙 §2 결함 1 — 0 기준 통일)
```

- [ ] **Step 1: Android 정독** — `fragment/UnivNoticeFragment.java`·`viewmodel/UnivNoticeViewModel.java`·`res/layout/bbs_item.xml`.
- [ ] **Step 2: 데이터층** — GET `EndPoint.yuNoticeList + "&articleLimit=10&article.offset=\(offset)"`(쿠키·헤더 없음). 파싱: `.board-table` 블록(1차 `allTags`/세그먼트 관례 — `class="board-table"` 여는 태그부터 `</table>`까지) → `<tbody>` 블록 → `<tr>` 블록들(`HtmlUtil.rows`) → 각 행의 `<td>` 블록들: [1]=제목 텍스트+첫 `<a>` href를 `CharacterSet(charactersIn: "=&")`로 split한 **[3]**=id, [2]=작성자, [3]=날짜(전부 `HtmlUtil.text`). 행 실패 skip. 파싱 결과 빈 배열 + HTML에 board-table 자체가 없으면 `.error("목록을 불러오지 못했습니다.")` 강등.
- [ ] **Step 3: VM** — 위 Interfaces 모양. init 즉시 로드, `fetchNextPage()` 가드(`!isLoading && !isEndReached && offset < 100`), 성공 시 `items += 신규; offset += 10; isEndReached = 신규.isEmpty || offset >= 100`. `refresh()`는 offset 0 리셋+재조회.
- [ ] **Step 4: 뷰** — 드로어 루트: 로컬 `NavigationView`+`AppToolbar("영대소식", .menu)`+`navigationBarHiddenCompat()`(ChatListView 관례). 셀=카드(제목 17pt singleLine / 날짜 15pt+우측 작성자 10pt caption) — private struct. 첫 로딩만 중앙 스피너(`isLoading && items.isEmpty`), 마지막 셀 onAppear 페이징, `.refreshable`, 셀 탭 `NavigationLink` → `WebViewScreen(urlString: EndPoint.yuNoticeView(articleNo: item.id), title: "영대소식")`. `.toast`.
- [ ] **Step 5: MainView 분기 + pbxproj(5파일) + 검증** — URL 문자열·셀렉터 스펙 §4.1 대조, iOS16 grep 0.
- [ ] **Step 6: 커밋** — `feat: add university news screen`

---

### Task 3: 도서관 좌석

**Files:**
- Create: `YuMinigroup/Dto/SeatItem.swift`, `YuMinigroup/Data/Remote/SeatRemoteDataSource.swift`, `YuMinigroup/Data/SeatRepository.swift`, `YuMinigroup/ViewModel/SeatViewModel.swift`, `YuMinigroup/View/SeatView.swift`
- Create(에셋): `YuMinigroup/Assets.xcassets/yu_library_seat01.imageset/`(Android `res/drawable*/yu_library_seat01.*` 복사 + Contents.json)
- Modify: `YuMinigroup/App/EndPoint.swift`, `YuMinigroup/View/MainView.swift`, `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `CollapsingListScaffold`(showTabs: false 지원 확인됨), `WebViewScreen`, URLSession(JSON GET — HttpClient는 문자열 반환이므로 `HttpClient.request` 후 JSONSerialization 또는 URLSession 직접 중 기존 관례(HttpClient+JSONDecoder, performRemoval 참고) 사용)
- Produces:

```swift
struct SeatItem: Identifiable, Hashable { var id, name, count, occupied, percentageInteger, status: String }
func fetchSeats(completion: @escaping (Resource<[SeatItem]>) -> Void)   // + Repository 패스스루
// EndPoint
static let librarySeatRooms = "https://slib.yu.ac.kr/Clicker/GetClickerReadingRooms"
static func librarySeatDetail(id: String) -> String   // https://slib.yu.ac.kr/clicker/UserSeat/{id}
// SeatViewModel: State { items/isLoading/message }, init 즉시 조회, refresh()는 isLoading 미표시(스펙 §4.3)
```

- [ ] **Step 1: Android 정독** — `fragment/SeatFragment.java`·`viewmodel/SeatViewModel.java`·`res/layout/seat_item.xml`·`adapter/BindingUtils.java`.
- [ ] **Step 2: 데이터층** — GET `librarySeatRooms`(쿠키 없음) → JSON 루트 키 **`_Model_lg_clicker_reading_room_brief_list`** 배열. 필드 `l_id/l_room_name/l_count/l_occupied/l_percentage_integer/l_open_mode` — **유연 디코딩**(각 값을 `String` 우선, 실패 시 `Int`→String화; JSONSerialization dict에서 `"\($0)"` 강등 방식이 간단). 항목 실패 skip.
- [ ] **Step 3: 뷰** — `CollapsingListScaffold(title: "도서관 좌석", navigationIcon: .menu, onNavigationClick: onMenuClick, showTabs: false, tabTitles: [], selectedTab: .constant(0), collapseOffset:, onTabSelected: { _ in }, imageHeight: 240, headerBackground: { Image("yu_library_seat01")+하단 그라디언트 })` — GroupView 사용례 참고하되 드로어 루트라 `navigationIcon: .menu`(킷의 메뉴 모드 시그니처는 CollapsingHeader.swift에서 확인, 미지원이면 GroupMainView식 AppToolbar+일반 헤더 이미지로 폴백 구현하고 보고서에 명시). 셀=카드(이름 18pt / `ProgressView(value: Double(percentageInteger) ?? 0, total: 100)` / 상태 15pt+우측 `"[\(Int(occupied) ?? 0)/\(count)]"` 12pt). 탭 → `WebViewScreen(EndPoint.librarySeatDetail(id:), "도서관 좌석")` push(로컬 NavigationView 필요 — 스캐폴드와의 조합은 GroupMainView처럼 NavigationView를 바깥에). `.refreshable`(스피너 억제 유지), `.toast`.
- [ ] **Step 4: 에셋 복사** — Android drawable에서 `yu_library_seat01`(png/jpg/webp — **webp면 iOS 미지원이라 png 변환**: `dwebp` 없으면 Python PIL, 그것도 없으면 파일 그대로 두되 보고서에 Mac 변환 필요 명시) → imageset. pbxproj는 Assets.xcassets가 이미 등록돼 있어 무수정.
- [ ] **Step 5: MainView 분기 + pbxproj(5파일) + 검증.**
- [ ] **Step 6: 커밋** — `feat: add library seat screen`

---

### Task 4: 시간표 — 컨테이너 + 학기시간표 탭

**Files:**
- Create: `YuMinigroup/Data/Remote/TimetableRemoteDataSource.swift`, `YuMinigroup/Data/TimetableRepository.swift`, `YuMinigroup/ViewModel/SemesterTimetableViewModel.swift`, `YuMinigroup/View/TimetableView.swift`
- Modify: `YuMinigroup/App/EndPoint.swift`(+`timetable`), `YuMinigroup/View/MainView.swift`, `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `HttpClient.request`(LMS 쿠키), `HtmlUtil.rows/blocks`
- Produces:

```swift
// EndPoint
static let timetable = baseURL + "/ilos/st/main/pop_academic_timetable_form.acl"
// TimetableRemoteDataSource + Repository 패스스루
func fetchSemesterTable(completion: @escaping (Resource<[[String]]>) -> Void)  // 첫 행=요일 헤더, 최대 26행×6열
// SemesterTimetableViewModel: State { table: [[String]] = []; isLoading; message }, init 즉시 조회, refresh()
// TimetableView: 드로어 루트(AppToolbar "시간표") + 상단 세그먼트 ["학기시간표","모의시간표 작성"] + 페이지 전환
//   — Task 5가 모의 탭을 채우기 전까지 모의 자리는 내부 placeholder Text("준비중입니다")
struct TimetableView: View { init(onMenuClick: @escaping () -> Void) }
```

- [ ] **Step 1: Android 정독** — `fragment/SemesterTimeTableFragment.java`(파싱·색·크기)·`helper/ui/SemesterTimetableView.java`(**이식 기준 모델** — 스펙 §2 결함 2)·`fragment/TimetableFragment.java`(탭 구성).
- [ ] **Step 2: 데이터층** — GET `EndPoint.timetable`, `Cookie` 헤더(파라미터 없음). 파싱: `.bbslist` 블록(세그먼트 슬라이싱) → `HtmlUtil.rows`로 `tr` 최대 **26개** → 각 행에서 직계 셀: `HtmlUtil.blocks(in:tag:)`가 private이므로 `HtmlUtil.cells(in:tag:"td")`+`cells(tag:"th")` 결합 또는 행 문자열에서 `<td|th>` 블록 정규식(1차 관례) — **최대 6열**, 텍스트 추출. `.bbslist` 없으면 `.error("시간표를 불러오지 못했습니다.")`.
- [ ] **Step 3: 학기 그리드 뷰**(TimetableView 내 private `SemesterTimetableGrid`) — `[[String]]`을 세로 스택: 행 0 셀 배경 `Color(red: 0.980, green: 0.957, blue: 0.753)`(#FAF4C0)·높이 `화면높이/20`, 이후 행 `Color(red: 0.945, green: 0.945, blue: 0.945)`(#F1F1F1)·높이 `화면높이/14`, 셀 폭 균등 6열(`frame(maxWidth: .infinity)`), 텍스트 10pt 중앙·셀 마진 1. 비지 않은 셀 탭 → `.alert`(셀 텍스트, "닫기"). 전체는 ScrollView(세로).
- [ ] **Step 4: 컨테이너** — AppToolbar 아래 세그먼트(Android TabLayout 대응 — `Picker(.segmented)` 또는 2차 SettingsView와 통일감 있는 커스텀 탭 바; **Android 스타일(colorPrimary 배경+흰 텍스트+accent 인디케이터)을 살린 커스텀 탭 바 권장**, GroupView 탭 킷은 CollapsingHeader 전용이라 재사용 불가) + 선택 인덱스로 학기/모의 전환. MainView `.timetable` 분기 교체.
- [ ] **Step 5: pbxproj(4파일) + 검증 + 커밋** — `feat: add timetable container and semester timetable tab`

---

### Task 5: 모의시간표 탭

**Files:**
- Create: `YuMinigroup/Dto/TimetableItem.swift`, `YuMinigroup/ViewModel/MockTimetableViewModel.swift`, `YuMinigroup/View/MockTimetableView.swift`
- Modify: `YuMinigroup/View/TimetableView.swift`(모의 자리 교체), `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 4의 TimetableView 컨테이너
- Produces:

```swift
struct TimetableItem: Codable, Identifiable, Hashable { var id: Int; var subject, classroom: String }
final class MockTimetableViewModel: ObservableObject {
    @Published private(set) var items: [Int: TimetableItem]   // key = id(0~49)
    func save(id: Int, subject: String, classroom: String)    // upsert + persist
    func delete(id: Int)                                      // remove + persist
    // 저장: UserDefaults 키 "mock_timetable_items", JSON 인코딩 [TimetableItem] — init에서 로드
}
struct MockTimetableView: View { init(viewModel: MockTimetableViewModel) }
```

- [ ] **Step 1: Android 정독** — `fragment/MockTimeTableFragment.java`(문구·그리드 상수)·`helper/ui/TimetableView.java`(**이식 기준** — id=교시index×5+(요일index−1))·`res/layout/timetable_input_dig.xml`. 원본 셀 클릭 버그(스펙 §2 결함 2)는 미러하지 않는다.
- [ ] **Step 2: VM** — 위 Interfaces. UserDefaults 로드 실패(디코딩 오류)는 빈 상태로 강등.
- [ ] **Step 3: 뷰** — 그리드: 헤더 행 `["시간","월","화","수","목","금"]`(#FAF4C0, 높이 화면/20) + 10행(`"1교시\n09:00"`…`"10교시\n18:00"` — 배열 verbatim, 교시 열·데이터 셀 `#EAEAEA`= `Color(red: 0.918, green: 0.918, blue: 0.918)`, 높이 화면/14), 데이터 셀 텍스트 = `subject + "\n" + classroom`(없으면 빈). 셀 탭:
  - 빈 셀 → 입력 다이얼로그 제목 **"시간표"**: "강 의 명  :"/"강 의 실  :" 라벨+TextField(hint "강의명을 입력하세요."/"강의실을 입력하세요.") + [저장|취소] → `save`.
  - 채운 셀 → 제목 **"TimeTable"**: 프리필 + [수정|삭제] (+취소) → `save`/`delete`.
  - iOS 15에서 `.alert`는 TextField를 못 담으므로 **2차 GroupInfoDialogView 관례의 커스텀 중앙 오버레이 다이얼로그**로 구현(MockTimetableView 내 private struct — 상태: `editingCellId: Int?`).
- [ ] **Step 4: TimetableView 연결 + pbxproj(3파일) + 검증** — placeholder 제거 확인, id 산식 grep.
- [ ] **Step 5: 커밋** — `feat: add mock timetable tab with local persistence`

---

### Task 6: 공지사항 정적 화면

**Files:**
- Create: `YuMinigroup/View/NoticeView.swift`
- Modify: `YuMinigroup/View/Tab4View.swift`(공지 스텁 교체 — 167행 부근 NavigationLink destination), `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `struct NoticeView: View` — push 자식(시스템 네비바, `.navigationTitle("공지사항")` inline)

- [ ] **Step 1: 작성** — 중앙 정렬: 상단 여백 후 제목 **"앱 공지사항"**(headline) + 30pt 아래 본문(Android `activity_notice.xml` 문구 verbatim, `\n` 포함):
  "내용 : 영남대 소모임앱을 이용해주셔서 감사합니다. \n 문의사항은 구글 플레이스토어에 게시되어있는 \n 개발자 연락처로 주세요. \n \n 기능 추가에 관한 문의를 주셔도 됩니다. \n 많은 이용부탁드립니다. 감사합니다."
  (스토어 문구는 Android 원문 유지 — 미러. multilineTextAlignment(.center), secondary 색은 쓰지 않고 기본색.)
- [ ] **Step 2: Tab4View 교체** — `PlaceholderView(title: "공지사항", ...)` → `NoticeView()`. 헤더 코멘트 현행화.
- [ ] **Step 3: pbxproj(1파일) + 검증** — Tab4View의 `PlaceholderView(` 0건.
- [ ] **Step 4: 커밋** — `feat: replace notice placeholder with static notice screen`

---

### Task 7: 그룹 설정 데이터층

**Files:**
- Modify: `YuMinigroup/App/EndPoint.swift`(+3상수), `YuMinigroup/Data/Remote/GroupRemoteDataSource.swift`, `YuMinigroup/Data/Remote/UserRemoteDataSource.swift`, `YuMinigroup/Data/GroupRepository.swift`, `YuMinigroup/Data/UserRepository.swift`

**Interfaces:**
- Consumes: `HtmlUtil.elementById/attributeExact/text`, 기존 `MemberItem`(uid/name/value/stuNum/dept/div/regDate), 2차 `groupImageUpdate` 업로드 플로우(`uploadGroupImage` — private이면 재사용 가능하게 내부 호출 경로 조정), `MultipartRequest`
- Produces:

```swift
// EndPoint
static let modifyGroup     = baseURL + "/ilos/community/share_group_modify.acl"
static let updateGroup     = baseURL + "/ilos/community/share_group_update.acl"
static let groupMemberList = baseURL + "/ilos/community/share_group_member_list.acl"

// GroupRemoteDataSource + GroupRepository 패스스루
// GET modify 파싱 → (name, description, joinType)
func fetchGroupSetting(groupId: String, completion: @escaping (Resource<(name: String, description: String, joinType: String)>) -> Void)
// POST update → (이미지 있으면 groupImageUpdate 302 플로우) → Firebase Groups/{key} 표적 갱신(name/description/joinType, 이미지 시 image)
// 성공값 = 갱신된 (name/description/joinType/imageURL?) — imageURL은 이미지 업로드 시에만
func updateGroup(groupId: String, key: String?, title: String, description: String, joinType: String, image: UIImage?,
                 completion: @escaping (Resource<(name: String, description: String, joinType: String, imageURL: String?)>) -> Void)

// UserRemoteDataSource + UserRepository 패스스루
func fetchManagedMembers(groupId: String, completion: @escaping (Resource<[MemberItem]>) -> Void)
```

- [ ] **Step 1: Android 정독** — `GroupRemoteDataSource.java` getGroup(:363-388)/setGroup(:439-490)/updateGroupDataToFirebase(:693-719), `UserRemoteDataSource.java`(:34 getManagedMemberList).
- [ ] **Step 2: fetchGroupSetting** — GET `EndPoint.modifyGroup + "?CLUB_GRP_ID=\(percent-encoded groupId)"`(쿠키, 1차 fetchMembers의 GET 관례). 파싱: `HtmlUtil.openTag(withId: "wrtGroup")`의 `value` 속성=이름 / `HtmlUtil.elementById("wrtExplain")`의 내부 콘텐츠(여는 태그 제거 후 `HtmlUtil.text`)=설명 / `class="radiobox"` 세그먼트 안 `class="chktype"` 여는 태그들 중 문자열에 `checked` 포함된 것의 `value`=joinType(기본 "0" — Android 미러). 필수(이름) 파싱 실패 → `.error("그룹 정보를 불러오지 못했습니다.")`.
- [ ] **Step 3: updateGroup** — POST `EndPoint.updateGroup`, formParams `["CLUB_GRP_ID": groupId, "GRP_NM": title, "TXT": description, "JOIN_DIV": joinType]` → JSON `isError`/`GRP_NM`(2차 CreateGroupResponse 관례의 유연 디코딩 재사용 또는 동형 struct). `isError` → `.error("소모임 변경에 실패했습니다.")`. 성공 후:
  1. `image != nil`이면 2차 그룹 생성의 이미지 업로드(파트명 `file`, UUID.jpg, PNG 바이트, **302/"응답이 비어있습니다." 성공 간주**)를 호출 — 기존 private 함수를 공용 private 헬퍼로 승격해 재사용(중복 금지). 성공/302 시 `imageURL = EndPoint.groupImage(file: "\(groupId).jpg")`, 그 외 실패는 `.error`.
  2. Firebase(스펙 §5.4, 결함 5 수정): `key`·root 있으면 `Groups/{key}`에 **표적 갱신** — `updateChildValues(["name": 응답 GRP_NM, "description": description, "joinType": joinType] + (imageURL 있으면 ["image": imageURL]))`(통째 setValue 금지 — members 등 보존). 실패해도 LMS 성공은 유지하되 메시지에 반영하지 않고 진행(기존 fire-and-forget 관례) — 단 **completion은 Firebase 호출과 무관하게 정확히 1회**.
  3. `completion(.success((응답 GRP_NM, description, joinType, imageURL)))`.
- [ ] **Step 4: fetchManagedMembers** — POST `EndPoint.groupMemberList`, body `CLUB_GRP_ID`. 파싱: `HtmlUtil.elementById("listZone")` → `tr` 블록들 → 각 행 `td` 블록: [0] 내부 첫 `<input>`의 `value`=학번, [1] 내부 첫 `<img>` `src`의 `id=`~`&ext`=uid(기존 `extractUid(fromImageSrc:)` 재사용), [2]=이름, [3]=학부/학과, [5]=회원 구분, [6]=가입 일시 → `MemberItem(uid:name:value: "", stuNum:dept:div:regDate:)`(value는 이 경로 미사용 — 빈 문자열). 행 실패 skip, listZone 없으면 `.error("회원 목록을 불러오지 못했습니다.")`.
- [ ] **Step 5: Repository 패스스루 + 검증** — 시그니처 grep, URL 3종 오탈자, `updateChildValues` 표적 갱신(통째 setValue 아님) 확인.
- [ ] **Step 6: 커밋** — `feat: add group settings data layer (modify/update/member list)`

---

### Task 8: 그룹 설정 화면 + Tab4/GroupView 배선

**Files:**
- Create: `YuMinigroup/View/SettingsView.swift`, `YuMinigroup/View/MemberManagementView.swift`, `YuMinigroup/View/DefaultSettingView.swift`, `YuMinigroup/ViewModel/MemberManagementViewModel.swift`, `YuMinigroup/ViewModel/DefaultSettingViewModel.swift`
- Modify: `YuMinigroup/View/Tab4View.swift`(설정 행 신설), `YuMinigroup/ViewModel/GroupViewModel.swift`(groupItem 갱신 지원), `YuMinigroup/View/GroupView.swift`(전파 배선), `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: Task 7 시그니처 전부, `CameraPicker`/`PhotoPicker`/`BitmapUtil.resized(_:maxSize:)`(200), `RemoteImage`, 2차 CreateGroupView(폼 관례의 준거)
- Produces:

```swift
// GroupViewModel 변경: let groupItem → @Published private(set) var groupItem + 
func applyGroupUpdate(name: String, description: String, joinType: String, imageURL: String?)  // 해당 필드만 교체
// SettingsView: 타이틀 "소모임 설정", 상단 탭 [회원관리|모임정보](Task 4 컨테이너와 동일 커스텀 탭 바 관례)
struct SettingsView: View {
    init(groupItem: GroupItem, onUpdated: @escaping (_ name: String, _ description: String, _ joinType: String, _ imageURL: String?) -> Void)
}
// MemberManagementViewModel: State { members/isLoading/message }, init 즉시 로드, refresh() 실제 재조회(스펙 §2 결함 3)
// DefaultSettingViewModel: title/descriptionText/isAutoJoin/image(UIImage?)/기존이미지URL, 로드(fetchGroupSetting 프리필),
//   updateGroup() — 검증 문구 "그룹이름을 입력하세요."/"그룹설명을 입력하세요.", 성공 시 updated 세팅(뷰가 onChange)
```

- [ ] **Step 1: Android 정독** — `activity/SettingsActivity.java`·`fragment/MemberManagementFragment.java`+`res/layout/fragment_member.xml`·`fragment/DefaultSettingFragment.java`+`fragment_default_setting.xml`·`res/menu/modify.xml`.
- [ ] **Step 2: 회원관리 탭** — 회색 배경(`Color(uiColor: .systemGroupedBackground)`) 위 카드: 고정 헤더 4열 **"프로필 | 학부/학과 | 회원 구분 | 가입 일시"**(균등 4열, 1px 구분선) + 행(65pt 원형 쿠키 프로필+이름 세로 / dept / div / regDate — 각 열 균등, 13pt). 읽기 전용. `.refreshable` → `viewModel.refresh()`(실재조회).
- [ ] **Step 3: 모임정보 탭** — CreateGroupView 폼 구성 미러(이름+클리어 / 이미지 275pt: 새 이미지 선택 전엔 기존 URL `RemoteImage`, 선택 후 `Image(uiImage:)`, 탭 → confirmationDialog 카메라/갤러리(1장, resized 200)/이미지 없음(새 선택 취소=기존 유지, 토스트 "이미지 없음 선택") / 설명 TextEditor / 하단 가입방식 라디오) + 툴바 우측 **"수정"** 버튼 + 로딩 오버레이 + 검증 캡션(2차 스테일 캡션 교훈 — updateGroup 진입 시 에러 클리어). 성공 시: 토스트 **"소모임 변경 완료"** → `onUpdated(...)` 호출 후 **1.2초 지연 dismiss**(2차 FindGroupView 토스트 생존 관례) — SettingsView 자신을 pop.
- [ ] **Step 4: SettingsView 컨테이너** — `.navigationTitle("소모임 설정")` inline + 상단 탭 2개(순서 [회원관리|모임정보] — Android verbatim) + 탭 전환. push 자식(시스템 네비바).
- [ ] **Step 5: Tab4View 설정 행** — "소모임 설정" 섹션의 groupSettingRow(탈퇴/폐쇄) **바로 아래**에 admin 전용 행 추가(Android content_tab4.xml 순서: ①ll_withdrawal ②ll_settings — 구현 전 원본 재확인): `if viewModel.groupItem.isAdmin { NavigationLink(destination: SettingsView(groupItem: viewModel.groupItem, onUpdated: onGroupUpdated)) { infoRow(title: "설정") } }`. Tab4View에 `let onGroupUpdated: (...) -> Void` 프로퍼티 추가.
- [ ] **Step 6: GroupViewModel/GroupView 전파** — GroupViewModel의 `groupItem`을 `@Published private(set) var`로 + `applyGroupUpdate`. GroupView가 Tab4View 생성 시 `onGroupUpdated: { viewModel.applyGroupUpdate(...) }` 전달(navigationTitle·헤더가 자동 갱신). Tab4ViewModel의 `groupItem`은 탈퇴 라벨용 초기값 그대로 둬도 무방(joinType 무관) — 헤더 코멘트에 근거 기록.
- [ ] **Step 7: pbxproj(5파일) + 검증** — 시그니처 짝, admin 조건, "수정"/"소모임 변경 완료" 문구, iOS16 0건.
- [ ] **Step 8: 커밋** — `feat: add group settings screen (member management + group info edit)`

---

### Task 9: 유튜브 검색 화면

**Files:**
- Create: `YuMinigroup/Dto/YouTubeItem.swift`, `YuMinigroup/Data/Remote/YouTubeRemoteDataSource.swift`, `YuMinigroup/Data/YouTubeRepository.swift`, `YuMinigroup/ViewModel/YoutubeSearchViewModel.swift`, `YuMinigroup/View/YouTubeSearchView.swift`
- Modify: `YuMinigroup/App/EndPoint.swift`, `YuMinigroup.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:

```swift
struct YouTubeItem: Codable, Identifiable, Hashable {
    var id: String { videoId }
    var videoId, publishedAt, title, thumbnail, channelTitle: String
    var position: Int = -1    // Android 미러(-1=신규 첨부)
}
// EndPoint
static let youtubeSearch = "https://www.googleapis.com/youtube/v3/search"
static let youtubeApiKey = "AIzaSyCHF6p97aduruLMxgCuEVfFaKUiGPcMuOQ"   // Android 하드코딩 미러, 2026-08-27 유효 확인
// YouTubeRemoteDataSource + Repository 패스스루
func searchVideos(query: String, completion: @escaping (Resource<[YouTubeItem]>) -> Void)
// GET ?part=snippet&key={KEY}&q={percent-encoded}&maxResults=50&type=video   ← type=video는 스펙 §2 결함 6
// 파싱: items[] → id.videoId / snippet.publishedAt·title·channelTitle / snippet.thumbnails.medium.url — 항목 실패 skip
// YoutubeSearchViewModel: State { items/isLoading/message } + @Published var query = ""
//   submitSearch() — query 빈/공백이면 미요청(Android의 진입 즉시 빈 쿼리 요청은 미러하지 않음, 스펙 §6.2)
struct YouTubeSearchView: View { init(onPicked: @escaping (YouTubeItem) -> Void) }  // 선택 시 onPicked 후 자체 dismiss
```

- [ ] **Step 1: Android 정독** — `activity/YouTubeSearchActivity.java`·`viewmodel/YoutubeSearchViewModel.java`·`res/layout/youtube_item.xml`·`res/menu/search.xml`.
- [ ] **Step 2: 데이터층** — HttpClient.request(GET, 헤더 없음) + JSONDecoder(중첩 struct Decodable — items[].id.videoId 없으면 항목 skip을 위해 `try?` 항목 디코딩). 에러 응답(`error.message` JSON)이면 `.error(그 메시지)` 강등.
- [ ] **Step 3: 뷰** — 모달 자기완결형(ProfileView 관례): 자체 NavigationView + 닫기(X) + 검색바(TextField hint **"검색어를 입력하세요."** + onSubmit/검색 버튼 → submitSearch) + 목록(160×90 썸네일 RemoteImage + 제목 16pt bold 4줄 + 채널 12pt 1줄). 행 탭 → `onPicked(item)` + dismiss. 로딩 스피너, `.toast`.
- [ ] **Step 4: pbxproj(5파일) + 검증** — `type=video`·인코딩 존재 grep, 문구 대조.
- [ ] **Step 5: 커밋** — `feat: add youtube search screen`

---

### Task 10: 유튜브 첨부 + 쓰기 경로

**Files:**
- Modify: `YuMinigroup/Dto/ArticleItem.swift`(+`youtubePosition: Int?`), `YuMinigroup/ViewModel/CreateArticleViewModel.swift`, `YuMinigroup/View/CreateArticleView.swift`, `YuMinigroup/Data/Remote/ArticleRemoteDataSource.swift`, `YuMinigroup/Data/ArticleRepository.swift`

**Interfaces:**
- Consumes: `YouTubeSearchView(onPicked:)`(Task 9), 기존 addArticle/setArticle/buildContentHtml/writeFirebaseArticle/updateFirebaseArticle
- Produces:

```swift
// ArticleItem: var youtubePosition: Int?   (기존 youtubeId와 짝 — 상세 삽입 위치, 목록은 미사용)
// CreateArticleViewModel.State: var youtubeItem: YouTubeItem?   // 1개 제한
func attachYoutube(_ item: YouTubeItem)   // 이미 있으면 state.message = "동영상은 하나만 첨부 할수 있습니다."
func removeYoutube()
// ArticleRepository/ArticleRemoteDataSource — 시그니처 확장(기존 호출부는 이 태스크에서 함께 갱신):
func addArticle(title: String, content: String, imageUrls: [String], youtube: YouTubeItem?, completion: ...)
func setArticle(articleId: String, key: String?, title: String, content: String, imageUrls: [String], youtube: YouTubeItem?, completion: ...)
```

- [ ] **Step 1: Android 정독** — `CreateArticleViewModel.java` uploadProcess(:255-256 embed 문자열 verbatim)·itemTypeCheck, `ArticleRemoteDataSource.java` insertArticleToFirebase(youtube 키)·updateArticleDataToFirebase(setYoutube 덮어쓰기), `ArticleActivity.java`(:96-110 수정 인텐트 vid).
- [ ] **Step 2: buildContentHtml 확장** — 시그니처 `(text:imageUrls:youtube: YouTubeItem?)`. 이미지 문단들 뒤에 youtube 있으면 **Android verbatim 조각**(스펙 §6.4 — 닫는 `<p>` 오타·`src="..."` 뒤 공백 2칸 포함):

```swift
if let youtube = youtube {
    paragraphs.append("<p><embed title=\"YouTube video player\" class=\"youtube-player\" autostart=\"true\" src=\"//www.youtube.com/embed/\(youtube.videoId)?autoplay=1\"  width=\"488\" height=\"274\"></embed><p>")
}
```

  (유튜브는 images 배열·업로드 대상 아님 — 기존 흐름 무변경.)
- [ ] **Step 3: Firebase 쓰기** — `writeFirebaseArticle` map에 `"youtube": ["position": youtube.position, "videoId": ..., "publishedAt": ..., "title": ..., "thumbnail": ..., "channelTitle": ...]`(youtube 있을 때만, Android Bean 미러). `updateFirebaseArticle`: 기존 dict 갱신 시 **`data["youtube"] = youtube 딕셔너리 또는 nil이면 `data.removeValue(forKey: "youtube")`** — 스펙 §2 결함 7 수정(주석에 근거). 반환 ArticleItem의 youtubeId/youtubePosition도 채움.
- [ ] **Step 4: VM/뷰** — State.youtubeItem + attach/remove. edit 모드 init: `article.youtubeId`가 있으면 `YouTubeItem(videoId: youtubeId, publishedAt: "", title: "", thumbnail: "https://i.ytimg.com/vi/\(youtubeId)/mqdefault.jpg", channelTitle: "", position: article.youtubePosition ?? 0)`으로 복원(항상 복원 — Android `position > -1` 조건 미러하지 않음, 스펙 §6.3). send() 검증(내용/이미지/유튜브 중 하나 필요 — 기존 guard에 `state.youtubeItem != nil` 추가), submit에 youtube 전달. CreateArticleView: 하단 첨부 버튼 옆 **"동영상"** 버튼(또는 confirmationDialog 항목 추가 — 기존 구조 따라 자연스러운 쪽, Android는 별도 컨텍스트 메뉴 항목) → `sheet`로 `YouTubeSearchView(onPicked: viewModel.attachYoutube)`. 첨부 프리뷰: 썸네일+`play.circle.fill` 오버레이+삭제 버튼(기존 이미지 썸네일 행 관례).
- [ ] **Step 5: 검증** — embed 문자열 바이트 대조(스펙 §6.4), addArticle/setArticle 전 호출부 컴파일 정합(grep), Firebase youtube 키 6필드.
- [ ] **Step 6: 커밋** — `feat: add youtube attachment to article write path`

---

### Task 11: 유튜브 렌더 — 목록 셀 + 상세 인앱 재생

**Files:**
- Modify: `YuMinigroup/Data/Remote/ArticleRemoteDataSource.swift`(상세 position 파싱), `YuMinigroup/View/Cell/ArticleListCell.swift`, `YuMinigroup/View/ArticleView.swift`

**Interfaces:**
- Consumes: `ArticleItem.youtubeId/youtubePosition`(Task 10), WKWebView(자체 소형 representable — WebViewScreen은 화면 단위라 재사용하지 않음)
- Produces: 목록 셀 유튜브 우선 규칙, 상세 인앱 embed 재생

- [ ] **Step 1: Android 정독** — `ArticleRemoteDataSource.java` youtubeExtract(:494-515 — `<p>` 순회하며 img면 position++, youtube-player면 position 기록), `article_item.xml`(:129-148 우선순위+video_mark), `BindingAdapters.java` bindImageList(:197-253 addView(container, position)).
- [ ] **Step 2: 상세 파싱** — parseArticleDetail의 기존 `<p>` 순회에 Android youtubeExtract 로직 추가: img 문단마다 카운터 증가, youtube-player 문단에서 `item.youtubePosition = 카운터`. 목록 파싱은 position 미기록(Android 미러 — 기본 nil).
- [ ] **Step 3: 목록 셀** — `if let youtubeId = article.youtubeId { 썸네일(i.ytimg mqdefault)+play 오버레이 } else if let firstImage = ... }` — 유튜브 우선(Android 규칙), 높이 160 유지.
- [ ] **Step 4: 상세 인앱 재생** — ArticleView의 youtubeThumbnail을 교체: `YoutubeEmbedView(videoId:)`(파일 내 private WKWebView representable — `https://www.youtube.com/embed/\(videoId)?playsinline=1` 로드, `allowsInlineMediaPlayback = true`, 16:9 `aspectRatio`). **삽입 위치**: images 스택을 만들 때 `youtubePosition`(nil이면 맨 끝) 인덱스에 embed를 끼워 넣는 통합 리스트로 재구성(이미지 인덱스와 PictureView startIndex 매핑이 어긋나지 않게 이미지 인덱스는 별도 유지). embed 아래 소형 "YouTube에서 열기" 폴백 버튼(기존 openYoutube 재사용).
- [ ] **Step 5: 검증** — 우선순위 분기 grep, position 삽입 로직, iOS16 0건.
- [ ] **Step 6: 커밋** — `feat: render youtube inline in article list and detail`

---

### Task 12: 기술 부채 3건

**Files:**
- Modify: `YuMinigroup/Data/Remote/GroupRemoteDataSource.swift`(1차 병합 폴백), `YuMinigroup/ViewModel/ChatViewModel.swift`(실패 시 관찰 보류), `YuMinigroup/Data/Remote/ChatRemoteDataSource.swift`(REST shallow), `docs/superpowers/plans/2026-08-26-mac-build-checklist.md`(패리티 갭 항목 갱신)

**Interfaces:**
- Consumes: 2차 `mergeFirebaseGroupKeys`의 LMS ID 폴백 선례(같은 파일), `FirebaseRef.database()?.url`(루트 ref의 데이터베이스 URL)
- Produces: 동작 변화 3건(공개 시그니처 무변경)

- [ ] **Step 1: 1차 병합 폴백** — `mergeFirebaseKeys`(가입 그룹)의 성공 경로(스냅샷 수신 후) 끝에 2차와 동일한 미매칭 `key = item.id` 폴백 추가(**resolveKeys 완료 콜백 내부** — remaining==0 지점. 미구성/withCancel 경로는 현행 유지). 주석: 비앱 그룹 채팅·게시글 Firebase 기록이 Android처럼 LMS ID 키로 동작(스펙 §7-1, 부수 효과 명시). Mac 체크리스트 5.3의 해당 패리티 갭 항목을 "3차에서 해소"로 갱신+검증 항목화.
- [ ] **Step 2: 채팅 실패 시 관찰 보류** — ChatViewModel의 초기 로드(`previousCount == 0`) 실패 분기에서 `isInitialLoadComplete = true`/`attachObserverIfNeeded()`를 호출하지 않도록 변경(성공 시에만). 실패 토스트는 기존 유지. 주석: afterKey nil 전체 재생 방지(스펙 §7-2).
- [ ] **Step 3: DM 목록 REST shallow** — `fetchDirectChatRooms`를 2단계로:

```swift
// ① 상대 uid 열거: REST shallow — SDK에 얕은 열거가 없어 URLSession 직접
let databaseURL = root.url   // DatabaseReference.url — 루트 ref면 DB URL 문자열
guard let url = URL(string: "\(databaseURL)/Messages/\(currentUid).json?shallow=true") else { fallbackFullRead(); return }
URLSession.shared.dataTask(with: url) { data, _, error in
    DispatchQueue.main.async {
        guard error == nil, let data = data,
              let keys = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            fallbackFullRead()   // 규칙 거부·비JSON 등 — 현행 전체 조회로 강등(기능 무손실)
            return
        }
        // ② 각 상대별 SDK 조회: Messages/{uid}/{상대}.queryOrderedByKey().queryLimited(toLast: 10)
        //    → 마지막 메시지 preview/timestamp + 역순 from != uid 첫 name(기존 로직 그대로 10건 범위)
    }
}.resume()
```

  기존 전체 조회 구현은 `fallbackFullRead`(private)로 이름만 바꿔 보존. fan-in은 remaining 카운터 관례. `root.url`이 루트 DatabaseReference의 DB URL 문자열임을 주석으로(Firebase iOS SDK `DatabaseReference.url`).
- [ ] **Step 4: 검증** — 폴백 3건 grep, ChatViewModel 실패 분기 diff 확인, REST 경로 문자열.
- [ ] **Step 5: 커밋** — `fix: resolve deferred chat and group parity debts`

---

### Task 13: Mac 체크리스트 3차 섹션 + 최종 정합 스윕

**Files:**
- Modify: `docs/superpowers/plans/2026-08-26-mac-build-checklist.md`

- [ ] **Step 1: "3차 (second 브랜치)" 섹션 추가** — 항목: 신규 파서 4종 실마크업(board-table/bbslist/listZone/modify 폼) · WKWebView 화면 4종(영대소식 상세/좌석 상세/버스/유튜브 embed 재생) · 시간표 2탭(학기 실데이터 26×6 편차·모의 저장/수정/삭제 왕복) · 좌석 JSON 실응답 · 그룹설정(로드 프리필→수정 저장→GroupView 타이틀 갱신→이미지 업로드 302) · 유튜브 왕복(검색→첨부→작성→목록 썸네일→상세 인앱 재생→수정 복원→제거 시 Firebase youtube 소거) · 기술부채 회귀(비앱 그룹 채팅 활성·채팅 초기 실패 후 재진입·DM REST shallow 실동작/폴백) · 에셋(yu_library_seat01 렌더).
- [ ] **Step 2: 최종 스윕** — ① `grep -rn "PlaceholderView(" YuMinigroup/View/ | grep -v "struct PlaceholderView"` **0건**(전 스텁 해소 — PlaceholderView.swift 자체는 잔존 가능, 참조만 0) ② pbxproj: 3차 신규 파일 전수(약 29개) × 4곳, ID 186부터 연번·중복 없음 ③ iOS16 API grep 0건 ④ 3차 변경/생성 파일 전수 CRLF 0(`git diff fe945d1..HEAD --name-only` 기준) ⑤ 신규 공개 시그니처를 각 태스크 Interfaces와 대조 ⑥ EndPoint에 스펙 §의 URL 전수 존재.
- [ ] **Step 3: 커밋** — `docs: add phase 3 items to mac build checklist`

---

## 태스크 밖(사용자 몫)

- Mac 빌드·실기기 검증(체크리스트 1~3차), `GoogleService-Info.plist` 확보, `second` 병합·push.
- 유튜브 API 키는 Android 하드코딩 미러(유효 확인됨) — 쿼터 소진 시 새 키 발급은 사용자 판단.
