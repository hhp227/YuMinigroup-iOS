# YuMinigroup-iOS 3차: 대학유틸·그룹설정·유튜브·기술부채 설계

- 날짜: 2026-08-27
- 브랜치: `second` 이어서(2차 fe945d1 위에 커밋 — 사용자 확정)
- 전제: 1·2차 완료. **의도 미러 + 개선 확대** 정책 유지(2차 §2와 동일). 본 3차로 Android 미러가 완결된다.

## 1. 범위

### 포함
1. **공통 인프라**: WebViewScreen(WKWebView) 재사용 컴포넌트
2. **대학유틸 4종**: 영대소식 · 시간표(학기+모의) · 도서관 좌석 · 셔틀버스 — 드로어 스텁 전부 해소
3. **공지사항**: Tab4 스텁 → 정적 화면
4. **그룹 설정**(admin 전용): Tab4 "설정" 행 신설 → 2탭(회원관리·모임정보) + **이미지 실제 업로드(개선, 합의됨)**
5. **유튜브**: 검색(글쓰기 첨부)·쓰기 경로·목록/상세 렌더·**인앱 재생 WKWebView embed(합의됨)**·수정 정합성 수정
6. **기술 부채 3건**(2차 최종 리뷰 이연): 1차 병합 LMS ID 폴백 · 채팅 초기 실패 시 관찰 보류 · DM 목록 조회 최적화

### 제외 (영구 또는 스코프 밖)
- AdMob·FCM(기존 확정 제외), LMS 쪽지 SEND_MESSAGE(dead code)
- 회원 승인/추방 — **Android 앱에도 없음**(LMS 웹 전용). 회원관리는 읽기 전용
- VerInfo 전체 화면 승격 — 현행 Tab4 인라인 버전 표시 유지(YAGNI)

## 2. Android 결함 처리 (의도 미러 정책 적용 목록)

| # | Android 동작 | iOS 처리 |
|---|---|---|
| 1 | 영대소식 offset 초기 1 / refresh 후 0 (계열 불일치) | **0 기준 통일**(0,10,…,90 — MAX 100건) |
| 2 | 모의시간표 셀 클릭 판정이 루트 뷰 id 비교로 깨져 있음 + 커서/셀 동기화 오류 | 예비 코드(TimetableView) 모델로 재구현: id(0~49)→아이템 딕셔너리 |
| 3 | 회원관리 onRefresh가 Toast만 띄우고 재조회 안 함 | 실제 refresh 호출 |
| 4 | 모임정보 이미지: 프리뷰만 되고 서버 미반영(미완성) | **groupImageUpdate 재사용해 실제 업로드+Firebase image 갱신**(개선, 합의) |
| 5 | 모임정보 Firebase 갱신 실패 시 onFailure 미호출(무한 로딩 위험) | 실패도 completion 전달 |
| 6 | 유튜브 검색 q 미인코딩 + type 미지정(채널 혼입 시 파싱 예외) | percent-encoding + `type=video` 추가 |
| 7 | iOS 1차 잔존: 유튜브 글 수정 시 LMS에선 영상 소실인데 Firebase stale youtube 잔존 | 수정 시 youtube 덮어쓰기(제거 시 Firebase에서도 제거) |

wire 계약(URL·파라미터·HTML 셀렉터·embed 태그 형식)은 Android와 바이트 수준 동일 유지.

## 3. 공통 인프라 — WebViewScreen

```swift
struct WebViewScreen: View {
    // push 모드: 시스템 네비바(title), 드로어 루트 모드: AppToolbar(title, .menu, onMenuClick)
    init(urlString: String, title: String, onMenuClick: (() -> Void)? = nil)
}
```
- WKWebView UIViewRepresentable + 로딩 ProgressView 오버레이(didFinish/didFail에서 해제). JS 기본 활성. 줌·wide viewport는 WKWebView 기본.
- `onMenuClick == nil` → push된 자식(시스템 네비바 `.navigationTitle(title)` inline), 아니면 드로어 루트(AppToolbar+햄버거, navigationBarHiddenCompat 하의 로컬 구조 — GroupMainView 관례).
- 사용처: 영대소식 상세(push) · 좌석 상세(push) · 셔틀버스(루트).

