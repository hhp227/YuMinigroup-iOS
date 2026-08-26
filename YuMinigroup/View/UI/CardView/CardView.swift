//
//  CardView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/09/03.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct CardView<Content: View>: View {
    var radius: CGFloat = 10
    
    var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading) {
            content().frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
        }.overlay(RoundedRectangle(cornerRadius: radius).stroke(Color(.sRGB, red: 150/255, green: 150/255, blue: 150/255, opacity: 0.5), lineWidth: 1)).padding([.leading, .trailing], 10)
    }
}

struct CardView_Previews: PreviewProvider {
    static var previews: some View {
        CardView {
            Text("")
        }
    }
}
