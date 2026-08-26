//
//  InjectorUtils.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/03/18.
//  Copyright © 2022 홍희표. All rights reserved.
//

import Foundation
import SwiftUI

class InjectorUtils {
    private func getGroupService() -> GroupService {
        return GroupServiceImpl()
    }
    
    private func getAuthService() -> AuthService {
        return AuthServiceImpl()
    }
    
    private func getPostService() -> PostService {
        return PostServiceImpl.init()
    }
    
    private func getReplyService() -> ReplyService {
        return ReplyServiceImpl()
    }
    
    private func getApiService() -> ApiService {
        return ApiServiceImpl.init()
    }
    
    func getUserDefaultsManager() -> UserDefaultsManager {
        return UserDefaultsManager.instance
    }
    
    private func getGroupRepository() -> GroupRepository {
        return GroupRepository.getInstance(groupService: getGroupService())
    }
    
    private func getPostRepository() -> PostRepository {
        return PostRepository.getInstance(postService: getPostService())
    }
    
    private func getReplyRepository() -> ReplyRepository {
        return ReplyRepository.getInstance(replyService: getReplyService())
    }
    
    private func getUserRepository() -> UserRepository {
        return UserRepository.getInstance(authService: getAuthService())
    }
    
    func provideLoginViewModel() -> LoginViewModel {
        return LoginViewModel(getUserRepository(), getUserDefaultsManager())
    }
    
    func provideRegisterViewModel() -> RegisterViewModel {
        return RegisterViewModel(getUserRepository())
    }
    
    func provideContentViewModel() -> ContentViewModel {
        return ContentViewModel(getUserDefaultsManager())
    }
    
    func provideDrawerViewModel() -> DrawerViewModel {
        return DrawerViewModel(getUserDefaultsManager())
    }
    
    func provideLoungeViewModel() -> LoungeViewModel {
        return LoungeViewModel(getPostRepository(), getUserDefaultsManager())
    }
    
    func provideCreatePostViewModel(type: Int, groupId: Int, post: PostItem? = nil) -> CreatePostViewModel {
        let savedStatedHandle = SavedStateHandle()
        
        savedStatedHandle.set(TYPE_KEY, type)
        savedStatedHandle.set(GROUP_ID_KEY, groupId)
        savedStatedHandle.set(POST_KEY, post)
        return CreatePostViewModel(getPostRepository(), getUserDefaultsManager(), savedStatedHandle)
    }
    
    func provideGroupListViewModel() -> GroupListViewModel {
        return GroupListViewModel()
    }
    
    func provideFindGroupViewModel() -> FindGroupViewModel {
        return FindGroupViewModel(getGroupRepository(), getUserDefaultsManager())
    }
    
    func provideJoinRequestGroupViewModel() -> JoinRequestGroupViewModel {
        return JoinRequestGroupViewModel()
    }
    
    func provideCreateGroupViewModel() -> CreateGroupViewModel {
        return CreateGroupViewModel()
    }
    
    func provideFriendViewModel() -> FriendViewModel {
        return FriendViewModel()
    }
    
    func provideChatListViewModel() -> ChatListViewModel {
        return ChatListViewModel()
    }
    
    func providePostDetailViewModel(_ post: Binding<PostItem>) -> PostDetailViewModel {
        let savedStatedHandle = SavedStateHandle()

        savedStatedHandle.set(POST_KEY, post)
        return PostDetailViewModel(getPostRepository(), getReplyRepository(), savedStatedHandle, getUserDefaultsManager())
    }
    
    func proviteUpdateReplyViewModel(_ reply: Binding<ReplyItem>) -> UpdateReplyViewModel {
        let savedStatedHandle = SavedStateHandle()

        savedStatedHandle.set(REPLY_KEY, reply)
        return UpdateReplyViewModel(getReplyRepository(), getUserDefaultsManager(), savedStatedHandle)
    }
    
    static var instance = InjectorUtils.init()
}
