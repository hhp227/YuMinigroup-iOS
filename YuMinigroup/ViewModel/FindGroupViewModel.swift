//
//  FindGroupViewModel.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/09/25.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import Combine

class FindGroupViewModel: ObservableObject {
    let groupRepository: GroupRepository
    
    init(_ groupRepository: GroupRepository,  _ userDefaultsManager: UserDefaultsManager) {
        self.groupRepository = groupRepository
    }
    
    struct State {
        var isLoading: Bool = false
        
        var pagingData: PagingData<GroupItem>? = PagingData<GroupItem>.empty()
        
        var message: String = ""
        
        var subscriptions: Set<AnyCancellable> = []
    }
}

extension FindGroupViewModel.State {
    func copy(
        isLoading: Bool? = nil,
        pagingData: PagingData<GroupItem>? = nil,
        message: String? = nil,
        subscriptions: Set<AnyCancellable>? = nil
    ) -> FindGroupViewModel.State {
        .init(
            isLoading: isLoading ?? self.isLoading,
            pagingData: pagingData ?? self.pagingData,
            message: message ?? self.message,
            subscriptions: subscriptions ?? self.subscriptions
        )
    }
}
