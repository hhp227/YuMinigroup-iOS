//
//  Toast.swift
//  YuMinigroup
//
//  KNU-iOS Helper/UIViewToast.swift(+UI/Toast.swift)를 SwiftUI로 이식 — Android Toast.makeText 대응.
//  message 바인딩에 값이 채워지면 2초 후 자동으로 nil로 돌아가는 캡슐형 토스트를 하단에 띄운다.
//

import SwiftUI

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    private static let duration: TimeInterval = 2.0

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = message {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.black.opacity(0.6)))
                    .padding(.bottom, 32)
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + ToastModifier.duration) {
                            if self.message == message {
                                self.message = nil
                            }
                        }
                    }
            }
        }
        .animation(.easeOut, value: message)
    }
}

extension View {
    func toast(message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}
