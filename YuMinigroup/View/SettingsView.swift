//
//  SettingsView.swift
//  YuMinigroup
//
//  Android activity/SettingsActivity(activity_settings.xml: Toolbar+TabLayout+ViewPager) 대응 — Tab4View
//  "설정" 행(admin 전용)이 push하는 그룹 설정 화면. GroupMainView가 이미 로컬 NavigationView를 열어
//  두었으므로(CreateGroupView/FindGroupView와 동일한 전제) 이 화면 자체는 새 NavigationView를 열지
//  않고 시스템 백 버튼에 기댄다.
//
//  탭 바는 TimetableView.swift(스펙 §4.2, Task 4)의 accentColor 배경 + 흰 텍스트 + 흰 밑줄 인디케이터
//  커스텀 HStack 관례를 그대로 재사용한다 — GroupView의 콜랩싱 탭 킷은 CollapsingToolbar 전용이라 이
//  화면(콜랩싱 헤더 없음)엔 재사용할 수 없다는 동일한 이유다. 탭 순서는 Android TAB_NAMES 배열
//  ["회원관리", "모임정보"] verbatim(SettingsActivity.java:25) — 반대로 두면 안 된다.
//
//  두 탭 VM(MemberManagementViewModel/DefaultSettingViewModel)은 groupItem.id/key/image로 이 화면
//  init에서 한 번만 만들어 @StateObject로 붙잡아 둔다(Android FragmentPagerAdapter의
//  BEHAVIOR_RESUME_ONLY_CURRENT_FRAGMENT가 두 프래그먼트를 모두 미리 만들어 두는 것과 동일하게, 탭을
//  오가도 회원 목록/폼 입력이 유지된다 — TimetableView의 MockTimetableTab과 달리 탭 전환 시 뷰 자체가
//  트리에서 빠지지 않으므로 상태가 살아있다).
//
//  onUpdated는 DefaultSettingView 저장 성공 시 그대로 통과시키는 콜백이다(Tab4View → GroupView →
//  GroupViewModel.applyGroupUpdate 순으로 전파, 브리프 Step 6). pop 자체는 DefaultSettingView가
//  presentationMode로 직접 수행한다(DefaultSettingView.swift 헤더 코멘트 참고) — 이 화면은 그 pop을
//  스레딩할 필요가 없다.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var memberManagementViewModel: MemberManagementViewModel
    @StateObject private var defaultSettingViewModel: DefaultSettingViewModel

    @State private var selectedTab = 0

    let onUpdated: (_ name: String, _ description: String, _ joinType: String, _ imageURL: String?) -> Void

    private static let tabTitles = ["회원관리", "모임정보"]

    init(groupItem: GroupItem, onUpdated: @escaping (_ name: String, _ description: String, _ joinType: String, _ imageURL: String?) -> Void) {
        _memberManagementViewModel = StateObject(wrappedValue: MemberManagementViewModel(groupId: groupItem.id))
        _defaultSettingViewModel = StateObject(wrappedValue: DefaultSettingViewModel(groupId: groupItem.id,
                                                                                      groupKey: groupItem.key,
                                                                                      existingImageURL: groupItem.image))
        self.onUpdated = onUpdated
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            if selectedTab == 0 {
                MemberManagementView(viewModel: memberManagementViewModel)
            } else {
                DefaultSettingView(viewModel: defaultSettingViewModel, onUpdated: onUpdated)
            }
        }
        .navigationTitle("소모임 설정")
        .navigationBarTitleDisplayMode(.inline)
    }

    // TimetableView.tabBar와 동일한 구성(accentColor 배경, 선택 탭 굵게+흰 밑줄).
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(Array(SettingsView.tabTitles.enumerated()), id: \.offset) { index, title in
                Button(action: { selectedTab = index }) {
                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 14, weight: selectedTab == index ? .bold : .regular))
                            .foregroundColorCompat(Color.white)
                            .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(selectedTab == index ? Color.white : Color.clear)
                            .frame(height: 2)
                    }
                }
                .padding(.top, 12)
            }
        }
        .background(Color.accentColor)
    }
}
