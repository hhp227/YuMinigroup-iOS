# YuMinigroup-iOS 2차 (그룹 라이프사이클 + 채팅) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 그룹찾기·가입신청중·그룹 만들기·채팅(그룹/1:1)을 YuMiniGroup-Android 의도 미러로 구현하고, 합의된 개선 4종(채팅방 목록·낙관적 전송 정합·Firebase 트랜잭션·빈 상태 UI)을 더한다.

**Architecture:** 1차 패턴 그대로 — SwiftUI(iOS 15.6) + ObservableObject VM + Repository/RemoteDataSource(LMS 스크래핑 + Firebase RTDB). 신규 데이터층은 GroupRemoteDataSource 확장 + ChatRemoteDataSource 신설.

**Tech Stack:** SwiftUI, URLSession(수동 쿠키 HttpClient), FirebaseDatabase(SPM 기링크), UIImagePickerController/PHPickerViewController(1차 헬퍼 재사용)

**Spec:** `docs/superpowers/specs/2026-08-27-phase2-groups-chat-design.md` — 각 태스크 구현 전 해당 스펙 섹션(§ 표기)을 먼저 읽을 것. Android 동작 상세(엔드포인트 파라미터·Firebase 경로·커서 로직 verbatim)는 스펙 §3에 있다.

## Global Constraints

- 배포 타깃 **iOS 15.6**. iOS 16 전용 API 금지(`NavigationStack`·`navigationDestination`·`PhotosPicker`·`presentationDetents`) → `NavigationView`+`NavigationLink(isActive:)`+`StackNavigationViewStyle`. `confirmationDialog`는 iOS 15 OK.
- **WSL은 Swift 컴파일 불가.** 태스크별 검증 = ①인터페이스 정합(grep) ②pbxproj 등록 정합 ③스펙·Android 원본과 대조. 테스트 타깃 없음(1차와 동일).
- **커밋 규칙**: 작업 브랜치 **`second`**. 태스크마다 수정·생성 파일을 **경로 지정 `git add` 후 커밋**(`git add -A` 금지). 커밋 메시지는 한 줄 관례형, **Co-Authored-By 등 트레일러 금지**, **push 금지**.
- 새 파일은 **LF** 개행.
- **pbxproj 수동 등록**: 파일 생성 태스크는 같은 태스크 안에서 `YuMinigroup.xcodeproj/project.pbxproj`의 PBXFileReference·PBXBuildFile·PBXGroup·PBXSourcesBuildPhase 4곳을 함께 갱신. ID는 기존 관례(`YU` + 22자리 순번) 이어서 **`YU0000000000000000000152`부터** 발급(등록 직전 `grep -o "YU000000000000000000[0-9]*" project.pbxproj | sort -u | tail -1`로 현재 최대값 재확인). 등록 후 각 파일명 grep이 4곳 모두 나오는지 확인.
- **미러 명명**: 클래스·메소드명은 Android(`com.hhp227.yu_minigroup`)와 동일(FindGroupViewModel/RequestViewModel/CreateGroupViewModel/ChatViewModel 등). 비동기는 `Resource<T>` 수렴, `try!`·`fatalError` 금지.
- **wire 계약 불변**: 엔드포인트 파라미터 이름·값, Firebase 경로·필드명·boolean 의미(true=가입/false=승인대기), joinType `"0"`/`"1"`은 스펙 §3의 값을 바이트 수준 그대로. body 인코딩만 정상 percent-encoding(1차 HttpClient.encodeParams 그대로 사용).
- **Firebase 미구성 대응**: 모든 Firebase 접근은 `FirebaseRef.database()` nil 가드 후 스펙 §5대로 강등(찾기=LMS만, 신청중=빈 목록, 채팅=안내 문구).
- 참조(읽기 전용): Android=`../YuMiniGroup-Android/app/src/main/java/com/hhp227/yu_minigroup/`.

---

### Task 1: 그룹 목록 데이터층 — share_group_list 파싱 + Firebase 병합/필터

**Files:**
- Modify: `YuMinigroup/App/EndPoint.swift` (상수 4개 추가, 헤더 코멘트의 "2·3차 예정" 문구 갱신)
- Modify: `YuMinigroup/Data/Remote/GroupRemoteDataSource.swift`
- Modify: `YuMinigroup/Data/GroupRepository.swift`

**Interfaces:**
- Consumes: `HttpClient.request`, `HtmlUtil.attributeExact/attribute/text`, `CookieStore.shared.cookieHeader`, `FirebaseRef.database()`, `PreferenceManager.shared.user?.uid`, `GroupItem`(1차 정의 그대로)
- Produces (GroupRepository 패스스루 포함):

```swift
// GroupRemoteDataSource
func fetchNotJoinedGroups(offset: Int, limit: Int, completion: @escaping (Resource<[GroupItem]>) -> Void)
func fetchJoinRequestGroups(offset: Int, limit: Int, completion: @escaping (Resource<[GroupItem]>) -> Void)
func resetGroupPaging()          // minId=0 + stopRequestMore=false (Android 결함 3 수정)
var isGroupPagingStopped: Bool   // Android isStopRequestMore()
```

- [ ] **Step 1: EndPoint 추가** — 스펙 §3.1 그대로:

```swift
static let createGroup      = baseURL + "/ilos/community/share_group_insert.acl"
static let registerGroup    = baseURL + "/ilos/community/share_group_register.acl"
static let groupImageUpdate = baseURL + "/ilos/community/share_group_image_update.acl"
static let noPhotoImage     = baseURL + "/ilos/images/community/share_nophoto.gif"
```

- [ ] **Step 2: Android 원본 정독** — `data/remote/GroupRemoteDataSource.java`의 `getNotJoinedGroupList`(:116)·`getJoinRequestGroupList`(:197)·`groupIdExtract` 두 오버로드·`initFirebaseData`. 파싱 셀렉터를 아래와 대조.
- [ ] **Step 3: 목록 요청 + 파싱 구현** — 두 메소드 공통 POST `EndPoint.groupList`, formParams `["panel_id": "1", "gubun": "select_share_total", "start": String(offset), "display": String(limit), "encoding": "utf-8"]`. 파싱은 세그먼트 방식(1차 parseAnchor와 같은 정규식 관례):
  - `id=["']accordion["']`를 가진 여는 태그 전부를 정규식으로 찾고, 각 매치 시작~다음 매치 시작(마지막은 문서 끝)을 세그먼트로 자른다. 여는 태그의 `class`가 정확히 `accordion`인 세그먼트만 처리(Android `getAttributeValue("class").equals("accordion")` 미러).
  - 그룹 ID: 세그먼트 안 `class="button"` 여는 태그의 onclick(`HtmlUtil.attributeExact`) →
    - **find 모드**: `onclick.components(separatedBy: CharacterSet(charactersIn: "(),"))`의 [1] trim (Android `split("[(]|[)]|[,]")[1]`)
    - **request 모드**: `onclick.components(separatedBy: "'")`의 [1] trim (Android String 오버로드)
    - Int 변환 실패 또는 인덱스 부족 시 해당 세그먼트만 skip(1차 parseAnchor 관례).
  - 이미지: 세그먼트의 첫 `<img>` src에 `EndPoint.baseURL` 접두(+`HtmlUtil.text`로 엔티티 보정). 이름: 첫 `<strong>` 텍스트.
  - `class="info"` 요소 내부 텍스트들을 순서대로 수집: [0]→`description_`, [1] trim→joinType 판정(`"가입방식: 자동 승인"` 정확 일치 → `"0"`, 아니면 `"1"`). `info` 필드: 각 텍스트가 `"회원수"` 포함 시 `"생성일"` 마지막 등장 위치 앞까지 trim+"\n", 아니면 그대로+"\n" 누적(스펙 §3.2).
  - GroupItem 생성: `isAdmin: false, memberCount: 0, key: nil`, 나머지 파싱값.
