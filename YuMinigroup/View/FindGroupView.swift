//
//  GroupFindView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/31.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct FindGroupView: View {
    @StateObject
    var viewModel = InjectorUtils.instance.provideFindGroupViewModel()
    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

struct FindGroupView_Previews: PreviewProvider {
    static var previews: some View {
        FindGroupView()
    }
}
