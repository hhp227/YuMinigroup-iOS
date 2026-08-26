//
//  CreateGroupViewModel.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/10/17.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation

class CreateGroupViewModel: ObservableObject {
    @Published
    var state = State()
    
    func createGroup() {
        print("createGroup")
    }
    
    struct State {
        var title: String = ""
        
        var description: String = ""
       
        let isLoading: Bool = false
        
        let message: String = ""
    }
}