- [ ] **Step 4: minId 휴리스틱** — 인스턴스 필드 `private var minId = 0`, `private var stopRequestMore = false`. 파싱 루프에서 `minId = (minId == 0) ? id : min(minId, id)`, `id > minId`면 `stopRequestMore = true` 후 루프 중단. `resetGroupPaging()`은 둘 다 리셋. find/request가 같은 필드를 공유해도 무방(화면당 VM이 각자 `GroupRepository()`→각자 데이터소스 인스턴스를 갖는 1차 구조).
- [ ] **Step 5: Firebase 병합(find)** — LMS 성공 후 `Groups`를 `queryOrderedByKey` 1회 스캔, 각 child의 `childSnapshot(forPath: "id")`가 일치하는 item의 `key`를 child.key로 교체(1차 `resolveKeys` 관례). `FirebaseRef.database()` nil 또는 조회 실패(withCancel) → LMS 결과 그대로 `.success`. (교정 2026-08-27 최종 리뷰: 미매칭 항목은 key = LMS ID 폴백 — 스펙 §3.2 "없으면 LMS ID 유지"가 본 계획에서 누락됐었음)
- [ ] **Step 6: Firebase 교차 필터(request, 결함 1 수정)** — `FirebaseRef.database()` nil 또는 uid 없음 → `.success([])`. 아니면:

```swift
root.child("UserGroupList").child(uid).queryOrderedByValue().queryEqual(toValue: false)
    .observeSingleEvent(of: .value, with: { snapshot in
        var keys: [String] = []
        for case let child as DataSnapshot in snapshot.children { keys.append(child.key) }
        guard !keys.isEmpty else { completion(.success([])); return }
        var pending: [GroupItem] = []
        var remaining = keys.count
        let finish = {
            remaining -= 1
            if remaining == 0 { completion(.success(pending.sorted { $0.name < $1.name })) }
        }
        for key in keys {
            root.child("Groups").child(key).observeSingleEvent(of: .value, with: { groupSnapshot in
                if let lmsId = groupSnapshot.childSnapshot(forPath: "id").value as? String,
                   var item = items.first(where: { $0.id == lmsId }) {
                    item.key = key
                    pending.append(item)
                }
                finish()
            }, withCancel: { _ in finish() })
        }
    }, withCancel: { _ in completion(.success([])) })
```

- [ ] **Step 7: Repository 패스스루 + 검증** — GroupRepository에 세 메소드·프로퍼티 위임 추가. grep: `fetchNotJoinedGroups\|fetchJoinRequestGroups\|resetGroupPaging`이 DataSource·Repository 양쪽에 있는지, EndPoint 4상수 존재, `gubun\|panel_id\|select_share_total` 파라미터 오탈자 확인.
- [ ] **Step 8: 커밋** — `git add YuMinigroup/App/EndPoint.swift YuMinigroup/Data/Remote/GroupRemoteDataSource.swift YuMinigroup/Data/GroupRepository.swift` → `feat: add group discovery data layer (share_group_list + firebase merge/filter)`

---

### Task 2: 가입신청/신청취소 데이터층 — register + 트랜잭션

**Files:**
- Modify: `YuMinigroup/Data/Remote/GroupRemoteDataSource.swift`
- Modify: `YuMinigroup/Data/GroupRepository.swift`

**Interfaces:**
- Consumes: Task 1까지의 데이터소스, `EndPoint.registerGroup`/`EndPoint.withdrawalGroup`, 기존 `performRemoval`의 JSON `isError` 판정 패턴
- Produces:

```swift
// GroupRemoteDataSource + GroupRepository 패스스루
// fallback: Groups/{key} 노드가 없을 때 최소 노드 생성용(스펙 §2 결함 6) — 목록 셀의 GroupItem 그대로
func registerGroup(groupId: String, key: String?, joinType: String, fallback: GroupItem?,
                   completion: @escaping (Resource<Bool>) -> Void)
func cancelJoinRequest(groupId: String, key: String?, completion: @escaping (Resource<Bool>) -> Void)
```

- [ ] **Step 1: Android 원본 정독** — `viewmodel/GroupInfoViewModel.java`(:83 sendRequest, :181 deleteUserInGroupFromFirebase, insertGroupToFirebase). 이미-멤버면 map을 비우는 결함(스펙 §2-④)은 이식하지 않는다.
- [ ] **Step 2: LMS 호출** — 기존 `performRemoval(endpoint:groupId:completion:onSuccess:)`를 그대로 재사용(둘 다 POST `CLUB_GRP_ID` 1개 + JSON `isError` 판정): register는 `EndPoint.registerGroup`, cancel은 `EndPoint.withdrawalGroup`.
- [ ] **Step 3: 트랜잭션 헬퍼(개선 3)** — `Groups/{key}` 통째 setValue 대신:

```swift
private func runMembershipTransaction(key: String, fallback: GroupItem?, joinType: String?,
                                       mutate: @escaping (inout [String: Bool]) -> Void) {
    guard let root = FirebaseRef.database() else { return }
    root.child("Groups").child(key).runTransactionBlock { currentData in
        if var group = currentData.value as? [String: Any] {
            var members = (group["members"] as? [String: Any])?
                .compactMapValues { ($0 as? Bool) ?? ($0 as? NSNumber)?.boolValue } ?? [:]
            mutate(&members)
            group["members"] = members
            group["memberCount"] = members.count
            currentData.value = group
        } else if let fallback = fallback {
            // 비앱 생성 그룹(Firebase 미등록) — 최소 노드 생성(스펙 §2 결함 6 수정)
            var members: [String: Bool] = [:]
            mutate(&members)
            currentData.value = [
                "admin": false,
                "id": fallback.id,
                "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
                "image": fallback.image,
                "name": fallback.name,
                "description": fallback.description_ ?? "",
                "joinType": joinType ?? fallback.joinType ?? "1",
                "members": members,
                "memberCount": members.count
            ] as [String: Any]
        }
        return TransactionResult.success(withValue: currentData)
    }
}
```

- [ ] **Step 4: register/cancel 조립** — LMS 성공(onSuccess 클로저)에서, `key`와 `uid`가 있을 때만:
  - register: `runMembershipTransaction(key:fallback:joinType:) { $0[uid] = (joinType == "0") }` + `root.child("UserGroupList").child(uid).child(key).setValue(joinType == "0")` — **true=정식가입/false=승인대기**(스펙 §3.3).
  - cancel: `runMembershipTransaction(key:fallback: nil, joinType: nil) { $0.removeValue(forKey: uid) }` + `UserGroupList/{uid}/{key}` `removeValue()`.
  - `key == nil`(Firebase 미등록/미구성)이면 Firebase 갱신 전체 생략(LMS만 성공 처리). (교정: Task 1 폴백 적용 후 key nil은 사실상 Firebase 미구성 경우만 남는다)
- [ ] **Step 5: 검증** — grep으로 `runTransactionBlock` 존재, `setValue(joinType == "0")`의 boolean 의미가 스펙 §3.3 표와 일치하는지 대조, Repository 패스스루 2건 확인.
- [ ] **Step 6: 커밋** — `feat: add group join request/cancel data layer with firebase transaction`

---

### Task 3: 그룹찾기 화면 — 공용 리스트 + GroupInfo 다이얼로그 + FindGroupView

**Files:**
- Create: `YuMinigroup/View/GroupListContent.swift`
- Create: `YuMinigroup/View/GroupInfoDialogView.swift`
- Create: `YuMinigroup/View/FindGroupView.swift`
- Create: `YuMinigroup/ViewModel/FindGroupViewModel.swift`
- Create: `YuMinigroup/ViewModel/GroupInfoViewModel.swift`
- Modify: `YuMinigroup.xcodeproj/project.pbxproj` (5파일 × FileRef+BuildFile = ID 152~161)

