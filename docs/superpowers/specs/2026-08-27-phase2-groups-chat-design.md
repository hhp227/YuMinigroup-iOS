# YuMinigroup-iOS 2차: 그룹 라이프사이클 + 채팅 설계

- 날짜: 2026-08-27
- 브랜치: `second` (develop `f0d1b56`에서 분기, 사용자 생성)
- 전제: 1차(코어 15화면) 완료. 본 문서는 YuMiniGroup-Android를 기준으로 한 **의도 미러 + 개선 확대** 설계다.
  화면·UX는 Android를 따르되 명백한 구현 결함은 의도 기준으로 수정하고, 합의된 개선 4종을 추가한다.

## 1. 범위

### 포함
1. **그룹찾기** (FindGroupView) — 미가입 그룹 목록 + 가입신청
2. **가입신청중 그룹** (RequestView) — 승인 대기 그룹 목록 + 신청취소
3. **그룹 만들기** (CreateGroupView) — 폼 + 이미지 업로드 + Firebase 기록
4. **채팅** (ChatView) — 그룹채팅 + 1:1, Firebase RTDB
5. **개선 4종** (Android에 없음, 합의됨)
   - 채팅방 목록 화면(ChatListView) — 드로어 "채팅" 메뉴 신설
   - 낙관적 전송 정합 — push key 기반 중복 제거
   - Firebase 쓰기 트랜잭션 — Groups members/memberCount 갱신 경합 방지
   - 빈 상태 UI — 찾기/신청중 목록 빈 상태 문구 표시

### 제외 (3차 이연)
- 그룹정보 수정(MODIFY_GROUP/UPDATE_GROUP)·그룹 이미지 변경·멤버 관리(GROUP_MEMBER_LIST)
- Tab4 공지사항 스텁 해소
- 대학유틸: 영대소식·시간표·도서관 좌석·셔틀버스·유튜브
- LMS 쪽지(SEND_MESSAGE=`club_send_msg_insert.acl`) — **Android에서도 dead code**(커밋 50ebd90에서 제거됨). 이식하지 않는다.
- AdMob·FCM (기존 확정대로 제외)

## 2. Android 결함 처리 정책 (합의됨)

| # | Android 동작 | iOS 처리 |
|---|---|---|
| 1 | 가입신청중 목록이 실제 필터링 없이 LMS 전체 그룹을 노출(키만 교체) | `UserGroupList/{uid}`에서 value==false 인 키 목록으로 **실제 교차 필터링** |
| 2 | 채팅이 1회 조회(addListenerForSingleValueEvent)라 실시간 수신 없음 | 초기 로드 후 **childAdded 관찰** 추가 |
| 3 | refresh 시 `stopRequestMore` 미리셋(페이징 영구 정지 결함) | refresh에서 minId와 함께 리셋 |
| 4 | 이미 멤버면 members map을 새로 비우는 버그(GroupInfoViewModel) | 트랜잭션 내 정상 upsert |
| 5 | body를 URL 인코딩 없이 전송(그룹 목록/생성 등) | 정상 percent-encoding 사용(서버는 표준 form 파서) |
| 6 | Firebase에 없는 그룹 가입 시 NPE성 동작 | 다이얼로그 인자로 최소 GroupItem 노드 생성 후 기록 |
| 7 | 신청중 화면 shimmer 미표시(onLoading 미호출) | 최초 로드 시 스켈레톤 정상 표시 |

그 외 wire 계약(엔드포인트·파라미터·Firebase 스키마·값 의미)은 Android와 **바이트 수준 동일**하게 유지한다.

## 3. 데이터층

### 3.1 EndPoint 추가

```swift
static let createGroup      = baseURL + "/ilos/community/share_group_insert.acl"
static let registerGroup    = baseURL + "/ilos/community/share_group_register.acl"
static let groupImageUpdate = baseURL + "/ilos/community/share_group_image_update.acl"
static let noPhotoImage     = baseURL + "/ilos/images/community/share_nophoto.gif"
```
신청취소는 기존 `withdrawalGroup`(share_auth_drop_me.acl) 재사용. 모든 요청은 1차 HttpClient(쿠키 헤더) 경유.