## 4. 대학유틸 + 공지

### 4.1 영대소식 (UnivNoticeView + UnivNoticeViewModel + BbsItem)

- **BbsItem**(신설 Dto): `id, title, writer, date` (String).
- 목록: 공개 **GET** `https://www.yu.ac.kr/main/intro/yu-news.do?mode=list&articleLimit=10&article.offset={offset}` — 쿠키·헤더 불필요.
- 파싱: `.board-table` → `tbody` → `tr` 순회 → 직계 `td`들: td[1]=제목(+첫 `<a>` href를 `=`/`&`로 split한 [3]=id), td[2]=작성자, td[3]=날짜. td[0] 미사용. 행 단위 실패는 skip.
- 페이징: offset 0부터 +10, **최대 100건**(offset<100), 최하단 도달 시 다음 페이지(마지막 셀 onAppear 관례), 첫 로딩만 중앙 스피너(`isLoading && !hasRequestMore`). pull-to-refresh → 전체 리셋.
- 셀: 카드(제목 17pt singleLine / 아래 날짜 15pt + 우측 작성자 10pt).
- 탭 → WebViewScreen(`...yu-news.do?mode=view&articleNo={id}`, title "영대소식") push — 드로어 루트이므로 로컬 NavigationView 필요(ChatListView 관례).
- 데이터층: UnivNoticeRemoteDataSource+Repository 신설(1차 계층 관례 — Android는 VM이 직접 호출하나 iOS는 계층 유지, 2차 관례).

### 4.2 시간표 (TimetableView — 상단 탭 2개 "학기시간표" / "모의시간표 작성")

드로어 루트, AppToolbar(title "시간표") 아래 세그먼트/탭 바 + 페이지 전환. **Android 프래그먼트 원본은 결함 2 — 예비 코드(helper/ui/TimetableView·SemesterTimetableView)를 정답 모델로 이식.**

**학기시간표**:
- **GET** `http://lms.yu.ac.kr/ilos/st/main/pop_academic_timetable_form.acl` — **LMS 쿠키 필수**, 파라미터 없음.
- 파싱: `.bbslist`의 `tr` 최대 **26행**, 각 행 직계 자식 최대 **6열**, 셀 텍스트 추출 → `[[String]]`(첫 행=요일 헤더).
- 렌더: 6열 그리드 — 헤더 행 배경 `#FAF4C0`, 데이터 셀 `#F1F1F1`, 텍스트 10pt 중앙, 헤더 행 높이=화면/20·데이터 행=화면/14, 셀 폭=화면/6. 비지 않은 셀 탭 → 셀 전체 텍스트 Alert("닫기").
- 영속성 없음(매번 조회). 로딩 스피너, 실패 시 토스트(Android는 무피드백 — 관례상 토스트 추가).

