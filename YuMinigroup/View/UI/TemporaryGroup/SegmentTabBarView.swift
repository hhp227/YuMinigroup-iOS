//
//  SegmentTabBarView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2023/09/09.
//

import SwiftUI

struct SegmentTabBarView: View {
    @Binding
    var currentTab: Int
    
    @Namespace
    var namespace
    
    var tabBarOptions: [String] = ["소식", "일정", "맴버", "설정"]
    
    var body: some View {
        VStack {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack() {
                    ForEach(tabBarOptions.indices, id: \.self) { index in
                        TabBarItem(
                            currentTab: $currentTab,
                            namespace: namespace,
                            title: tabBarOptions[index],
                            tab: index
                        )
                    }
                }
                .padding(.horizontal)
                .frame(width: UIScreen.main.bounds.width)
            }
            .frame(height: 40)
        }
    }
}



struct TabBarItem: View {
    @Binding
    var currentTab: Int
    
    let namespace: Namespace.ID
    
    var title: String
    
    var tab: Int
    
    var body: some View {
        Button {
            currentTab = tab
        } label: {
            VStack {
                Spacer()
                Text(title)
                    .bold()
                    .foregroundColor(.red)
                if currentTab == tab {
                    if #available(iOS 16.0, *) {
                        Color.black
                            .frame(height: 2)
                            .matchedGeometryEffect(
                                id: "underline",
                                in: namespace.self
                            )
                            .bold()
                    } else {
                        // Fallback on earlier versions
                    }
                } else {
                    Color.clear.frame(height: 2)
                }
            }
            .animation(.spring(), value: currentTab)
        }
        .buttonStyle(.plain)
    }
}
