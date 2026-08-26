//
//  GroupGridCell.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/05/11.
//  Copyright © 2022 홍희표. All rights reserved.
//

import SwiftUI

struct GroupGridCell: View {
    @State
    private var isNavigate = false
    
    let group: GroupItem
    
    var body: some View {
        Button(action: { isNavigate.toggle() }) {
            Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
        }
        .navigationDestination(isPresented: $isNavigate) {
            GroupDetailView()
        }
    }
}

struct GroupGridCell_Previews: PreviewProvider {
    static var previews: some View {
        GroupGridCell(group: .init(id: 0, authorId: 0, joinType: 0))
    }
}
