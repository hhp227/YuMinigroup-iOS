//
//  JoinRequestGroupView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/31.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct JoinRequestGroupView: View {
    @StateObject
    var viewModel = InjectorUtils.instance.provideJoinRequestGroupViewModel()
    
    var body: some View {
        List {
            Image("image3")
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipped()
                .listRowInsets(EdgeInsets())
            ForEach(["Item1", "Item2", "Item3"], id: \.self) { item in
                Text(item)
            }
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.inset)
    }
}

struct JoinRequestGroupView_Previews: PreviewProvider {
    static var previews: some View {
        JoinRequestGroupView()
    }
}
