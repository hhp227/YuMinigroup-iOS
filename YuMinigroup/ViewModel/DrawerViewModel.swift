//
//  DrawerViewModel.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/12.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

class DrawerViewModel: ObservableObject {
    private let userDefaultsManager: UserDefaultsManager
    
    private var statusObserver = [AnyCancellable]()
    
    private(set) var status = [DrawerType: DrawerStatus]() {
        didSet {
            statusObserver.forEach { $0.cancel() }
            statusObserver.removeAll()
            status.forEach { info in
                let observer = info.value.objectDidChange.sink { s in
                    let maxRate = self.status.sorted { $0.value.showRate > $1.value.showRate }.first?.value.showRate ?? 0
                    
                    if self.maxShowRate == maxRate {
                        return
                    }
                    self.maxShowRate = maxRate
                }
                
                statusObserver.append(observer)
            }
        }
    }
    
    @Published
    private(set) var drawerView = [DrawerType: AnyView]()
    
    @Published
    private(set) var maxShowRate: CGFloat = .zero
    
    @Published
    var route = "Lounge"
    
    @Published
    var user: User? = nil
    
    public func setDrawer<V: DrawerViewProtocol>(view: V, widthType: DrawerWidth = .percent(rate: 0.8), shadowRadius: CGFloat = 10) {
        let status = DrawerStatus(type: view.type)
        status.maxWidth = widthType
        status.shadowRadius = shadowRadius
        self.status[view.type] = status
        self.drawerView[view.type] = AnyView(DrawerContainer(content: view, drawerModel: self))
    }
    
    public func show(type: DrawerType, isShow: Bool) {
        if self.status.first(where: { $0.value.currentStatus.isMoving }) != nil {
            return
        }
        self.status[type]?.currentStatus = isShow ? .show : .hide
    }
    
    public func hideAll() {
        self.status.forEach { $0.value.currentStatus = .hide }
    }
    
    func clear() {
        userDefaultsManager.storeUser(nil)
    }
    
    init(_ userDefaultsManager: UserDefaultsManager) {
        self.userDefaultsManager = userDefaultsManager
        
        userDefaultsManager.userPublisher
            .replaceError(with: user)
            .assign(to: \.user, on: self)
            .store(in: &statusObserver)
        setDrawer(view: DrawerView(type: .left), widthType: .percent(rate: 0.8), shadowRadius: 10)
    }
}
