//
//  CameraPicker.swift
//  YuMinigroup
//
//  Android MediaStore.ACTION_IMAGE_CAPTURE(FileProvider 경유 임시 파일) 대응 — 카메라로 한 장 촬영해
//  바로 첨부하는 화면. UIImagePickerController(sourceType: .camera)를 UIViewControllerRepresentable로
//  감싼다. Android는 EXIF 회전을 별도로 읽어 bitmapResize 후 rotateImage로 다시 굽지만, iOS의
//  info[.originalImage]는 이미 UIImage.imageOrientation에 방향이 실려 있고 CreateArticleViewModel.
//  send()가 업로드 직전 BitmapUtil.resized(맥스 픽셀 리사이즈, EXIF 방향을 픽셀에 굽는 처리 포함)를
//  거치므로 여기서 따로 회전을 처리하지 않는다.
//
//  Info.plist에 NSCameraUsageDescription("게시글 사진 촬영에 사용됩니다")이 필요하다 — 이 파일이 아니라
//  project.pbxproj의 build settings(INFOPLIST_KEY_NSCameraUsageDescription, GENERATE_INFOPLIST_FILE=YES
//  전제)로 등록한다.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()

        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // 정적 설정이라 갱신할 상태가 없다.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onPicked: (UIImage) -> Void

        init(onPicked: @escaping (UIImage) -> Void) {
            self.onPicked = onPicked
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onPicked(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
