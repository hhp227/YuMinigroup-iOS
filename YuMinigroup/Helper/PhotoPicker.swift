//
//  PhotoPicker.swift
//  YuMinigroup
//
//  Android ACTION_OPEN_DOCUMENT(EXTRA_ALLOW_MULTIPLE=true, image/*) 대응 — 앨범에서 이미지를 여러 장
//  고르는 화면. iOS 14+의 PHPickerViewController를 UIViewControllerRepresentable로 감싼다(iOS 15.6
//  타깃이라 iOS 16 전용 SwiftUI PhotosPicker는 쓰지 않는다 — 브리프 명시 지시).
//
//  PHPickerResult.itemProvider.loadObject(ofClass:completionHandler:)는 백그라운드 큐에서 비동기로
//  불리므로, 여러 장을 골랐을 때 순서가 뒤섞이지 않도록 인덱스 배열에 채워 넣고 DispatchGroup으로
//  전부 끝난 뒤 한 번에(메인 큐에서) onPicked([UIImage])를 호출한다 — CreateArticleView가 리스트에
//  한 번만 append하도록(부분 갱신으로 인한 깜빡임/순서 뒤섞임 방지).
//

import SwiftUI
import PhotosUI

struct PhotoPicker: UIViewControllerRepresentable {
    // 0 = 개수 제한 없음(PHPickerConfiguration 문서 규칙) — Android EXTRA_ALLOW_MULTIPLE과 동일하게 무제한.
    var selectionLimit = 0

    let onPicked: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()

        configuration.filter = .images
        configuration.selectionLimit = selectionLimit

        let picker = PHPickerViewController(configuration: configuration)

        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 정적 설정이라 갱신할 상태가 없다.
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let onPicked: ([UIImage]) -> Void

        init(onPicked: @escaping ([UIImage]) -> Void) {
            self.onPicked = onPicked
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else {
                return
            }
            var images = [UIImage?](repeating: nil, count: results.count)
            let group = DispatchGroup()

            for (index, result) in results.enumerated() where result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    images[index] = object as? UIImage
                    group.leave()
                }
            }
            group.notify(queue: .main) { [weak self] in
                guard let self = self else {
                    return
                }
                self.onPicked(images.compactMap { $0 })
            }
        }
    }
}
