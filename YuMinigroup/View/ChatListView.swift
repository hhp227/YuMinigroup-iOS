//
//  ChatListView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/09/23.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct ChatListView: View {
    @StateObject
    var viewModel: ChatListViewModel = InjectorUtils.provideChatListViewModel(InjectorUtils.instance)()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, ChatListView!")
        }
        .padding()
    }
}

struct ChatListView_Previews: PreviewProvider {
    static var previews: some View {
        ChatListView()
    }
}
