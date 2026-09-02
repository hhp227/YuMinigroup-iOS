//
//  CreateGroupViewModel.swift
//  YuMinigroup
//
//  Android viewmodel.CreateGroupViewModel(+data.GroupRepository.addGroup) 대응 — 그룹 생성 화면의
//  상태와 전송 로직. Android createGroup(title, description)을 그대로 미러한다:
//
//      if (!title.isEmpty() && !description.isEmpty()) {
//          addGroup(...)
//      } else {
//          titleError = title.isEmpty() ? "그룹명을 입력하세요." : null;
//          descriptionError = description.isEmpty() ? "그룹설명을 입력하세요." : null;
//      }
//
//  즉 검증 실패 분기에서만 titleError/descriptionError를 세팅하고(비지 않은 쪽은 nil로 리셋), 둘 다
//  있으면 addGroup 호출 전에 두 에러를 모두 nil로 클리어한다 — Android는 EditText가 재입력 시 자체
//  적으로 에러 표시를 지우는 플랫폼 동작에 기대 이 클리어가 없어도 되지만, SwiftUI에는 그런 자동
//  동작이 없어 그대로 두면 "검증 실패 → 재입력 → addGroup 실패"로 이어질 때 유효한 필드 옆에 옛
//  캡션이 재노출된다(리뷰 수정 — 브리프 의사코드의 공백, 스펙과 충돌 없음).
//
//  joinType은 Android RadioGroup(rb_auto 기본 checked)의 Boolean 미러로 isAutoJoin(Bool, 기본 true)을
//  두고, addGroup 호출 시 Android와 동일하게 "0"(자동 승인)/"1"(승인 확인) 문자열로 변환한다.
//

import UIKit

final class CreateGroupViewModel: ObservableObject {
    struct State {
        var isLoading = false
        var message: String?
        var titleError: String?
        var descriptionError: String?
        var created: GroupItem?     // 성공 시 세팅 — 뷰가 onChange로 감지
    }

    @Published var state = State()
    @Published var title = ""
    @Published var descriptionText = ""      // description은 CustomStringConvertible과 충돌 여지 — 이 이름 고정
    @Published var isAutoJoin = true         // Android joinType 기본 true(자동 승인)
    @Published var image: UIImage?

    private let repository: GroupRepository

    init(repository: GroupRepository = GroupRepository()) {
        self.repository = repository
    }

    // Android CreateGroupViewModel.createGroup(title, description) 대응.
    func createGroup() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedTitle.isEmpty, !trimmedDescription.isEmpty else {
            state.titleError = trimmedTitle.isEmpty ? "그룹명을 입력하세요." : nil
            state.descriptionError = trimmedDescription.isEmpty ? "그룹설명을 입력하세요." : nil
            return
        }
        // 재시도 경로: 이전 검증 실패로 남아있던 캡션이 addGroup 실패 후에도 다시 보이지 않도록 클리어.
        state.titleError = nil
        state.descriptionError = nil
        repository.addGroup(title: trimmedTitle, description: trimmedDescription, joinType: isAutoJoin ? "0" : "1", image: image) { [weak self] resource in
            guard let self = self else {
                return
            }
            switch resource {
            case .loading:
                self.state.isLoading = true
            case .success(let value):
                self.state.isLoading = false
                self.state.created = value.group
            case .error(let message, _):
                self.state.isLoading = false
                self.state.message = message
            }
        }
    }
}
