//
//  CollapsingNavigationBarView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/16.
//

import SwiftUI

struct CollapsingNavigationBarView<Header: View, Content: View>: View {
    @State
    private var navigationBarHeight: CGFloat = 0

    @State
    private var scrollOffset: CGPoint = .zero
    
    private let axes: Axis.Set = .vertical
    
    private var headerVisibleRatio: CGFloat {
        (headerHeight + scrollOffset.y) / headerHeight
    }
    
    let headerHeight: CGFloat
    
    let headerMinHeight: CGFloat? = nil
    
    let onScroll: ((CGPoint, CGFloat) -> Void)?
    
    /*@State var offset: CGFloat = 0
    
    let maxHeight = UIScreen.main.bounds.height / 2.5
    
    let scrollUpBehavior: ScrollUpHeaderBehavior
    
    let scrollDownBehavior: ScrollDownHeaderBehavior*/
    
    var header: () -> Header
    
    var content: () -> Content
    
    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                ScrollView(axes, showsIndicators: true) {
                    ZStack(alignment: .top) {
                        ScrollViewOffsetTracker()
                        VStack(spacing: 0) {
                            scrollHeader
                            content()
                        }
                    }
                }
                .withOffsetTracking(action: handleScrollOffset)
                .onAppear {
                    DispatchQueue.main.async {
                        navigationBarHeight = proxy.safeAreaInsets.top
                    }
                }
            }
            navbarOverlay
        }
        .prefersNavigationBarHidden()
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    @ViewBuilder
    var navbarOverlay: some View {
        if headerVisibleRatio <= 0 {
            Color.clear
                .frame(height: navigationBarHeight)
                .overlay(scrollHeader, alignment: .bottom)
                .ignoresSafeArea(edges: .top)
        }
    }

    var scrollHeader: some View {
        ScrollViewHeader(content: header)
            .frame(height: headerHeight)
    }

    func handleScrollOffset(_ offset: CGPoint) {
        self.scrollOffset = offset
        self.onScroll?(offset, headerVisibleRatio)
    }
    
    /*var body: some View {
        GeometryReader { globalProxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    GeometryReader { proxy in
                        //header().opacity(getOpacity()).foregroundColor(.white).frame(maxWidth: .infinity).frame(height: getHeaderHeight(edgeInsets: globalProxy.safeAreaInsets), alignment: .bottom).background(Color.red)
                    }.frame(height: maxHeight).offset(y: -offset).zIndex(1)
                    content().zIndex(0)
                }.modifier(OffsetModifier(offset: $offset))
            }.coordinateSpace(name: "SCROLL")
        }
    }
    
    func getHeaderHeight(edgeInsets: EdgeInsets) -> CGFloat {
        let topHeight = maxHeight + offset
        return scrollUpBehavior == .parallax ? (topHeight > /*80 + */edgeInsets.top ? topHeight : /*80 + */edgeInsets.top) : (topHeight > maxHeight ? maxHeight : topHeight)
        //return topHeight > /*80 + */edgeInsets.top ? topHeight : /*80 + */edgeInsets.top
    }
    
    func topAppBarTitleOpacity(edgeInsets: EdgeInsets) -> Double {
        let progress = -(offset + 60) / (maxHeight - (/*80 + */edgeInsets.top))
        return Double(progress)
    }
    
    func getOpacity() -> Double {
        let progress = -(offset + 100) / 70
        let opacity = 1 - progress
        return Double(offset < 0 ? opacity : 1)
    }*/
}

public enum ScrollUpHeaderBehavior {
    case parallax
    case sticky
}

public enum ScrollDownHeaderBehavior {
    case offset
    case sticky
}

struct OffsetModifier: ViewModifier {
    @Binding var offset: CGFloat
    
    func body(content: Content) -> some View {
        content.overlay(GeometryReader { proxy -> Color in
            let minY = proxy.frame(in: .named("SCROLL")).minY
            
            DispatchQueue.main.async {
                offset = minY
            }
            return Color.clear
        }, alignment: .center)
    }
}


///
///

private struct ScrollViewOffsetTracker: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear
                .preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geo.frame(in: .named("scrollView")).origin
                )
        }
        .frame(height: 0)
    }
}

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
}

private extension ScrollView {
    func withOffsetTracking(
        action: @escaping (_ offset: CGPoint) -> Void
    ) -> some View {
        self.coordinateSpace(name: "scrollView")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: action)
    }
}

private extension View {

    @ViewBuilder
    func prefersNavigationBarHidden() -> some View {
        #if os(watchOS)
        self
        #else
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 8.0, *) {
            self.toolbarBackground(.hidden)
        } else {
            self
        }
        #endif
    }
}