### 3.2 그룹 목록 조회 (GroupRemoteDataSource 확장)

`getNotJoinedGroupList(offset:limit:)` / `getJoinRequestGroupList(offset:limit:)` 공통:
- **POST** `share_group_list.acl`, form-urlencoded
- 파라미터: `panel_id=1`, `gubun=select_share_total`, `start=<offset(1부터)>`, `display=<limit>`, `encoding=utf-8`
- limit: 찾기=15, 신청중=100 (Android와 동일)

**HTML 파싱** (HtmlUtil로 Jericho 로직 재현):
- `id="accordion"` && `class="accordion"` 요소 순회
- 그룹 ID: `.menu_list .button`의 `onclick`을 `( ) ,`로 split한 [1] (찾기) / `href.split("'")[1]` (신청중 — Android 오버로드 차이 유지)
- 이미지: 첫 `img`의 `src` 앞에 baseURL, 이름: 첫 `strong` 텍스트
- description: `.menu_list .info`[0] content, joinType: `.info`[1] 텍스트 trim — `"가입방식: 자동 승인"` 정확 일치 → `"0"`, 아니면 `"1"`
- info: `a` 하위 `.info` span 순회, "회원수" 포함 시 `substring(0, lastIndexOf("생성일")).trim()+"\n"`, 아니면 text+"\n"

**페이지 종료 휴리스틱** (Android 이식 + 결함 3 수정):
- `minId = (minId==0) ? id : min(minId, id)`, 순회 중 `id > minId`면 `stopRequestMore=true` 후 중단
- refresh 시 `minId=0` **및 `stopRequestMore=false`** 리셋

**Firebase 병합**:
- 찾기: `Groups`를 `orderByKey` 1회 조회 → `GroupItem.id`가 일치하는 항목의 엔트리 key를 LMS ID → **Firebase push key로 교체** (없으면 LMS ID 유지)
- 신청중: `UserGroupList/{내uid}`를 `orderByValue().equalTo(false)`로 조회 → 대기중 키 집합 → 각 `Groups/{key}` 조회 → **LMS 목록과 교차하는 항목만 결과에 남긴다** (결함 1 수정)

### 3.3 가입신청/신청취소 (GroupInfo)

- **POST** `registerGroup`(신청) / `withdrawalGroup`(취소), body `CLUB_GRP_ID=<LMS 그룹ID>` 1개
- 응답 JSON `isError == false`면 성공
- **Firebase 갱신** (성공 시, `FirebaseRef.database()` nil이면 생략):
  - 신청: `Groups/{key}`를 **runTransactionBlock**으로 `members[내uid] = (joinType=="0")`, `memberCount=members.count` 갱신 + `UserGroupList/{내uid}/{key} = (joinType=="0")`
    - `"0"`(자동 승인) → **true = 즉시 정식 가입**, `"1"`(운영자 승인) → **false = 승인 대기**
  - 취소: 트랜잭션으로 `members`에서 내 uid 제거·count 갱신 + `UserGroupList/{내uid}/{key}` removeValue
  - `Groups/{key}` 노드가 없으면(비앱 생성 그룹) 다이얼로그 인자(id·name·image·desc·joinType)로 최소 GroupItem을 만들어 기록 (결함 6 수정)

### 3.4 그룹 생성 (addGroup — 3단계)

