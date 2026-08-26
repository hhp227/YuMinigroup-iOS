//
//  GroupRepository.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/09/24.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation

class GroupRepository {
    private let groupService: GroupService
    
    func getGroups() {
        // TODO
    }
    
    func requestToJoinOrCancel() {
        // TODO
    }
    
    func addGroupImage() {
        // TODO
    }
    
    func addGroup() {
        // TODO
    }
    
    func removeGroup() {
        // TODO
    }
    
    // TODO clearCache
    
    init(_ groupService: GroupService) {
        self.groupService = groupService
    }
    
    private static var instance: GroupRepository? = nil
    
    static func getInstance(groupService: GroupService) -> GroupRepository {
        if let instance = self.instance {
            return instance
        } else {
            let groupRepository = GroupRepository(groupService)
            self.instance = groupRepository
            return groupRepository
        }
    }
}
