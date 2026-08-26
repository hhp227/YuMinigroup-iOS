//
//  ScrollViewHeader.swift
//  YuMinigroup
//
//  Created by hhp227 on 2023/06/28.
//

import SwiftUI

public struct ScrollViewHeader<Content: View>: View {
    let content: () -> Content

    public var body: some View {
        GeometryReader { geo in
            content()
                .stretchable(in: geo)
        }
    }
}

private extension View {

    @ViewBuilder
    func stretchable(in geo: GeometryProxy) -> some View {
        let width = geo.size.width
        let height = geo.size.height
        let minY = geo.frame(in: .global).minY
        let useStandard = minY <= 0
        self.frame(width: width, height: height + (useStandard ? 0 : minY))
            .offset(y: useStandard ? 0 : -minY)
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
struct ScrollViewHeader_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScrollView {
                ScrollViewHeader {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [.blue, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom)
                        Text("Header title")
                           .padding()
                    }
                }
                .frame(height: 250)
            }
            .navigationTitle("Test")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accentColor(.white)
        .colorScheme(.dark)
    }
}