1. **POST** `createGroup`: `GRP_NM=<이름>`, `TXT=<설명>`, `JOIN_DIV=<"0"|"1">` → 응답 JSON `isError`/`CLUB_GRP_ID`(trim)/`GRP_NM`
2. 이미지 선택 시 **POST multipart** `groupImageUpdate`: 텍스트 파트 `CLUB_GRP_ID`, 파일 파트 이름 **`file`**, 파일명 `<UUID(하이픈 제거)>.jpg`, 바이트는 **PNG 인코딩**(Android 검증된 방식 그대로 — 확장자와 불일치하지만 서버 동작 확인됨). 1차 MultipartRequest 재사용.
   - **HTTP 302 응답은 성공으로 간주**(서버 특성). URLSession 리다이렉트 자동 추적을 이 요청에서 차단하고 302를 성공 처리.
3. **Firebase 원자 기록**: 루트 push key 생성 →
   - `Groups/{pushKey}` = GroupItem(id=CLUB_GRP_ID, timestamp=현재 epoch millis, author/authorUid=나, name=응답 GRP_NM, description, joinType, members={내uid: true}, memberCount=1, image=이미지 있으면 `groupImage("<groupId>.jpg")` 없으면 `noPhotoImage`)
   - `UserGroupList/{내uid}/{pushKey}` = true
   - 두 경로를 `updateChildren` 하나로 원자 기록
   - Groups 노드 필드명은 Android Bean 직렬화와 동일하게(**`admin`**, memberCount, timestamp, id, author, authorUid, image, name, info, description, joinType, members)

### 3.5 채팅 (ChatRepository + ChatRemoteDataSource 신설)

**경로 규약**:
- 그룹: `Messages/{그룹 Firebase key}/{pushId}`
- 1:1: `Messages/{내uid}/{상대uid}/{pushId}` — 전송 시 `Messages/{상대uid}/{내uid}/{pushId}`에도 **동일 pushId로 updateChildren 원자 미러 기록**

**MessageItem 스키마** (키 verbatim): `from`(발신 uid), `name`(발신 이름), `message`, `type`(항상 "text"), `seen`(항상 false 기록, 읽음 처리 없음), `timestamp`(클라이언트 epoch millis)

**조회**:
- 초기: `orderByKey().limitToLast(15)` 1회 조회
- 이전 페이지: 보유한 가장 오래된 key를 커서로 `endAt(cursor)` + `limitToLast(count+15)` — endAt은 inclusive이므로 커서 key 중복 제거(Android fetchMessageList 로직: firstMessageKey/insertPosition/addedCount 재현)
- **실시간**: 초기 로드 후 마지막 key 이후를 `queryStarting`으로 childAdded 관찰(개선 2). 화면 이탈 시 옵저버 해제.

**전송**: push로 key 선발급 → 로컬 리스트에 (key, item) 즉시 추가(낙관적) → setValue. childAdded 수신분과 **key로 중복 제거**(개선: Android는 중복 발생).

### 3.6 채팅방 목록 (신설, ChatListView 전용 조회)

- 그룹채팅방: `UserGroupList/{내uid}` `orderByValue().equalTo(true)` → 각 `Groups/{key}`에서 이름·이미지
- 1:1: `Messages/{내uid}` 자식 키(상대 uid) 목록 → 각 스레드 `limitToLast(1)`로 마지막 메시지(미리보기·시각). 상대 이름은 상대 발신(`from != 내uid`) 마지막 메시지의 `name` — `limitToLast(10)` 범위에서 탐색하고 없으면 uid 표시
- 정렬: 마지막 메시지 timestamp 내림차순, 메시지 없는 그룹채팅방은 하단에 이름순
- 1회 조회 + 재진입 시 새로고침(1차 패턴). 실시간 관찰은 하지 않는다(YAGNI).

## 4. 화면 설계 (View + 화면당 ViewModel, 1차 MVVM 패턴)

### 4.1 FindGroupView / RequestView (공용 컴포넌트 `GroupListContent`)

