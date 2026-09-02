//
//  DefaultSettingViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.DefaultSettingViewModel 대응 — 그룹 설정 "모임정보" 탭의 상태. CreateGroupViewModel과
//  같은 title/descriptionText/isAutoJoin/image 필드 구성이지만, 이 화면은 빈 폼이 아니라
//  fetchGroupSetting으로 서버 값을 프리필한 뒤 수정한다는 점이 다르다 — existingImageURL은
//  fetchGroupSetting 응답에 없는 필드라(스펙 §5.4는 이름/설명/joinType만 파싱한다) SettingsView가
//  생성 시점에 groupItem.image를 그대로 넘겨준다(브리프 "기존 이미지 URL은 groupItem.image").
//
//  updateGroup()의 검증 문구("그룹이름을 입력하세요."/"그룹설명을 입력하세요.")는 Android
//  DefaultSettingViewModel.updateGroup(:103)과 글자 하나까지 동일하다 — CreateGroupViewModel의
//  "그룹명을 입력하세요."와는 다른 문구이므로 그대로 복붙하지 않는다(브리프가 명시적으로 못박은 값).
//  CreateGroupViewModel과 같은 이유로 검증 실패 후 재시도 시 스테일 캡션이 남지 않도록 updateGroup()
//  진입(검증 통과) 직후 titleError/descriptionError를 항상 nil로 클리어한다.
//
//  성공 시 message와 updated를 함께(동기) 세팅한다 — DefaultSettingView가 이 둘을 각각 다른 용도로
//  쓴다: message는 .toast가 즉시 그리고("소모임 변경 완료"), updated는 onChange가 감지해 1.2초 뒤
//  pop+onUpdated(...) 콜백을 부른다(FindGroupView "Toast 생존 관례" — 토스트 표시가 pop보다 먼저
//  시작돼야 pop 이후에도 일부 노출 시간이 남는다). updated를 Optional 튜플이 아니라 Equatable
//  struct(UpdatedGroupSetting)로 감싸는 이유는 SwiftUI onChange(of:)가 Equatable 제네릭 제약을 요구해
//  튜플을 직접 못 받기 때문이다(CreateGroupViewModel.state.created가 GroupItem이라는 이미 Hashable한
//  타입이라 이 문제가 없었던 것과 대비).
//

import UIKit

final class DefaultSettingViewModel: ObservableObject {
    // GroupRepository.updateGroup의 성공 튜플을 그대로 옮겨 담는 Equatable 래퍼(onChange(of:) 제약).
    struct UpdatedGroupSetting: Equatable {
        let name: String
        let description: String
        let joinType: String
        let imageURL: String?
    }

    struct State {
        var isLoading = false
        var message: String?
        var titleError: String?
        var descriptionError: String?
        var updated: UpdatedGroupSetting?
    }

    @Published var state = State()
    @Published var title = ""
    @Published var descriptionText = ""
    @Published var isAutoJoin = true
    @Published var image: UIImage?

    // imageArea가 새로 선택된 image가 nil일 때 대신 보여줄 기존 그룹 이미지(쿠키 로딩, RemoteImage).
    let existingImageURL: String?

    private let groupId: String
    private let groupKey: String?
    private let repository: GroupRepository

    init(groupId: String, groupKey: String?, existingImageURL: String?, repository: GroupRepository = GroupRepository()) {
        self.groupId = groupId
        self.groupKey = groupKey
        self.existingImageURL = existingImageURL
        self.repository = repository
        loadGroupSetting()
    }

    // Android setGroup/getGroup 호출부의 loadGroupSetting(:131) 대응 — 이름/설명/joinType 프리필.
    private func loadGroupSetting() {
        repository.fetchGroupSetting(groupId: groupId) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let setting):
                self.state.isLoading = false
                self.title = setting.name
                self.descriptionText = setting.description
                self.isAutoJoin = setting.joinType == "0"
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }

    // Android DefaultSettingViewModel.updateGroup(title, description)(:103) 대응.
    func updateGroup() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedDescription.isEmpty else {
            state.titleError = trimmedTitle.isEmpty ? "그룹이름을 입력하세요." : nil
            state.descriptionError = trimmedDescription.isEmpty ? "그룹설명을 입력하세요." : nil
            return
        }
        // 재시도 경로: CreateGroupViewModel과 동일한 이유로 updateGroup 호출 전 옛 캡션을 클리어한다.
        state.titleError = nil
        state.descriptionError = nil
        repository.updateGroup(groupId: groupId,
                                key: groupKey,
                                title: trimmedTitle,
                                description: trimmedDescription,
                                joinType: isAutoJoin ? "0" : "1",
                                image: image) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let value):
                self.state.isLoading = false
                self.state.message = "소모임 변경 완료"
                self.state.updated = UpdatedGroupSetting(name: value.name,
                                                           description: value.description,
                                                           joinType: value.joinType,
                                                           imageURL: value.imageURL)
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }
}
