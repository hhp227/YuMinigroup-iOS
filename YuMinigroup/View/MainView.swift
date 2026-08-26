//
//  MainView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/07/29.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct MainView: View {
    @StateObject
    private var drawerViewModel: DrawerViewModel = InjectorUtils.instance.provideDrawerViewModel()
    
    private static let MAX_MASK_ALPHA: CGFloat = 0.25
    
    var body: some View {
        ZStack {
            NavigationStack {
                switch drawerViewModel.route {
                case "Lounge":
                    LoungeView()
                        .navigationTitle("Lounge")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarItems(leading: Button(action: { drawerViewModel.show(type: .left, isShow: true) }) {
                            Image("hamburger-menu-icon").colorMultiply(.accentColor)
                        })
                case "GroupList":
                    GroupListView()
                        .navigationBarItems(leading: Button(action: { drawerViewModel.show(type: .left, isShow: true) }) {
                            Image("hamburger-menu-icon").colorMultiply(.accentColor)
                        })
                case "FriendList":
                    FriendView()
                        .navigationBarItems(leading: Button(action: { drawerViewModel.show(type: .left, isShow: true) }) {
                            Image("hamburger-menu-icon").colorMultiply(.accentColor)
                        })
                case "ChatList":
                    ChatListView()
                        .navigationBarItems(leading: Button(action: { drawerViewModel.show(type: .left, isShow: true) }) {
                            Image("hamburger-menu-icon").colorMultiply(.accentColor)
                        })
                case "Logout":
                    let _ = drawerViewModel.clear()
                default:
                    EmptyView()
                }
            }
            Color.black
                .opacity(Double(drawerViewModel.maxShowRate * MainView.MAX_MASK_ALPHA))
                .onTapGesture(perform: drawerViewModel.hideAll)
                .ignoresSafeArea()
            drawerViewModel.drawerView[.left]
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