**Interfaces:**
- Consumes: Task 1·2의 Repository 메소드, `RemoteImage(urlString:)`, `.toast(message:)`, `Resource<T>`
- Produces:

```swift
struct GroupListContent: View {   // FindGroupView/RequestView 공용(Android activity_list.xml 대응)
    let items: [GroupItem]
    let isInitialLoading: Bool    // 스켈레톤 조건 = isLoading && !hasRequestMore (Android 미러)
    let hasRequestMore: Bool
    let isEndReached: Bool
    let emptyMessage: String
    let onItemTap: (GroupItem) -> Void
    let onLoadMore: () -> Void
    let onRefresh: () -> Void
}

final class FindGroupViewModel: ObservableObject {
    struct State {
        var items: [GroupItem] = []
        var isLoading = false
        var hasRequestMore = false
        var isEndReached = false
        var message: String?
    }
    @Published var state: State
    init()                 // 즉시 fetchNextPage() (Android 미러), LIMIT=15, offset은 1에서 +15씩
    func fetchNextPage()
    func refresh()         // repository.resetGroupPaging() + offset=1 + 재조회
}

final class GroupInfoViewModel: ObservableObject {
    enum ButtonType { case request, cancel }
    struct State { var isProcessing = false; var message: String?; var completed: ButtonType? }
    @Published var state: State
    let group: GroupItem
    let buttonType: ButtonType
    init(group: GroupItem, buttonType: ButtonType)
    func sendRequest()     // request→registerGroup(성공 시 message="신청완료"), cancel→cancelJoinRequest("신청취소")
}

struct GroupInfoDialogView: View {
    // 중앙 다이얼로그 카드. 표시/닫기는 부모가 selectedGroup 옵셔널로 관리.
    @ObservedObject var viewModel: GroupInfoViewModel
    let onClose: () -> Void
    let onCompleted: (GroupInfoViewModel.ButtonType) -> Void  // state.completed 관찰 후 호출
}

struct FindGroupView: View {
    init(onJoined: @escaping () -> Void)   // 가입신청 성공 → 자기 pop 후 GroupMain 새로고침용
}
```

- [ ] **Step 1: Android 원본 정독** — `activity/FindGroupActivity.java`, `viewmodel/FindGroupViewModel.java`+`ListViewModel.java`, `fragment/GroupInfoFragment.java`, `res/layout/fragment_group_info.xml`·`group_list_item.xml`.
- [ ] **Step 2: FindGroupViewModel** — 상태·흐름은 위 Interfaces + Android 미러: `fetchNextPage()`는 `state.isLoading || state.isEndReached || repository.isGroupPagingStopped`면 무시. 성공 시 `items += 신규`, `offset += 15`, `isEndReached = 신규.isEmpty`. 실패 시 `message` 세팅. `refresh()`는 `resetGroupPaging()` 후 `offset=1, items=[], isEndReached=false` 리셋+재조회.
- [ ] **Step 3: GroupListContent** — 스펙 §4.1 그대로: 최초 로딩이면 스켈레톤 행 7개(`.redacted(reason: .placeholder)`, 회색 150×100 사각형+텍스트 2줄), 아니면 `ScrollView`+`LazyVStack`의 셀(좌 `RemoteImage` 150×100 `scaledToFill().clipped()`, 우 이름 `lineLimit(2)`+`가입방식:` 라벨 캡션) — 마지막 셀 `onAppear`에서 `onLoadMore()`(1차 Tab3View 관례). 푸터: `hasRequestMore && !isEndReached`일 때 `ProgressView`. 빈 상태(개선 4): `!isInitialLoading && items.isEmpty`면 중앙에 `emptyMessage`. `.refreshable { onRefresh() }`.
- [ ] **Step 4: GroupInfoViewModel + GroupInfoDialogView** — 다이얼로그 레이아웃 스펙 §4.2: 이미지 200pt(`RemoteImage(urlString: group.image)`) + 하단 겹침 이름(`Color.black.opacity(0.47)` 배경·흰 글씨 18pt) + 설명(`description_`, 16pt, `lineLimit(6)`) + info(13pt secondary) + `Divider` + 버튼 2개(`가입신청`/`신청취소` ↔ `닫기`, UserDialogView actionBar 관례). 처리 중 버튼 `disabled`+`ProgressView`. `onChange(of: viewModel.state.completed)`에서 nil 아니면 `onCompleted` 호출.
- [ ] **Step 5: FindGroupView** — `ZStack { GroupListContent(...); if selectedGroup != nil { 딤 배경(Color.black.opacity(0.5), 탭=닫기) + GroupInfoDialogView(...) } }` + `.navigationTitle("그룹 찾기")`+`.navigationBarTitleDisplayMode(.inline)`+`.toast(message: $viewModel.state.message)`. `emptyMessage: "가입할 수 있는 그룹이 없습니다."`. `onCompleted(.request)` → `selectedGroup = nil` → `presentationMode.wrappedValue.dismiss()` + `onJoined()` (Android FindGroupActivity finish+RESULT_OK 미러). 다이얼로그 표시 중 토스트가 다이얼로그 위에 오도록 `.toast`는 ZStack 바깥 최상위에.
- [ ] **Step 6: pbxproj 등록** — 5파일을 View/ViewModel 그룹에 ID 152~161로 등록 → 파일명별 grep 4곳 확인.
- [ ] **Step 7: 검증** — `GroupInfoViewModel.ButtonType` 참조 일관성, `onJoined` 전달 경로, iOS16 API grep(`NavigationStack\|presentationDetents\|PhotosPicker` 0건).
- [ ] **Step 8: 커밋** — 생성 5파일+pbxproj 경로 add → `feat: add find group screen with group info dialog`

---

### Task 4: 가입신청중 화면 — RequestView + GroupMain 배선(찾기/신청중)

**Files:**
- Create: `YuMinigroup/View/RequestView.swift`
- Create: `YuMinigroup/ViewModel/RequestViewModel.swift`
- Modify: `YuMinigroup/View/GroupMainView.swift` (하단 3버튼 중 2개 실연결)
- Modify: `YuMinigroup.xcodeproj/project.pbxproj` (2파일 = ID 162~165)

**Interfaces:**
- Consumes: Task 1 `fetchJoinRequestGroups`, Task 2 `cancelJoinRequest`, Task 3 `GroupListContent`/`GroupInfoDialogView`/`GroupInfoViewModel`, `FindGroupView(onJoined:)`
- Produces:

```swift
final class RequestViewModel: ObservableObject {
    // 자체 State 구조체(FindGroupViewModel.State와 동일 필드 — 화면당 VM 독립이라는 1차 관례). LIMIT=100(Android 미러).
    // 성공 시 items = (offset == 1 ? 신규 : items + 신규), offset += 100, isEndReached = 신규.isEmpty
    // (Android의 "크기 같으면 리셋" 결함성 병합 대신 실제 필터링 전제의 단순형 — 스펙 §2 결함 1 연동)
    @Published var state: State
    init(); func fetchNextPage(); func refresh()
}
struct RequestView: View { init() }   // 셀 탭 → GroupInfoDialogView(buttonType: .cancel)
```

