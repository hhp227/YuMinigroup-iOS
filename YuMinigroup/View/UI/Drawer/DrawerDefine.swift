//
//  DrawerDefine.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/12.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import SwiftUI

public enum DrawerType {
    case left
    case right
    case none
    
    var isLeft: Bool {
        return self == .left
    }
}

public enum DrawerWidth {
    case width(value: CGFloat)
    case percent(rate: CGFloat)
}

public enum ShowStatus {
    case show
    case hide
    case moving(offset: CGFloat)
    
    var isMoving: Bool {
        switch self {
        case .moving(_):
            return true
        default:
            return false
        }
    }
}

public protocol DrawerProtocol {
    var type: DrawerType { get }
    
    init(type: DrawerType)
}

public typealias DrawerViewProtocol = (View & DrawerProtocol)
