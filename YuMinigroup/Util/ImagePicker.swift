//
//  ImagePicker.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/12/30.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode)
    var presentationMode
    
    @Binding
    var imageSelected: UIImage
    
    @Binding
    var sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: UIViewControllerRepresentableContext<ImagePicker>) { }
    
    func makeCoordinator() -> ImagePickerCoordinator {
        return ImagePickerCoordinator(parent: self)
    }
    
    class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                // select the image for our app
                parent.imageSelected = image
                
                // dismiss the screen
                parent.presentationMode.wrappedValue.dismiss()
            }
        }
        
        init(parent: ImagePicker) {
            self.parent = parent
        }
    }
}
