//
//  DrawerStatus.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/12.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

public class DrawerStatus: ObservableObject {
    public let objectDidChange = PassthroughSubject<DrawerStatus, Never>()
    
    public var currentStatus: ShowStatus = .hide {
        didSet {
            switch currentStatus {
            case .hide:
                showRate = 0
            case .show:
                showRate = 1
            case .moving(let offset):
                let width = parentSize.width / 2
                
                if self.type.isLeft {
                    showRate = (width + offset) / width
                } else {
                    showRate = (width - offset) / width
                }
            }
            objectDidChange.send(self)
        }
    }
    
    public var type: DrawerType {
        didSet {
            objectDidChange.send(self)
        }
    }
    
    var parentSize = CGSize.zero
    
    var drawerWidth: CGFloat {
        get {
            switch self.maxWidth {
            case .percent(let rate):
                return parentSize.width * rate
            case .width(let value):
                return value
            }
        }
    }
    
    var shadowRadius: CGFloat = 0
    
    var showRate: CGFloat = 0
    
    var maxWidth: DrawerWidth = .percent(rate: 0.5) {
        didSet {
            objectDidChange.send(self)
        }
    }
    
    func drawerOffset() -> CGFloat {
        if self.type == .none {
            return 0
        }
        switch currentStatus {
        case .hide:
            return self.type.isLeft ? -parentSize.width : parentSize.width
        case .moving(let offset):
            return self.type.isLeft ? offset : parentSize.width - drawerWidth + offset
        case .show:
            return self.type.isLeft ? 0 : parentSize.width - drawerWidth
        }
    }
    
    init(type: DrawerType) {
        self.type = type
    }
}
