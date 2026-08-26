//
//  ImageItem.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/30.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation

struct ImageItem: Codable, Identifiable, ListItem {
    var id: Int = 0
    
    var image: String = ""
    
    var tag: String = ""
    
    var data: Data? = nil
}
