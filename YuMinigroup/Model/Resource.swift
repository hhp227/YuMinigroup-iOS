//
//  Resource.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/11/08.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation

struct Resource<T> {
    let status: Status
    
    let data: T?
    
    let message: String?
    
    static func success(_ data: T?) -> Resource {
        return Resource(status: .SUCCESS, data: data, message: nil)
    }
    
    static func error(_ msg: String, _ data: T?) -> Resource {
        return Resource(status: .ERROR, data: data, message: msg)
    }
    
    static func loading(_ data: T?) -> Resource {
        return Resource(status: .LOADING, data: data, message: nil)
    }
    
    enum Status {
        case SUCCESS
        case ERROR
        case LOADING
    }
}
