import SwiftUI
import UIKit

extension View {
    @ViewBuilder
    func navigationBarHiddenCompat() -> some View {
        if #available(iOS 16.0, *) {
            toolbar(.hidden, for: .navigationBar)
        } else {
            navigationBarHidden(true)
        }
    }

    func foregroundColorCompat(_ color: Color) -> some View {
        foregroundColor(color)
    }

    func navigationBarTintColorCompat(_ color: UIColor) -> some View {
        background(NavigationBarTintColorView(color: color))
    }

    func navigationBarBackgroundColorCompat(_ color: UIColor) -> some View {
        background(NavigationBarBackgroundColorView(color: color))
    }
}

private struct NavigationBarTintColorView: UIViewControllerRepresentable {
    let color: UIColor

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        uiViewController.navigationController?.navigationBar.tintColor = color
    }
}

private struct NavigationBarBackgroundColorView: UIViewControllerRepresentable {
    let color: UIColor

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let navigationBar = uiViewController.navigationController?.navigationBar else { return }

        let appearance = UINavigationBarAppearance()
        if color.cgColor.alpha == 0 {
            appearance.configureWithTransparentBackground()
        } else {
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = color
        }

        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance
    }
}
