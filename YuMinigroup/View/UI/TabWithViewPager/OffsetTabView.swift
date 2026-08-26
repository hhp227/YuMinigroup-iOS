//
//  OffsetTabView.swift
//  YuMinigroup
//
//  Created by hhp227 on 2023/06/02.
//

import SwiftUI

struct OffsetPageTabView<Content: View>: UIViewRepresentable {
    @Binding
    var offset: CGFloat
    
    @Binding
    var selection: Int
    
    var content: Content
    
    func makeCoordinator() -> Coordinator {
        return OffsetPageTabView.Coordinator(parent: self)
    }
    
    init(selection: Binding<Int>, offset: Binding<CGFloat>, @ViewBuilder content: @escaping () -> Content) {
        self.content = content()
        self._offset = offset
        self._selection = selection
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let hostView = UIHostingController(rootView: content)
        hostView.view.translatesAutoresizingMaskIntoConstraints = false
        hostView.view.backgroundColor = .clear
        let constraints = [
            hostView.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostView.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostView.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostView.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hostView.view.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ]
        
        scrollView.addSubview(hostView.view)
        scrollView.addConstraints(constraints)
        
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delegate = context.coordinator
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        let currentOffset = uiView.contentOffset.x
        
        if currentOffset != offset {
            uiView.setContentOffset(CGPoint(x: offset, y: 0), animated: true)
        }
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: OffsetPageTabView
        
        init(parent: OffsetPageTabView) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let offset = scrollView.contentOffset.x
            let maxSize = scrollView.contentSize.width
            let currentSelection = (offset / maxSize).rounded()
            parent.selection = Int(currentSelection)
            parent.offset = offset
        }
    }
}
