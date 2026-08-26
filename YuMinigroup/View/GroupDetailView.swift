//
//  GroupDetailView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/15.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct GroupDetailView: View {
    @State
    private var offsetY = CGFloat.zero
    
    @State
    var currentTab = 0
    
    var body: some View {
        VStack {
            ScrollView {
                GeometryReader { proxy in
                    let offset = proxy.frame(in: .global).minY
                    
                    /*DispatchQueue.main.async {
                        self.offsetY = offset
                    }*/
                    VStack {
                        Image("image3")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(
                                width: proxy.size.width,
                                height: 300 + (offset > 0 ? offset : 0)
                            )
                            .clipped()
                            .opacity(offsetY < 0 ? 0 : 1)
                            .animation(.easeIn(duration: 0.5), value: offsetY)
                            .offset(y: offset > 0 ? -offset : 0)
                    }
                }
                .frame(minHeight: 250)
                LazyVStack(pinnedViews: .sectionHeaders) {
                    Section(header: SegmentTabBarView(currentTab: $currentTab)) {
                        switch currentTab {
                            case 0:
                                TabBarView(title: "소식")
                            case 1:
                                TabBarView(title: "일정")
                            case 2:
                                TabBarView(title: "맴버")
                            case 3:
                                TabBarView(title: "설정")
                            default:
                                EmptyView()
                        }
                    }
                }
            }
            .navigationTitle("경북대 소모임")
            .toolbar {
                ToolbarItem {
                    Button("Item") {}
                }
            }
        }
    }
}

/*struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GroupDetailView()
    }
}*/

struct TabBarView: View {
    let contents = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    
    let title: String
    
    var body: some View{
        VStack {
            Text("\(title) 칸입니다.")
            ForEach(contents, id: \.self) { name in
                TempItem(title: name)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
            }
        }
    }
}

struct TempItem: View {
    let title: String
    
    var body: some View {
        ZStack {
            Image(title)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            RoundedRectangle(cornerRadius: 12)
                .foregroundColor(.black)
                .opacity(0.5)
            Text(title)
                .foregroundColor(.white)
                .fontWeight(.bold)
        }
    }
}
