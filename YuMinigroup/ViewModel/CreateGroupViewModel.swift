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
//  있으면 그 자리에서 바로 addGroup을 호출한다 — Android가 검증 통과 경로에서 에러 라이브데이터를
//  건드리지 않는 것(EditText가 재입력 시 자체적으로 에러 표시를 지우는 플랫폼 동작에 기대는 것)까지
//  바이트 수준으로 옮긴 것(브리프 Step 2 그대로).
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