- [ ] **Step 1: Android 원본 정독** — `activity/RequestActivity.java`, `viewmodel/RequestViewModel.java`.
- [ ] **Step 2: RequestViewModel** — 위 Interfaces대로. 자체 `State` 구조체 선언 권장(FindGroupViewModel.State와 필드 동일 — 화면당 VM 독립이라는 1차 관례 유지).
- [ ] **Step 3: RequestView** — FindGroupView와 같은 뼈대, 차이: `navigationTitle("가입신청중 그룹")`, `emptyMessage: "가입신청중인 그룹이 없습니다."`, 다이얼로그 `buttonType: .cancel`, `onCompleted(.cancel)` → 다이얼로그만 닫고 `viewModel.refresh()` (Android: Activity 유지, 스펙 §4.2). 최초 로딩 스켈레톤 정상 표시(스펙 §2 결함 7 수정 — Android는 onLoading 미호출이지만 데이터소스가 `.loading`을 쏘므로 자동 해결됨을 확인만).
- [ ] **Step 4: GroupMainView 배선** — `bottomButton`을 제네릭 destination으로 변경:

```swift
private func bottomButton<Destination: View>(title: String, systemImage: String,
                                              @ViewBuilder destination: () -> Destination) -> some View
```

  "그룹찾기" → `FindGroupView(onJoined: viewModel.fetchGroups)`, "가입신청중 그룹" → `RequestView()`. "그룹 만들기"는 이 태스크에서는 기존 `PlaceholderView` 유지(Task 6 몫). `emptyBanner`도 Task 6에서 손댄다.
- [ ] **Step 5: pbxproj 등록 + 검증** — 2파일 ID 162~165, grep 4곳. `PlaceholderView(` 잔존이 GroupMainView에 1건(그룹 만들기)뿐인지 확인.
- [ ] **Step 6: 커밋** — `feat: add pending join requests screen and wire group main buttons`

---

### Task 5: 그룹 생성 데이터층 — addGroup 3단계

**Files:**
- Modify: `YuMinigroup/Data/Remote/GroupRemoteDataSource.swift` (`import UIKit` 추가)
- Modify: `YuMinigroup/Data/GroupRepository.swift`

**Interfaces:**
- Consumes: `MultipartRequest.upload`(1차), `BitmapUtil` 불필요(리사이즈는 VM에서), `EndPoint.createGroup/groupImageUpdate/noPhotoImage/groupImage(file:)`
- Produces:

```swift
// GroupRemoteDataSource + Repository 패스스루
// 성공값: (key: Firebase push key(미구성 시 nil), group: 완성된 GroupItem — isAdmin=true, members=[uid: true])
func addGroup(title: String, description: String, joinType: String, image: UIImage?,
              completion: @escaping (Resource<(key: String?, group: GroupItem)>) -> Void)
```

- [ ] **Step 1: Android 원본 정독** — `GroupRemoteDataSource.java` `addGroup`(:391)·`groupImageUpdate`(:539)·`insertGroupToFirebase`(:669).
- [ ] **Step 2: Step A(생성)** — POST `EndPoint.createGroup`, formParams `["GRP_NM": title, "TXT": description, "JOIN_DIV": joinType]`. 응답 JSON 디코드:

```swift
private struct CreateGroupResponse: Decodable {
    let isError: Bool
    let clubGrpId: String
    let grpNm: String
    private enum CodingKeys: String, CodingKey { case isError, clubGrpId = "CLUB_GRP_ID", grpNm = "GRP_NM" }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isError = try container.decode(Bool.self, forKey: .isError)
        // 서버가 숫자로 줄 가능성 방어(Android getString은 자동 문자열화)
        if let stringId = try? container.decode(String.self, forKey: .clubGrpId) {
            clubGrpId = stringId
        } else {
            clubGrpId = String(try container.decode(Int.self, forKey: .clubGrpId))
        }
        grpNm = try container.decode(String.self, forKey: .grpNm)
    }
}
```

  `isError == true` 또는 디코드 실패 → `.error("그룹 생성에 실패했습니다.")`. `groupId = clubGrpId.trimmingCharacters(...)`.
- [ ] **Step 3: Step B(이미지, image != nil일 때만)** — `MultipartRequest.upload(EndPoint.groupImageUpdate, headers: ["Cookie": cookie], fileField: "file", fileName: "\(UUID().uuidString.replacingOccurrences(of: "-", with: "")).jpg", mimeType: "image/jpeg", fileData: image.pngData() ?? Data(), formParams: ["CLUB_GRP_ID": groupId])` — **PNG 바이트 + .jpg 파일명은 Android 검증 방식 그대로**(스펙 §3.4).
  **302 처리**: HttpClient.session은 리다이렉트를 따라가지 않으므로 302도 `.success`(본문 유무 무관)로 온다. 단 MultipartRequest는 `data == nil`이면 `AppError("응답이 비어있습니다.")`로 실패시키므로, **이 특정 에러는 성공으로 간주**하고 Step C로 진행한다(Android의 302→성공 미러):

```swift
case .failure(let error):
    if (error as? AppError)?.message == "응답이 비어있습니다." {
        self.insertGroupToFirebase(...)   // 302/빈 본문 — Android와 동일하게 성공 취급
    } else {
        completion(.error(error.localizedDescription))
    }
case .success:
    self.insertGroupToFirebase(...)       // 응답 본문은 Android도 사용하지 않는다
```

- [ ] **Step 4: Step C(Firebase 원자 기록)** — `insertGroupToFirebase(groupId:groupName:description:joinType:hasImage:completion:)`:
  - `imageURL = hasImage ? EndPoint.groupImage(file: "\(groupId).jpg") : EndPoint.noPhotoImage`
  - `FirebaseRef.database()` nil 또는 uid 없음 → `completion(.success((key: nil, group: 완성 GroupItem)))` (LMS만으로 성공).
  - 아니면 `let key = root.childByAutoId().key`(루트 push key — Android 미러) 후:

```swift
let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
let groupDict: [String: Any] = [
    "admin": false,          // Android Bean 직렬화가 항상 false로 기록(필드명 "admin" — "isAdmin" 아님)
    "id": groupId,
    "timestamp": timestamp,
    "author": user.name ?? "",
    "authorUid": uid,
    "image": imageURL,
    "name": groupName,
    "description": description,
    "joinType": joinType,
    "members": [uid: true],  // 생성자는 항상 true(정식 가입)
    "memberCount": 1
]
root.updateChildren(["Groups/\(key)": groupDict, "UserGroupList/\(uid)/\(key)": true])
```

  - 반환 GroupItem: `id: groupId, key: key, name: groupName, image: imageURL, description_: description, joinType: joinType, isAdmin: true, author/authorUid: 나, memberCount: 1, timestamp: Date(), members: [uid: true]`.
- [ ] **Step 5: 검증** — grep: `CLUB_GRP_ID`가 이미지 업로드 텍스트 파트에 있는지, `"admin"` 필드명, `UserGroupList/\(uid)/\(key)` 경로 문자열, Repository 패스스루.
- [ ] **Step 6: 커밋** — `feat: add group creation data layer (insert + image upload + firebase)`

---

### Task 6: 그룹 만들기 화면 — CreateGroupView + GroupMain 마무리 배선

**Files:**
- Create: `YuMinigroup/View/CreateGroupView.swift`
- Create: `YuMinigroup/ViewModel/CreateGroupViewModel.swift`
- Modify: `YuMinigroup/View/GroupMainView.swift` (만들기 버튼 실연결 + 생성 직후 GroupView push + emptyBanner 버튼)
- Modify: `YuMinigroup.xcodeproj/project.pbxproj` (2파일 = ID 166~169)

**Interfaces:**
- Consumes: Task 5 `addGroup`, `CameraPicker(onPicked: (UIImage) -> Void)`, `PhotoPicker(selectionLimit:onPicked: ([UIImage]) -> Void)`, `BitmapUtil.resized(_:maxSize:)`, `GroupView(groupItem:)`
- Produces:

```swift
final class CreateGroupViewModel: ObservableObject {
    struct State {
        var isLoading = false
        var message: String?
        var titleError: String?
        var descriptionError: String?
        var created: GroupItem?     // 성공 시 세팅 — 뷰가 onChange로 감지
    }
    @Published var state: State
    @Published var title = ""
    @Published var descriptionText = ""      // description은 CustomStringConvertible과 충돌 여지 — 이 이름 고정
    @Published var isAutoJoin = true         // Android joinType 기본 true(자동 승인)
    @Published var image: UIImage?
    func createGroup()
}
struct CreateGroupView: View { init(onCreated: @escaping (GroupItem) -> Void) }
```

- [ ] **Step 1: Android 원본 정독** — `activity/CreateGroupActivity.java`, `viewmodel/CreateGroupViewModel.java`, `res/layout/activity_create_group.xml`.
- [ ] **Step 2: CreateGroupViewModel** — `createGroup()`: `title.trimmingCharacters`/`descriptionText.trimmingCharacters`가 비면 각각 `titleError = "그룹명을 입력하세요."` / `descriptionError = "그룹설명을 입력하세요."`(비지 않은 쪽은 nil로 리셋)만 세팅하고 반환. 둘 다 있으면 `repository.addGroup(title:description:joinType: isAutoJoin ? "0" : "1", image:)` — loading→`isLoading`, 성공→`created = group`, 실패→`message`.
- [ ] **Step 3: CreateGroupView** — 스펙 §4.3 레이아웃:
  - 그룹이름 행: `TextField("그룹이름 입력", text: $viewModel.title)` + 우측 클리어 버튼(`xmark.circle.fill`, title 비면 회색·있으면 진회색, 탭 시 `title = ""`), `titleError` 있으면 아래 빨간 캡션.
  - 이미지: 탭 영역 275pt — `image`가 있으면 `Image(uiImage:)` `scaledToFill().clipped()`, 없으면 `Image("add_photo")`(1차 에셋). 탭 → `confirmationDialog("이미지 선택")`: 카메라(→`fullScreenCover`에 `CameraPicker`)/갤러리(→`sheet`에 `PhotoPicker(selectionLimit: 1)`, 결과 첫 장을 `BitmapUtil.resized(_, maxSize: 200)`)/이미지 없음(→`image = nil` + 토스트 "이미지 없음 선택"). 카메라 결과도 `resized(maxSize: 200)`(Android 갤러리 200px 리사이즈 미러 — 카메라 썸네일도 통일).
  - 설명: `TextEditor`+플레이스홀더 오버레이("그룹 설명을 입력하세요.", 텍스트 비었을 때만), `descriptionError` 빨간 캡션.
  - 하단 고정 가입방식: `Text("가입방식")` + 라디오 2개("자동 승인"/"승인 확인") — iOS 관례상 체크마크 버튼 2개로 `isAutoJoin` 토글.
  - 툴바: `.toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("생성", action: viewModel.createGroup) } }` + `.navigationTitle("그룹 만들기")`.
  - 전송중 오버레이: `state.isLoading`이면 `Color.black.opacity(0.47)` 전면 + `ProgressView` + "전송중..." 흰 글씨.
  - `onChange(of: viewModel.state.created)`: nil 아니면 `presentationMode.wrappedValue.dismiss()` 후 `onCreated(group)`.
- [ ] **Step 4: GroupMainView 마무리** — "그룹 만들기" 버튼 → `CreateGroupView(onCreated: handleCreated)`. 상태 `@State private var createdGroup: GroupItem?` + `@State private var isCreatedGroupActive = false`, 숨김 링크를 ZStack에 추가:

```swift
NavigationLink(isActive: $isCreatedGroupActive) {
    if let createdGroup = createdGroup { GroupView(groupItem: createdGroup) }
} label: { EmptyView() }
.hidden()
```

  `handleCreated(group)`: `viewModel.fetchGroups()` + `createdGroup = group` 후 **pop 애니메이션과의 경합을 피해** `DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { isCreatedGroupActive = true }` (Android가 CreateGroup을 finish하고 GroupActivity를 바로 여는 흐름의 미러 — 스펙 §4.3).
  `emptyBanner`에 버튼 2개 추가(Android 빈 상태 페이저 b_find/b_create 대응): "그룹 찾기" → `FindGroupView(onJoined: viewModel.fetchGroups)` push, "그룹 생성" → `CreateGroupView(onCreated: handleCreated)` push (`NavigationLink` + `.buttonStyle(.borderedProminent)`).
- [ ] **Step 5: pbxproj 등록 + 검증** — ID 166~169, grep 4곳. GroupMainView에 `PlaceholderView(` 0건 확인.
- [ ] **Step 6: 커밋** — `feat: add create group screen and wire group main navigation`

---

### Task 7: 채팅 데이터층 — MessageItem + ChatRemoteDataSource/ChatRepository

**Files:**
- Create: `YuMinigroup/Dto/MessageItem.swift`
- Create: `YuMinigroup/Data/Remote/ChatRemoteDataSource.swift`
- Create: `YuMinigroup/Data/ChatRepository.swift`
- Modify: `YuMinigroup.xcodeproj/project.pbxproj` (3파일 = ID 170~175)

**Interfaces:**
- Consumes: `FirebaseRef.database()`, `PreferenceManager.shared.user`, `User`
- Produces:

```swift
struct MessageItem: Identifiable, Hashable {
    var id: String { key }
    var key: String            // Firebase pushId — 낙관적 추가도 push 선발급 key 사용(개선 2)
    var from, name, message, type: String
    var seen: Bool             // 항상 false 기록(Android 미러 — 읽음 처리 없음)
    var timestamp: Int64       // epoch millis(클라이언트 시각, Android 미러)
}

final class ChatRemoteDataSource {
    var isAvailable: Bool      // FirebaseRef.isConfigured
    // key 오름차순(오래된→최신) 반환. cursor 있으면 endAt(cursor) — inclusive라 호출부가 중복 제거
    func fetchMessages(currentUid: String, receiver: String, isGroupChat: Bool,
                       cursor: String?, limit: Int,
                       completion: @escaping (Result<[MessageItem], Error>) -> Void)
    // afterKey 있으면 queryStarting(atValue:) — inclusive 재생분은 호출부가 key로 중복 제거. 미구성 시 nil
    func observeNewMessages(currentUid: String, receiver: String, isGroupChat: Bool, afterKey: String?,
                            onMessage: @escaping (MessageItem) -> Void) -> UInt?
    func removeObserver(currentUid: String, receiver: String, isGroupChat: Bool, handle: UInt)
    // push 선발급 key로 만든 로컬 MessageItem 반환(미구성/uid 없음 → nil). 1:1은 양쪽 경로 원자 미러 기록
    @discardableResult
    func sendMessage(user: User, receiver: String, isGroupChat: Bool, text: String) -> MessageItem?
}
// ChatRepository: 위 4메소드+isAvailable 패스스루(1차 GroupRepository 관례)
```

- [ ] **Step 1: Android 원본 정독** — `data/remote/ChatRemoteDataSource.java`, `data/ChatRepository.java`, `dto/MessageItem.java`(@PropertyName 키 확인).
- [ ] **Step 2: 경로 헬퍼 + 디코드** —

```swift
private func threadRef(currentUid: String, receiver: String, isGroupChat: Bool) -> DatabaseReference? {
    guard let root = FirebaseRef.database() else { return nil }
    let messages = root.child("Messages")
    return isGroupChat ? messages.child(receiver) : messages.child(currentUid).child(receiver)
}

private static func decode(_ snapshot: DataSnapshot) -> MessageItem? {
    guard let dict = snapshot.value as? [String: Any],
          let from = dict["from"] as? String,
          let message = dict["message"] as? String else {
        return nil
    }
    return MessageItem(key: snapshot.key,
                       from: from,
                       name: dict["name"] as? String ?? "",
                       message: message,
                       type: dict["type"] as? String ?? "text",
                       seen: (dict["seen"] as? Bool) ?? (dict["seen"] as? NSNumber)?.boolValue ?? false,
                       timestamp: (dict["timestamp"] as? NSNumber)?.int64Value ?? 0)
}
```