- 내비 타이틀: "그룹 찾기" / "가입신청중 그룹", back으로 pop
- 최초/새로고침 로딩: 스켈레톤 행 7개(redacted). 추가 페이지 로딩: 하단 ProgressView 푸터
- 셀: 좌 150×100pt 이미지(쿠키 헤더 RemoteImage, fitXY 대응 scaledToFill) / 우 이름(2줄)+`"가입방식: 자동 승인"|"가입방식: 운영자 승인 확인"`
- 페이징: 마지막 셀 onAppear → fetchNextPage(중복 가드), endReached면 푸터 숨김
- pull-to-refresh: refresh() (1차 킷 한계로 장식적이어도 재진입 새로고침은 동작)
- **빈 상태**(개선 4): "가입신청중인 그룹이 없습니다." / 찾기는 "가입할 수 있는 그룹이 없습니다."
- 셀 탭 → GroupInfoDialogView 오버레이 (찾기=가입신청 모드, 신청중=신청취소 모드)
- ViewModel: FindGroupViewModel(LIMIT 15) / RequestViewModel(LIMIT 100), 상태 `isLoading/items/offset/hasRequestMore/isEndReached/message`, init 시 즉시 첫 로드

### 4.2 GroupInfoDialogView + GroupInfoViewModel

- 커스텀 중앙 다이얼로그(ZStack 오버레이, 투명 배경): 이미지 200pt(centerCrop) + 하단 겹침 이름 라벨(#77000000 배경·흰 글씨) + 설명(최대 6줄) + info + 1px 구분선 + [가입신청|신청취소] [닫기]
- sendRequest 흐름은 §3.3. 처리 중 버튼 비활성+ProgressView
- 성공 후:
  - 가입신청: 토스트 "신청완료" → 다이얼로그 닫고 **FindGroupView pop** → GroupMain 새로고침(자동승인 그룹이면 내 그룹에 즉시 표시)
  - 신청취소: 토스트 "신청취소" → 다이얼로그만 닫고 RequestView 목록 새로고침

### 4.3 CreateGroupView + CreateGroupViewModel

- 폼(위→아래): 그룹이름(hint "그룹이름 입력", 클리어 버튼, 포커스 기본) / 이미지 275pt(기본 add_photo, 탭 → confirmationDialog·ActionSheet: 카메라/갤러리/이미지 없음, 1차 CameraPicker·PhotoPicker 재사용, 갤러리는 200px 리사이즈) / 설명(hint "그룹 설명을 입력하세요.", 멀티라인) / 하단 고정 가입방식 라디오("자동 승인" 기본 · "승인 확인")
- 툴바 우측 "생성" 버튼. 검증: 빈 이름 → "그룹명을 입력하세요.", 빈 설명 → "그룹설명을 입력하세요." (필드 하단 빨간 캡션)
- 전송 중: #77000000 오버레이 + "전송중..."
- 성공: §3.4 완료 후 **새 그룹 GroupView로 programmatic push**(admin=true, Firebase key 전달), GroupMain은 복귀 시 새로고침

### 4.4 ChatView + ChatViewModel

- 초기화 인자: `receiver`(그룹 Firebase key 또는 상대 uid), `isGroupChat`, `chatName`. 타이틀 = `chatName + (그룹이면 " 그룹채팅방")`
- 리스트 배경 `#f4faff`, 하단 정렬(stackFromEnd 대응: ScrollViewReader + 초기 진입 시 마지막으로 scrollTo)
- 말풍선:
  - 좌(상대): 프로필 41pt(쿠키 헤더 userImage URL)+이름(13pt bold #777777) — **같은 분("a h:mm")·같은 발신자 묶음의 첫 메시지에만** 표시(separated 규칙), 말풍선 #434343 16pt
  - 우(나): 프로필·이름 없음, 타임스탬프가 말풍선 왼쪽
  - 타임스탬프: `"a h:mm"` 포맷(예 "오후 3:05"), **묶음의 마지막 메시지에만**(아니면 자리 유지 invisible)
- 스크롤: 최상단 도달 시 fetchPreviousPage(가드+커서, §3.5) 후 기존 첫 항목 위치로 보정 / 신규 수신·전송은 바닥 근처일 때만 자동 스크롤(KnuMiniGroup-iOS 채팅 키보드 픽스와 동일한 "바닥 근처 판정" 기준)
- 입력 바: TextField(hint "메시지를 입력하세요.") + "전송" 버튼(입력 비면 회색 배경·회색 글씨, 있으면 accent·흰 글씨). 빈 문자열/공백만이면 토스트 "메시지를 입력하세요."
- Firebase 미구성이면 리스트 대신 "채팅을 사용할 수 없습니다" 안내(입력 바 비활성)

### 4.5 ChatListView + ChatListViewModel (신설)

- 드로어 `MainRoute`에 `chatList`("채팅", SF Symbol bubble 계열) 추가 — 그룹메인과 로그아웃 사이
- 행: 그룹채팅방=그룹 이미지+이름+마지막 메시지 미리보기·시각 / 1:1=상대 프로필(쿠키 userImage)+이름+미리보기·시각
- 탭 → ChatView(해당 인자). 빈 상태: "대화가 없습니다."
- Firebase 미구성이면 안내 문구

### 4.6 진입점 배선 (기존 화면 수정)

1. **GroupMainView** 하단 3버튼: PlaceholderView → FindGroupView / RequestView / CreateGroupView
2. **GroupView** 툴바 우측에 채팅 아이콘 추가 → ChatView(그룹 key, 그룹명, 그룹채팅)
3. **UserDialogView** "메시지 보내기" 활성화(본인이면 기존대로 숨김) → ChatView(상대 uid, 이름, 1:1)
4. **MainView** 드로어에 "채팅" 메뉴 추가 → ChatListView
5. 빈 그룹 상태 페이저의 "그룹 찾기"/"그룹 생성" 버튼도 실화면 연결

## 5. 에러·엣지 처리

- **Firebase 미구성**(GoogleService-Info.plist 부재): LMS 기능(목록·생성·신청 API)은 동작, Firebase 병합·기록 생략. 신청중 목록=빈 상태+안내, 채팅·채팅목록=안내 문구. 기존 `FirebaseRef.database()` nil 패턴 일관 적용
- **네트워크/파싱 실패**: 1차와 동일하게 Resource 실패 → 토스트/스낵바 메시지
- **세션 만료 중 자동 재로그인·HTTP status 검사**: 1차 파킹 항목 그대로 유지(2차 미포함)
- 그룹 생성 이미지 업로드 302: 성공 처리(§3.4)

## 6. 검증·커밋 정책

- WSL Swift 컴파일 불가 → 1차와 동일한 **정적 검증**(타입 인터페이스 정합, pbxproj 등록 확인, grep 교차 검사)
- 신규 파일은 **pbxproj 수동 등록** 필수(1차 규칙·ID 채번 방식 유지)
- **Mac 인수 체크리스트**(`docs/superpowers/plans/2026-08-26-mac-build-checklist.md`)에 2차 항목 추가: share_group_list 파서 실마크업 검증, Firebase 쿼리 시그니처, 302 처리, 채팅 실기기 E2E
- 커밋: `second` 브랜치에 **태스크별 커밋**(1차 오버라이드 연장, 사용자 합의). Co-Authored-By 등 트레일러 금지, **push 금지**(사용자 몫)
- CRLF 노이즈 유의: 실수정 파일만 경로 스테이징, `git add -A` 금지

## 7. 최고 위험 항목

1. share_group_list.acl HTML 파서 — 실마크업 미검증(전 파서 공통 리스크)
2. Firebase iOS SDK 쿼리 API(queryStarting/endAt/runTransactionBlock) 시그니처 — 정적 검증만 가능
3. GroupView 툴바 아이콘 추가 — 1차 CollapsingHeader 구조 변경 리스크
4. 302 처리 — URLSession delegate 리다이렉트 차단 코드 실검증 불가