**모의시간표**:
- 로컬 전용. 그리드: 요일 헤더 `["시간","월","화","수","목","금"]`(#FAF4C0) + 교시 10행(`"1교시\n09:00"`…`"10교시\n18:00"`, 교시 열 #EAEAEA) — 데이터 셀 50개(#EAEAEA), **id = 교시index×5+(요일index−1), 0~49 유지**.
- **TimetableItem**(신설 Dto): `id: Int, subject: String, classroom: String` — **UserDefaults에 JSON `[TimetableItem]` 저장**(SQLite 대체, PreferenceManager 관례의 별도 키). 셀 텍스트 = `subject + "\n" + classroom`.
- 빈 셀 탭 → 다이얼로그 제목 "시간표": "강의명을 입력하세요."/"강의실을 입력하세요." 입력 + [저장|취소]. 채운 셀 탭 → 제목 "TimeTable": 프리필 + [수정|삭제]. (iOS 15: `alert`에 TextField 2개 — UIAlertController representable 또는 커스텀 오버레이 다이얼로그, GroupInfoDialog 관례 재사용 가능.)

### 4.3 도서관 좌석 (SeatView + SeatViewModel + SeatItem)

- **SeatItem**(신설 Dto): `id, name, count, occupied, percentageInteger, status` — 전부 String(**유연 디코딩**: 숫자로 와도 String화).
- 공개 **GET** `https://slib.yu.ac.kr/Clicker/GetClickerReadingRooms` → JSON 루트 배열 키 **`_Model_lg_clicker_reading_room_brief_list`**, 필드 `l_id/l_room_name/l_count/l_occupied/l_percentage_integer/l_open_mode`.
- 화면: CollapsingListScaffold(showTabs: **false** — 킷이 탭 없는 모드를 지원함을 확인(collapsedHeight·HeaderView 분기 존재), imageHeight **240**, 헤더=도서관 이미지 — Android `yu_library_seat01` drawable을 iOS 에셋으로 복사+하단 그라디언트). 타이틀 "도서관 좌석".
- 셀: 카드 — 방 이름 18pt / 가로 ProgressView(value: percentage/100) / 상태 15pt + 우측 `"[\(occupied 정수화)/\(count)]"` 12pt(occupied만 파싱, count는 원문 — Android 미러).
- 페이징 없음. refresh 시 중앙 스피너 억제(Android 미러). 탭 → WebViewScreen(`https://slib.yu.ac.kr/clicker/UserSeat/{id}`, "도서관 좌석").

### 4.4 셔틀버스

- WebViewScreen(urlString: `https://hcms.yu.ac.kr/main/life/information-on-the-school-bus.do`, title "순환버스 시간표", onMenuClick: 드로어)을 MainContentRouter `.shuttleBus`에 직접 렌더. VM 없음.

### 4.5 공지사항 (NoticeView)

- 네트워크 없음. 중앙 정렬 정적 텍스트: 제목 **"앱 공지사항"** + 본문(Android 문구 그대로: "내용 : 영남대 소모임앱을 이용해주셔서 감사합니다. …"). Tab4의 PlaceholderView 교체(push, 시스템 네비바).

## 5. 그룹 설정 (admin 전용)

### 5.1 진입
- Tab4View에 **"소모임 설정" 섹션의 "설정" 행 신설 — `viewModel.isAdmin`일 때만 표시**(기존 탈퇴/폐쇄 행과 같은 섹션). 탭 → SettingsView push(groupId·groupImage·firebaseKey 전달).

### 5.2 SettingsView — 타이틀 "소모임 설정", 상단 탭 2개 [회원관리 | 모임정보]

### 5.3 회원관리 (MemberManagementView + VM)
- **POST** `share_group_member_list.acl`, body `CLUB_GRP_ID={groupId}` — LMS 쿠키.
- 파싱: `#listZone` 직계 자식(tr)들 → 각 행의 `td`: td[0] 내부 input의 `value`=학번, td[1] 내부 img `src`의 `id=`~`&ext`=uid, td[2]=이름, td[3]=학부/학과, td[4] 미사용, td[5]=회원 구분, td[6]=가입 일시 → 기존 `MemberItem`(uid,name,value:nil,stuNum,dept,div,regDate — 1차 Dto 필드로 충분).
- 화면: 회색 배경 카드 — 고정 헤더 행 4열 **"프로필 | 학부/학과 | 회원 구분 | 가입 일시"**(1px 구분선) + 목록 행(프로필 65pt 원형 쿠키 이미지+이름 / dept / div / regDate). 읽기 전용(액션 없음). refresh 실제 재조회(결함 3 수정).

### 5.4 모임정보 (DefaultSettingView + VM)
- **초기 로드**: **GET** `share_group_modify.acl?CLUB_GRP_ID={groupId}` — 쿠키. 파싱: `#wrtGroup`의 `value`=이름, `#wrtExplain`의 innerHTML=설명, `.radiobox` 안 `.chktype` 중 `checked` 포함 요소의 `value`=joinType("0"/"1"). 프리필.
- 폼: CreateGroupView와 동일 구성(이름+클리어 / 이미지 275pt — 기존 이미지 URL 표시(쿠키), 탭 시 카메라/갤러리(200px 리사이즈)/이미지 없음 / 설명 / 하단 가입방식 라디오) + 툴바 **"수정"** + 검증 문구 "그룹이름을 입력하세요."/"그룹설명을 입력하세요." + 로딩 오버레이.
- **저장**: **POST** `share_group_update.acl`, body `CLUB_GRP_ID/GRP_NM/TXT/JOIN_DIV` → JSON `isError`/`GRP_NM`. 성공 시:
  1. **(개선, 합의) 이미지가 새로 선택돼 있으면** 2차 `groupImageUpdate` 플로우 재사용(multipart `file`=UUID.jpg PNG 바이트, 302/빈 본문 성공 간주) 후 Firebase image도 `groupImage("{groupId}.jpg")`로 갱신. "이미지 없음" 선택 시 업로드 생략(이미지 필드 유지 — 서버 삭제 API 없음).
  2. Firebase `Groups/{key}`: name/description/joinType(+이미지 변경 시 image)만 표적 갱신(members 등 보존, `FirebaseRef` nil이면 생략, 실패도 completion 전달 — 결함 5 수정).
  3. 토스트 "소모임 변경 완료" → pop, 변경된 GroupItem을 콜백으로 Tab4→GroupView에 전파(타이틀·상태 갱신).

## 6. 유튜브 검색/재생

### 6.1 YouTubeItem Dto (신설, 검색·첨부용)
`videoId, publishedAt, title, thumbnail, channelTitle: String` + `position: Int`(기본 -1=신규 첨부).

### 6.2 검색 (YouTubeSearchView + YoutubeSearchViewModel)
- **GET** `https://www.googleapis.com/youtube/v3/search?part=snippet&key={API_KEY}&q={인코딩된 쿼리}&maxResults=50&type=video` — API_KEY는 Android 하드코딩 값 그대로(**유효 확인됨 2026-08-27**). `type=video`는 결함 6 수정.
- 파싱: `items[]` → `id.videoId`, `snippet.publishedAt/title/channelTitle`, `snippet.thumbnails.medium.url`. 항목 단위 실패 skip.
- 화면: CreateArticleView에서 sheet/fullScreenCover — 검색바(hint "검색어를 입력하세요.", 제출 시 조회. Android의 진입 즉시 빈 쿼리 요청은 미러하지 않음 — 빈 쿼리면 미요청) + 목록(160×90 썸네일+제목 16pt bold 4줄+채널 12pt). 탭 → 선택 반환+닫기.

### 6.3 첨부 (CreateArticleView/VM 확장)
- 첨부 메뉴에 **"동영상"** 항목 추가. 이미 있으면 토스트 **"동영상은 하나만 첨부 할수 있습니다."**(1개 제한).
- 선택된 유튜브는 콘텐츠 리스트에 추가(신규는 맨 뒤), 프리뷰=썸네일+재생 마크 오버레이. 제거 가능.
- 수정 진입 시 기존 유튜브를 `position+1` 위치에 복원(0=본문 헤더). Android의 `position > -1` 조건은 미러하지 않음(항상 복원).

### 6.4 쓰기 경로 (ArticleRemoteDataSource 확장)
- buildContentHtml에 유튜브 조각 추가 — **Android verbatim**(닫는 `<p>` 오타·공백 2칸까지 그대로, 서버가 소비하는 형식):
  `<p><embed title="YouTube video player" class="youtube-player" autostart="true" src="//www.youtube.com/embed/{videoId}?autoplay=1"  width="488" height="274"></embed><p>`
  (+마지막 항목 아니면 `<br>`). 유튜브는 이미지 업로드 700ms 텀 대상 아님·images 배열 미포함.
- Firebase article map에 **`youtube` 키** 추가(YouTubeItem 필드 직렬화: position/videoId/publishedAt/title/thumbnail/channelTitle — Android Bean 미러). **수정 시 setValue 전에 youtube를 현재 첨부로 덮어쓰기(nil이면 제거)** — 결함 7 수정.

### 6.5 렌더
- **목록 셀**: 유튜브 있으면 썸네일(`https://i.ytimg.com/vi/{id}/mqdefault.jpg`)이 첫 이미지보다 **우선** + 재생 마크 오버레이(SF Symbol play.circle.fill 계열).
- **상세**: 파서가 `<p>` 순회로 **position**(앞선 이미지 개수)을 추출 → `ArticleItem.youtubePosition: Int?` 추가 → 이미지 스택의 해당 인덱스에 **인앱 재생 WKWebView**(`https://www.youtube.com/embed/{id}?playsinline=1`, 16:9 비율) 삽입(합의된 개선 — Android YouTubePlayerView 대체). 로드 실패 대비 탭 시 외부 열기(`youtube.com/watch?v=`) 폴백 버튼 유지.

## 7. 기술 부채 3건 (2차 최종 리뷰 이연)

1. **1차 가입그룹 병합 LMS ID 폴백**: `mergeFirebaseKeys`/`resolveKeys`(가입 그룹 목록)에도 2차 그룹찾기와 동일한 "미매칭 시 key = LMS ID" 폴백 적용 → 비앱 그룹의 그룹채팅 진입 활성화. **부수 효과 인지**: 게시글 Firebase 이중기록·Tab1 병합이 `Articles/{lmsId}` 키로 활성화됨(Android와 동일해짐). Mac 체크리스트의 해당 패리티 갭 항목을 "해소됨"으로 갱신.
2. **채팅 초기 로드 실패 시 관찰 보류**: ChatViewModel — 초기 fetch `.failure`면 `isInitialLoadComplete`를 세우지 않고 옵저버 부착 보류(전체 이력 재생 방지) + 실패 토스트. 재진입 시 재시도(신규 VM).
3. **DM 목록 조회 최적화**: RTDB iOS SDK는 자식 키만 얕게 열거할 수 없으므로(shallow는 REST 전용), 1:1 경로를 2단계로 재설계 — ①상대 uid 열거: **REST shallow GET** `{Database.database().reference().url}/Messages/{uid}.json?shallow=true`(HttpClient 아닌 URLSession 직접, 응답=키 딕셔너리. Android 앱이 무인증 SDK 접근을 쓰므로 REST 무인증도 동일 권한 표면) ②각 상대별 SDK `Messages/{uid}/{상대}.queryOrderedByKey().queryLimited(toLast: 10)` 개별 조회로 마지막 메시지·이름 탐색(2차 §3.6 원안 복원). **REST 실패(규칙 거부·URL 불가 등) 시 현행 전체 조회로 폴백**(기능 저하 없이 최적화만 포기, 주석 명시). Mac 체크리스트에 REST shallow 실동작 확인 항목 추가.

## 8. 에러·엣지

- 공개 엔드포인트(영대소식·좌석·유튜브·버스)는 쿠키 불필요 — HttpClient 쿠키 헤더 없이 호출(또는 빈 쿠키 무해). 학기시간표·그룹설정은 LMS 쿠키 필수(1차 CookieStore).
- Firebase 미구성: 그룹설정 저장은 LMS만 반영(기존 관례), 유튜브 Firebase 기록 생략(기존 게시글 관례).
- 파싱 실패는 항목 skip·`.error` 강등(전 파서 공통, 크래시 금지).
- 유튜브 API 실패(쿼터 등): 토스트로 메시지 표시, 검색 화면 유지.

## 9. 검증·커밋

- WSL 정적 검증 + **Mac 체크리스트에 3차 섹션 추가**: 신규 파서 4종(board-table/bbslist/listZone/modify 폼) 실마크업, WKWebView 화면 4종, 유튜브 embed 재생·첨부 왕복(작성→목록 썸네일→상세 재생→수정 복원→제거), 그룹설정 저장+이미지 업로드, 기술부채 3건 회귀(비앱 그룹 채팅 활성 확인 포함).
- pbxproj 신규 파일 수동 등록(ID 186부터). 새 파일 LF.
- 커밋: `second`에 태스크별, 트레일러 금지, push 금지(2차와 동일).

## 10. 최고 위험

1. 신규 HTML/JSON 파서 4종 — 실마크업 미검증(전 차수 공통 최고 위험)
2. WKWebView(유튜브 embed 포함) — WSL에서 실렌더 검증 불가
3. 학기시간표 26×6 그리드의 실데이터 행/열 편차(빈 시간표·병합 셀 등)
4. 유튜브 embed 태그 verbatim이 LMS 웹 렌더와 호환되는지(Android가 검증한 형식 그대로라 리스크 낮음)