- [ ] **Step 3: fetchMessages** — `threadRef` nil → `completion(.success([]))`. 쿼리: `queryOrderedByKey()` + (`cursor` 있으면 `queryEnding(atValue: cursor)`) + `queryLimited(toLast: UInt(limit))`, `observeSingleEvent(of: .value)` — children 순회(오름차순 보장)로 decode·수집. `withCancel` → `completion(.failure(error))`.
- [ ] **Step 4: observeNewMessages** — `threadRef` nil → nil. `afterKey` 있으면 `queryOrderedByKey().queryStarting(atValue: afterKey)`, 없으면 ref 그대로. `.observe(.childAdded)`로 decode 후 `onMessage`(메인 큐 보장 — Firebase 콜백은 메인 큐이므로 그대로). 반환 handle. `removeObserver`는 같은 ref에 `removeObserver(withHandle:)`.
- [ ] **Step 5: sendMessage** — 스펙 §3.5 그대로:

```swift
guard let root = FirebaseRef.database(), let uid = user.uid else { return nil }
let messagesRef = root.child("Messages")
let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
let map: [String: Any] = ["from": uid, "name": user.name ?? "", "message": text,
                          "type": "text", "seen": false, "timestamp": timestamp]
if isGroupChat {
    let ref = messagesRef.child(receiver).childByAutoId()
    guard let key = ref.key else { return nil }
    ref.setValue(map)
    return MessageItem(key: key, from: uid, name: user.name ?? "", message: text,
                       type: "text", seen: false, timestamp: timestamp)
}
guard let pushId = messagesRef.child(uid).child(receiver).childByAutoId().key else { return nil }
messagesRef.updateChildren(["\(receiver)/\(uid)/\(pushId)": map,   // 상대 쪽
                            "\(uid)/\(receiver)/\(pushId)": map])  // 내 쪽 — 동일 pushId 원자 미러
return MessageItem(key: pushId, from: uid, name: user.name ?? "", message: text,
                   type: "text", seen: false, timestamp: timestamp)
```

- [ ] **Step 6: pbxproj 등록(Dto/Data/Remote 그룹) + 검증** — ID 170~175, grep 4곳. Firebase 경로 문자열이 스펙 §3.5와 일치(`Messages` 루트, 1:1 양방향 키 순서: 상대 경로가 `receiver/uid`, 내 경로가 `uid/receiver`).
- [ ] **Step 7: 커밋** — `feat: add chat data layer (firebase messages + realtime observe)`

---

### Task 8: 채팅 화면 — ChatViewModel + ChatView + MessageRow

**Files:**
- Create: `YuMinigroup/ViewModel/ChatViewModel.swift`
- Create: `YuMinigroup/View/ChatView.swift`
- Create: `YuMinigroup/View/Cell/MessageRow.swift`
- Modify: `YuMinigroup.xcodeproj/project.pbxproj` (3파일 = ID 176~181)

**Interfaces:**
- Consumes: Task 7 전부, `RemoteImage`, `EndPoint.userImage(uid:)`, `.toast(message:)`
- Produces:

```swift
final class ChatViewModel: ObservableObject {
    struct ScrollCommand: Equatable {
        enum Kind: Equatable { case forceBottom, softBottom, preserveTop }  // soft=바닥 근처일 때만
        let kind: Kind
        let key: String        // 스크롤 기준 메시지 key
        let token: UUID        // onChange 재발화용
    }
    struct State {
        var messages: [MessageItem] = []
        var message: String?          // 토스트
        var scrollCommand: ScrollCommand?
    }
    @Published var state: State
    @Published var inputMessage = ""
    let receiver: String?
    let isGroupChat: Bool
    let chatName: String
    var isChatAvailable: Bool         // receiver != nil && repository.isAvailable && uid 존재
    var navigationTitle: String       // chatName + (isGroupChat ? " 그룹채팅방" : "")
    init(receiver: String?, isGroupChat: Bool, chatName: String)  // 즉시 초기 로드(Android 미러)
    func fetchPreviousPage()
    func actionSend()
    func startObserving()             // ChatView onAppear
    func stopObserving()              // ChatView onDisappear
}
struct ChatView: View { init(receiver: String?, isGroupChat: Bool, chatName: String) }
struct MessageRow: View {
    // isMine: 우측 정렬. separated: 프로필+이름 표시(같은 분·같은 발신자 묶음의 첫 메시지).
    // showsTimestamp: 묶음 마지막에만 true — false면 자리 유지(opacity 0, Android INVISIBLE 미러)
    init(item: MessageItem, isMine: Bool, separated: Bool, showsTimestamp: Bool)
}
```

- [ ] **Step 1: Android 원본 정독** — `viewmodel/ChatViewModel.java`(fetchMessageList onSuccess 로직·ScrollEvent), `activity/ChatActivity.java`(스크롤 3종), `adapter/MessageListAdapter.java`(isSeparated/isTimestampVisible), `message_item_left.xml`/`message_item_right.xml`.
- [ ] **Step 2: ChatViewModel 커서 로직** — LIMIT=15, 필드 `private var cursor: String?`, `private var firstMessageKey: String?`, `private var hasRequestedMore = false`, `private var knownKeys = Set<String>()`(개선 2), `private var observerHandle: UInt?`. init에서 `isChatAvailable`이면 `fetchMessages(previousCount: 0, previousCursor: nil)`. `fetchPreviousPage()`: `!hasRequestedMore && cursor != nil`일 때만 — `hasRequestedMore = true; fetchMessages(previousCount: state.messages.count, previousCursor: cursor); cursor = nil`. onSuccess(Android 미러 + key 중복 제거):

```swift
let insertPosition = max(state.messages.count - previousCount, 0)
var addedCount = 0
var newCursor: String?
for item in fetched {                                   // key 오름차순
    if newCursor == nil { newCursor = item.key }        // 배치의 최고(最古) key
    if let first = firstMessageKey, first == item.key { continue }
    if firstMessageKey == nil { firstMessageKey = item.key }
    if item.key == previousCursor { continue }          // endAt inclusive 중복 제거
    if knownKeys.contains(item.key) { continue }        // 낙관적/childAdded 중복 제거(개선 2)
    knownKeys.insert(item.key)
    state.messages.insert(item, at: insertPosition + addedCount)
    addedCount += 1
}
hasRequestedMore = false
if let newCursor = newCursor { cursor = newCursor }
guard addedCount > 0 else { return }
if previousCount == 0, let last = state.messages.last {
    state.scrollCommand = ScrollCommand(kind: .forceBottom, key: last.key, token: UUID())
} else if state.messages.indices.contains(addedCount) {
    // Android scrollToPositionWithOffset(addedCount, 10) — 이전에 맨 위였던 메시지를 상단에 유지
    state.scrollCommand = ScrollCommand(kind: .preserveTop, key: state.messages[addedCount].key, token: UUID())
}
```

