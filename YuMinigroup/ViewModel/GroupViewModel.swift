//
//  GroupViewModel.swift
//  YuMinigroup
//
//  Android TabHostLayoutFragment(newInstance 인자: admin/grp_id/grp_nm/grp_img/key) 대응 — 그룹 상세
//  화면(GroupView)의 화면 상태만 들고 있는 얇은 VM이다. Android는 액티비티/프래그먼트 인자 번들로
//  그룹 정보를 넘기지만, iOS는 NavigationLink 목적지를 만들 때 GroupMainView가 이미 들고 있는
//  GroupItem 값을 그대로 물려받는다(재조회 없음 — Android도 넘겨받은 인자를 그대로 쓸 뿐 그룹
//  상세를 다시 조회하지 않는 것과 동일).
//
//  selectedTab/collapseOffset/탭별 scrollOffset 4개는 CollapsingListScaffold(Task 2 일반화판)가
//  쓰는 순수 UI 상태다. 탭 바디는 아직 스켈레톤(Text 자리)이라 실제 리스트 스크롤은 없지만,
//  Task 12~15가 각 탭을 실구현으로 교체할 때 그대로 이어 쓸 수 있도록 지금부터 4개를 나눠 둔다
//  (참고: ParallaxTabScreen 예제도 탭 개수만큼 firstTabScrollOffset/secondTabScrollOffset을 따로
//  든다 — 여기서는 탭이 4개라 tab1~tab4로 확장했다).
//
//  hasCoverPhoto는 Android "!mGroupImage.contains(share_nophoto)" 분기 그대로("경북대 소모임에는
//  없음" 주석이 달린, 영남대 전용 로직) — true면 커버 사진 모드(그라디언트 스크림), false면
//  로고 모드로 GroupView가 헤더 배경을 분기한다.
//

import SwiftUI

final class GroupViewModel: ObservableObject {
    let groupItem: GroupItem

    // Android res/values/arrays.xml tab_names 배열 그대로(순서 고정: 소식/일정/맴버/설정).
    let tabTitles = ["소식", "일정", "맴버", "설정"]

    @Published var selectedTab = 0
    @Published var collapseOffset: CGFloat = 0

    // 탭 인덱스 0~3(소식/일정/맴버/설정) 각각의 스크롤 오프셋 — 탭 전환 시 강제 collapse 판단에 쓰인다.
    @Published var tab1ScrollOffset: CGFloat = 0
    @Published var tab2ScrollOffset: CGFloat = 0
    @Published var tab3ScrollOffset: CGFloat = 0
    @Published var tab4ScrollOffset: CGFloat = 0

    var hasCoverPhoto: Bool {
        !groupItem.image.contains("share_nophoto")
    }

    init(groupItem: GroupItem) {
        self.groupItem = groupItem
    }
}
