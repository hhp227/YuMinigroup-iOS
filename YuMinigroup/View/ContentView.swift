//
//  ContentView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2020/05/17.
//  Copyright © 2020 홍희표. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @StateObject
    var viewModel: ContentViewModel = InjectorUtils.instance.provideContentViewModel()
    
    var body: some View {
        if viewModel.user != nil {
            MainView()
        } else {
            LoginView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