- [ ] **Step 3: startObserving/stopObserving/actionSend** — `startObserving()`: `observerHandle == nil`일 때만 `repository.observeNewMessages(..., afterKey: state.messages.last?.key)` — 콜백에서 `knownKeys` 중복이면 무시, 아니면 insert 후 append + `softBottom` 커맨드. `stopObserving()`: handle 있으면 `removeObserver`. `actionSend()`: trim 후 비면 토스트 "메시지를 입력하세요.", `receiver == nil`이면 "채팅 대상 정보가 없습니다.", `sendMessage` nil이면 "채팅을 사용할 수 없습니다.". 성공: knownKeys 등록+append+`forceBottom`+`inputMessage = ""`.
- [ ] **Step 4: MessageRow** — 스펙 §4.4: 좌측(상대) = `separated`일 때만 `RemoteImage(EndPoint.userImage(uid: item.from))` 41pt 원형+이름(13pt bold, `#777777` = `Color(red: 0.467, green: 0.467, blue: 0.467)`), 말풍선(흰 배경 라운드 8, 글자 `#434343` 16pt), 오른쪽에 타임스탬프(10pt secondary). 우측(나) = 프로필·이름 없음, 말풍선 accentColor 배경·흰 글씨, 타임스탬프가 말풍선 왼쪽. 타임스탬프 포맷은 파일 내 정적 포맷터:

```swift
private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale.current            // Android Locale.getDefault() 미러 — 한국어면 "오후 3:05"
    formatter.dateFormat = "a h:mm"
    return formatter
}()
static func timeStamp(_ millis: Int64) -> String {
    timeFormatter.string(from: Date(timeIntervalSince1970: TimeInterval(millis) / 1000))
}
```

  `showsTimestamp == false`면 `.opacity(0)`(자리 유지). `separated`면 상하 여백 10, 아니면 2(Android messageSeparated 미러).
- [ ] **Step 5: ChatView** — `!viewModel.isChatAvailable`이면 중앙 안내("채팅을 사용할 수 없습니다")+입력 바 `disabled`. 가용 시:
  - `ScrollViewReader { proxy in ScrollView { LazyVStack(spacing: 0) { ForEach(Array(messages.enumerated()), id: \.element.key) { ... } } } }` 배경 `Color(red: 0.957, green: 0.980, blue: 1.0)`(`#f4faff`).
  - separated/showsTimestamp 계산(Android 미러): `separated(at: i)` = `i == 0 || timeStamp(prev) != timeStamp(cur) || prev.from != cur.from`; `showsTimestamp(at: i)` = `i == count-1 || timeStamp(next) != timeStamp(cur) || next.from != cur.from`.
  - 최상단 로드: 첫 메시지 행 `onAppear` → `viewModel.fetchPreviousPage()`.
  - 바닥 근처 추적: `@State private var isNearBottom = true` — 마지막 메시지 행 `onAppear`에서 true, `onDisappear`에서 false.
  - `onChange(of: viewModel.state.scrollCommand)`: `forceBottom` → `proxy.scrollTo(key, anchor: .bottom)`, `softBottom` → `isNearBottom`일 때만 동일, `preserveTop` → `proxy.scrollTo(key, anchor: .top)`. forceBottom 초기 1회는 애니메이션 없이(`withAnimation` 미사용), 이후는 `withAnimation`.
  - 입력 바: `Divider` 위 HStack — `TextField("메시지를 입력하세요.", text: $viewModel.inputMessage)` + "전송" 버튼(입력 비면 `Color(uiColor: .secondarySystemBackground)` 배경·secondary 글씨, 있으면 accentColor·흰 글씨 — Android cv_btn_send 미러), 탭 → `viewModel.actionSend()`.
  - `.navigationTitle(viewModel.navigationTitle)`+`.navigationBarTitleDisplayMode(.inline)`+`.toast(message: $viewModel.state.message)`+`.onAppear { viewModel.startObserving() }`+`.onDisappear { viewModel.stopObserving() }`.
- [ ] **Step 6: pbxproj 등록 + 검증** — ID 176~181(Cell 그룹 포함), grep 4곳. `ScrollCommand` Equatable 충족(onChange 요건), `observeNewMessages` 시그니처가 Task 7과 일치하는지 grep 대조.
- [ ] **Step 7: 커밋** — `feat: add chat screen with realtime receive and pagination`

---

### Task 9: 채팅 진입점 배선 — 그룹 툴바 + 멤버 다이얼로그

**Files:**
- Modify: `YuMinigroup/View/GroupView.swift` (툴바 채팅 아이콘 + 숨김 NavigationLink)
- Modify: `YuMinigroup/View/UserDialogView.swift` ("메시지 보내기" 활성화)
- Modify: `YuMinigroup/ViewModel/UserViewModel.swift` (`isSelf` 추가)
- Modify: `YuMinigroup/View/Tab3View.swift` (시트 닫고 ChatView push)

**Interfaces:**
- Consumes: `ChatView(receiver:isGroupChat:chatName:)` (Task 8), `PreferenceManager.shared.user?.uid`
- Produces: `UserViewModel.isSelf: Bool`, `UserDialogView.init(viewModel:onSendMessage:)` — Tab3View 외 호출부 없음(1차 유일 호출부 확인됨)

- [ ] **Step 1: GroupView 툴바** — `@State private var showChat = false` 추가, body의 기존 수식어에 이어서:

```swift
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { showChat = true }) {
            Image(systemName: "bubble.left.and.bubble.right.fill")   // Android action_chat("채팅방") 대응
        }
    }
}
.background(
    NavigationLink(isActive: $showChat) {
        ChatView(receiver: viewModel.groupItem.key,   // 그룹 Firebase key — nil이면 ChatView가 안내 표시
                 isGroupChat: true,
                 chatName: viewModel.groupItem.name)
    } label: { EmptyView() }
    .hidden()
)
```

  틴트는 기존 `navigationBarTintColorCompat`를 따르므로 접힘/펼침 색 전환이 자동 적용됨을 확인.
- [ ] **Step 2: UserViewModel** — `var isSelf: Bool { PreferenceManager.shared.user?.uid == member.uid }` 추가(Android `UserViewModel.isAuth()` 미러).
- [ ] **Step 3: UserDialogView** — `let onSendMessage: () -> Void` 프로퍼티 추가. actionBar: `viewModel.isSelf`면 "메시지 보내기" 버튼 자체를 숨김(Android GONE 미러 — "닫기"만 전폭), 아니면 활성 버튼(“메시지 보내기”, `.foregroundColorCompat(.primary)`) 탭 → `onSendMessage()`. "(준비중)" 라벨·`disabled(true)`·헤더의 2차 연결점 코멘트 제거.
- [ ] **Step 4: Tab3View** — `@State private var chatTarget: MemberItem?` + `@State private var isChatActive = false` 추가. `.sheet(item:)` 내용: `UserDialogView(viewModel: UserViewModel(member: member), onSendMessage: { selectedMember = nil; chatTarget = member; DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isChatActive = true } })` — 시트 dismiss 애니메이션과 push 경합 회피(Task 6 handleCreated와 같은 관례). ZStack에 숨김 링크:

```swift
NavigationLink(isActive: $isChatActive) {
    if let chatTarget = chatTarget {
        ChatView(receiver: chatTarget.uid, isGroupChat: false, chatName: chatTarget.name)
    }
} label: { EmptyView() }
.hidden()
```

  (Tab3View는 GroupView→GroupMainView의 NavigationView 안에 있으므로 push 동작 — Android가 UserDialog에서 ChatActivity를 새로 여는 것의 미러. `value` extra는 SEND_MESSAGE dead code 전용이라 전달하지 않는다.)
- [ ] **Step 5: 검증** — grep: `onSendMessage` 정의·호출 짝, `UserDialogView(viewModel:` 호출부가 Tab3View 1곳뿐인지, `준비중` 문구 0건, `ChatView(receiver:` 호출 3형태(그룹 key/멤버 uid) 시그니처 일치.
- [ ] **Step 6: 커밋** — `feat: wire chat entry points (group toolbar + member dialog)`

---

### Task 10: 채팅방 목록(신설) — ChatListView + 드로어 메뉴

