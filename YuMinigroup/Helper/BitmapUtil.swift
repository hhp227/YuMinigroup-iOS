//
//  BitmapUtil.swift
//  YuMinigroup
//
//  Android helper.BitmapUtil(bitmapResize + rotateImage) 미러 — EXIF 방향을 픽셀에 반영한 뒤
//  긴 변 기준으로 maxSize 이하로 축소한다. maxSize는 포인트가 아닌 "픽셀" 기준 값이므로, 렌더러의
//  scale을 명시적으로 고정해 디바이스 화면 배율(2x/3x)에 좌우되지 않게 한다.
//

import UIKit

enum BitmapUtil {
    static func resized(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let normalized = normalizedOrientation(image)
        let pixelWidth = normalized.size.width * normalized.scale
        let pixelHeight = normalized.size.height * normalized.scale

        guard maxSize > 0, max(pixelWidth, pixelHeight) > maxSize else {
            return normalized
        }
        let scale = maxSize / max(pixelWidth, pixelHeight)
        let targetPixelSize = CGSize(width: pixelWidth * scale, height: pixelHeight * scale)
        let format = UIGraphicsImageRendererFormat.default()

        // format.scale이 기본값(메인 스크린 scale)이면 targetSize(포인트)가 그 배율만큼 다시 확대되어
        // maxSize를 픽셀 단위로 정확히 지킬 수 없다. 1로 고정해 "포인트 = 픽셀"이 되게 한다.
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetPixelSize, format: format)

        return renderer.image { _ in
            normalized.draw(in: CGRect(origin: .zero, size: targetPixelSize))
        }
    }

    // EXIF 방향 정보를 실제 픽셀에 구워넣는다 (Android rotateImage 대응).
    // format.scale을 원본 이미지의 scale로 고정해, 기본값(메인 스크린 scale)으로 인해
    // 이미 작은 이미지가 불필요하게 2x/3x 픽셀로 확대 렌더링되는 것을 막는다.
    private static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else {
            return image
        }
        let format = UIGraphicsImageRendererFormat.default()

        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)

        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}
