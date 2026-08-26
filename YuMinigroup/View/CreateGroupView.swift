//
//  CreateGroupView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/31.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct CreateGroupView: View {
    @State
    private var isShowingActionSheet = false
    
    @State
    private var isShowingImagePicker = false
    
    @StateObject
    var viewModel = InjectorUtils.instance.provideCreateGroupViewModel()
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Enter Group Title", text: $viewModel.state.title)
            Image("add_photo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .onTapGesture {
                    isShowingActionSheet.toggle()
                }
                .actionSheet(isPresented: $isShowingActionSheet) {
                    ActionSheet(title: Text("Selection Action"), buttons: [
                        .default(Text("Gallery")) { isShowingImagePicker.toggle() },
                        .default(Text("Camera")),
                        .cancel()
                    ])
                }
            TextEditor(text: $viewModel.state.description)
            Spacer()
        }
        .navigationBarItems(trailing: Button(action: viewModel.createGroup) { Text("Send") })
    }
}

struct CreateGroupView_Previews: PreviewProvider {
    static var previews: some View {
        CreateGroupView()
    }
}