**Files:**
- Create: `YuMinigroup/View/ChatListView.swift`
- Create: `YuMinigroup/ViewModel/ChatListViewModel.swift`
- Modify: `YuMinigroup/Data/Remote/ChatRemoteDataSource.swift` (`fetchChatRooms` 추가)
- Modify: `YuMinigroup/Data/ChatRepository.swift` (패스스루)
- Modify: `YuMinigroup/ViewModel/MainViewModel.swift` (`MainRoute`에 `chatList` 추가 — `groupMain` 바로 다음)
- Modify: `YuMinigroup/View/MainView.swift` (타이틀 "채팅"/아이콘 `bubble.left.and.bubble.right.fill`/라우터 분기)
- Modify: `YuMinigroup.xcodeproj/project.pbxproj` (2파일 = ID 182~185)

**Interfaces:**
- Consumes: Task 7 데이터소스, `AppToolbar(title:navigationIcon:onNavigationClick:)`, `RemoteImage`, `MessageRow.timeStamp(_:)`(시각 표기 재사용)
- Produces:

```swift
struct ChatRoomItem: Identifiable, Hashable {   // ChatListViewModel.swift 파일 안에 선언(화면 전용 — Android에 없는 신설)
    var id: String { receiver }
    let receiver: String        // 그룹 Firebase key 또는 상대 uid
    let isGroupChat: Bool
    let title: String           // 그룹 이름 또는 상대 이름(모르면 uid)
    let imageURL: String?       // 그룹 이미지 or EndPoint.userImage(uid:)
    let preview: String?        // 마지막 메시지
    let timestamp: Int64?       // 마지막 메시지 시각(millis)
}
// ChatRemoteDataSource 추가(+Repository 패스스루)
func fetchChatRooms(currentUid: String, completion: @escaping (Result<[ChatRoomItem], Error>) -> Void)

final class ChatListViewModel: ObservableObject {
    struct State { var rooms: [ChatRoomItem] = []; var isLoading = false; var message: String? }
    @Published var state: State
    var isChatAvailable: Bool
    init()                       // 즉시 fetchRooms()
    func fetchRooms()
}
struct ChatListView: View { init(onMenuClick: @escaping () -> Void) }
```

- [ ] **Step 1: fetchChatRooms 구현** — 스펙 §3.6. `FirebaseRef.database()` nil 또는 uid 없음 → `.success([])`. DispatchGroup으로 두 갈래 병합:
  - **그룹채팅방**: `UserGroupList/{uid}` `queryOrderedByValue().queryEqual(toValue: true)` → 각 key마다 `Groups/{key}`에서 `name`/`image` 읽어 기본 room 생성 → 각각 `Messages/{key}.queryOrderedByKey().queryLimited(toLast: 1)`로 preview/timestamp 채움(없으면 nil 유지).
  - **1:1**: `Messages/{uid}` 전체 1회 조회 — 각 child(key=상대 uid)에서 children을 순회해 마지막 메시지(preview/timestamp)와, **뒤에서부터 `from != uid`인 첫 메시지의 `name`**을 상대 이름으로(최대 10건만 역순 탐색, 없으면 uid 표기 — 스펙 §3.6). `imageURL = EndPoint.userImage(uid: 상대uid)`.
  - 병합 후 정렬: `timestamp` 내림차순, nil은 뒤로 가되 이름 오름차순. `.success(rooms)`.
- [ ] **Step 2: ChatListViewModel + ChatListView** — VM은 위 Interfaces대로(로딩/실패 토스트). 뷰는 GroupMainView 관례 미러:

```swift
NavigationView {
    VStack(spacing: 0) {
        AppToolbar(title: "채팅", navigationIcon: .menu, onNavigationClick: onMenuClick)
        // isChatAvailable == false → 중앙 "채팅을 사용할 수 없습니다"
        // rooms 비고 !isLoading → 중앙 "대화가 없습니다."
        // 목록: List 대신 ScrollView+LazyVStack — 행: RemoteImage(48pt 원형(1:1)/라운드(그룹)) +
        //   VStack(title 15pt bold + preview 13pt secondary lineLimit(1)) + Spacer +
        //   timestamp(MessageRow.timeStamp, caption2 secondary)
        // 행 전체 = NavigationLink(destination: ChatView(receiver:isGroupChat:chatName: title))
    }
    .navigationBarHiddenCompat()
}
.navigationViewStyle(StackNavigationViewStyle())
.toast(message: $viewModel.state.message)
```

  `.refreshable { viewModel.fetchRooms() }` + 화면 재진입(onAppear) 시 `fetchRooms()`(1차 재진입 새로고침 관례).
- [ ] **Step 3: MainRoute/MainView** — `MainRoute`에 `case chatList`를 `groupMain` 바로 다음에 추가(CaseIterable 순서=드로어 순서). `MainView.title` → "채팅", `systemImage` → "bubble.left.and.bubble.right.fill", `MainContentRouter`에 `case .chatList: ChatListView(onMenuClick: onMenuClick)` 분기 추가.
- [ ] **Step 4: pbxproj 등록 + 검증** — ID 182~185, grep 4곳. `MainRoute.allCases` 소비처(MainView.title/systemImage switch)가 전 케이스를 다루는지(스위치 exhaustive — default 없는 switch면 컴파일 타임 보장, grep으로 case 수 6개 확인).
- [ ] **Step 5: 커밋** — `feat: add chat room list screen with drawer menu`

---

### Task 11: Mac 인수 체크리스트 갱신 + 최종 정합 스윕

**Files:**
- Modify: `docs/superpowers/plans/2026-08-26-mac-build-checklist.md`

**Interfaces:**
- Consumes: Task 1~10 전부 완료 상태
- Produces: 2차 검증 항목이 추가된 Mac 체크리스트(사용자 인수 문서)

- [ ] **Step 1: 체크리스트에 "2차 (second 브랜치)" 섹션 추가** — 항목:
  - 빌드: 신규 파일 17종 컴파일(최고위험: ChatRemoteDataSource의 Firebase 쿼리 시그니처 `queryStarting(atValue:)`/`queryEnding(atValue:)`/`runTransactionBlock`, GroupView 툴바+CollapsingHeader 공존)
  - 그룹찾기: 목록 파싱(실마크업 1순위 검증 — accordion 셀렉터), 페이징, 가입신청(자동/승인 각 1회) 후 Firebase `UserGroupList` 값 true/false 확인
  - 가입신청중: 승인대기 그룹만 노출, 신청취소 후 목록 갱신
  - 그룹 만들기: 이미지 없음/있음 각 1회(302 응답 경로), 생성 직후 새 그룹 화면 진입, LMS·Firebase 양쪽 등록 확인
  - 채팅: 그룹채팅/1:1 송수신, 두 기기 실시간 수신, 위로 스크롤 페이징, 재진입 시 중복 없음
  - 채팅 목록: 그룹방+1:1 노출·정렬, 미리보기
  - Firebase 미구성(plist 제거) 상태에서 각 화면 안내 문구 확인
- [ ] **Step 2: 최종 스윕** — ① `grep -rn "PlaceholderView(" YuMinigroup/View/ | grep -v "struct PlaceholderView"` 잔존이 MainView(univNotice/timetable/librarySeat/shuttleBus)와 Tab4View(공지사항)뿐인지(3차 이연분) ② `grep -c "\.swift" project.pbxproj` 증가분 = 신규 17파일 × 2(FileRef+BuildFile, ID 152~185) ③ iOS16 API 금지 grep 0건 ④ 신규 공개 시그니처를 태스크 Interfaces와 대조.
- [ ] **Step 3: 커밋** — `docs: add phase 2 items to mac build checklist`

---

## 태스크 밖(사용자 몫)

- Mac 빌드·실기기 검증(위 체크리스트), `GoogleService-Info.plist`(yuminigroup Firebase에 iOS 앱 추가) 확보, `second` 브랜치 병합·push.
