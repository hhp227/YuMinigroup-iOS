//
//  CreatePostView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/08.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>
    
    @State
    private var isShowingActionSheet = false
    
    @State
    private var isShowingImagePicker = false
    
    @State
    private var selectedItems: [PhotosPickerItem] = []
    
    @StateObject
    var viewModel: CreatePostViewModel
    
    let onResult: () -> Void
    
    var body: some View {
        List {
            ZStack {
                TextEditor(text: $viewModel.state.text)
                    .autocapitalization(.none)
                    .keyboardType(.default)
                    .disableAutocorrection(true)
                Text(viewModel.state.text)
                    .opacity(0)
                    .padding(.all, 8)
            }
            .listRowInsets(EdgeInsets())
            .shadow(radius: 1)
            ForEach(viewModel.state.items, id: \.id) { item in
                if let imageItem = item as? ImageItem {
                    Image(uiImage: UIImage(data: imageItem.data!) ?? UIImage())
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
            }
        }
        .listStyle(.inset)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button(action: viewModel.actionSend) { Text("Send") })
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: 5) {
                Button(action: { isShowingActionSheet.toggle() }) {
                    Image(systemName: "photo.fill").padding(10)
                }
                Button(action: {}) {
                    Image(systemName: "video.fill").padding(10)
                }
            }
            .padding(5)
        }
        .actionSheet(isPresented: $isShowingActionSheet) {
            ActionSheet(title: Text("Selection Action"), buttons: [
                .default(Text("Gallery")) { isShowingImagePicker.toggle() },
                .default(Text("Camera")),
                .cancel()
            ])
        }
        .photosPicker(isPresented: $isShowingImagePicker, selection: $selectedItems, matching: .images)
        .onReceive(viewModel.$state) { state in
            if state.postId >= 0 {
                onResult()
                presentationMode.wrappedValue.dismiss()
            }
        }
        .onChange(of: selectedItems) { newValue in
            newValue.forEach { item in
                item.loadTransferable(type: Data.self) { result in
                    switch result {
                    case .success(let data):
                        viewModel.addItem(ImageItem(data: data)) // TODO id값을 뭘로 기준으로 할것인가?
                    case .failure(let error):
                        print(error)
                    }
                }
            }
        }
    }
}

struct CreatePostView_Previews: PreviewProvider {
    static var previews: some View {
        CreatePostView(viewModel: InjectorUtils.instance.provideCreatePostViewModel(type: 0, groupId: 0), onResult: {})
    }
}
