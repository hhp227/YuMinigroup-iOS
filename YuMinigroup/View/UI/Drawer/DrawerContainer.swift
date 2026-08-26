//
//  DrawerContainer.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/12.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI
import Combine

struct DrawerContainer<Content: DrawerViewProtocol>: View {
    @ObservedObject
    public var viewModel: DrawerViewModel
    
    @ObservedObject
    private var status: DrawerStatus
    
    let drawer: AnyView
    
    let type: DrawerType
    
    var body: some View {
        GeometryReader { proxy in
            self.generateBody(proxy: proxy)
        }
    }
    
    func generateBody(proxy: GeometryProxy) -> some View {
        self.status.parentSize = proxy.size
        
        switch self.status.type {
        case .left, .right:
            let view = ZStack {
                AnyView(Color.white).frame(maxWidth: self.status.drawerWidth).padding(EdgeInsets(top: -proxy.safeAreaInsets.top, leading: 0, bottom: -proxy.safeAreaInsets.bottom, trailing: 0))
                self.drawer.frame(maxWidth: self.status.drawerWidth)
            }.shadow(radius: self.status.showRate > 0 ? self.status.shadowRadius : 0).offset(x: self.status.drawerOffset(), y: 0).gesture(DragGesture().onChanged { value in
                if self.status.type.isLeft && value.translation.width < 0 {
                    self.status.currentStatus = .moving(offset: value.translation.width)
                } else if !self.status.type.isLeft && value.translation.width > 0 {
                    self.status.currentStatus = .moving(offset: value.translation.width)
                }
            }.onEnded { value in
                if self.status.type.isLeft {
                    let sliderW = self.status.drawerWidth / 2
                    self.status.currentStatus = value.location.x < sliderW ? .hide : .show
                } else {
                    let sliderW = proxy.size.width - self.status.drawerWidth / 2
                    self.status.currentStatus = value.location.x > sliderW ? .hide : .show
                }
            }).animation(.default)
            return AnyView.init(view)
        case .none:
            return AnyView(EmptyView())
        }
    }
    
    init(content: Content, drawerModel: DrawerViewModel) {
        self.drawer = AnyView.init(content.environmentObject(drawerModel))
        self.type = content.type
        self.viewModel = drawerModel
        self.status = drawerModel.status[content.type]!
    }
}

struct DrawerContainer_Previews: PreviewProvider {
    static var previews: some View {
        DrawerContainer(content: PreviewDrawer.init(type: .left), drawerModel: DrawerViewModel(.instance))
    }
    
    public struct PreviewDrawer: View, DrawerProtocol {
        public let type: DrawerType
        
        public var body: some View {
            Text("Slider")
        }
        
        public init(type: DrawerType) {
            self.type = type
        }
    }
}
