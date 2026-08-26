//
//  ContentView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2020/05/17.
//  Copyright © 2020 홍희표. All rights reserved.
//

import Foundation
import Combine

class ContentViewModel: ObservableObject {
    @Published
    var user: User? = nil
    
    init(_ userDefaultManager: UserDefaultsManager) {
        userDefaultManager.userPublisher
            .catch { error in
                Just(nil)
            }
            .assign(to: &$user)
    }
}
