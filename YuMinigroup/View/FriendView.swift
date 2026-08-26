//
//  FriendView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/10/20.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct FriendView: View {
    @StateObject
    var viewModel: FriendViewModel = InjectorUtils.instance.provideFriendViewModel()
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, FriendView!")
        }
        .padding()
    }
}

struct FriendView_Previews: PreviewProvider {
    static var previews: some View {
        FriendView()
    }
}
