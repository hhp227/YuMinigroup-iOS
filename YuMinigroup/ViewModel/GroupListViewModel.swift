//
//  GroupListViewModel.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/09/24.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation

class GroupListViewModel: ObservableObject {
    @Published
    private(set) var state = State()
    
    func fetchGroups(_ offset: Int) {
    }
    
    struct State {
        var isLoading: Bool = false
        
        var groups: [GroupItem] = [GroupItem(id: 0, authorId: 0, joinType: 0), GroupItem(id: 1, authorId: 1, joinType: 0), GroupItem(id: 2, authorId: 2, joinType: 0), GroupItem(id: 3, authorId: 3, joinType: 0), GroupItem(id: 4, authorId: 4, joinType: 0)]
        
        var offset: Int = 0
        
        var canLoadNextPage = true
        
        var message: String = ""
    }
}
