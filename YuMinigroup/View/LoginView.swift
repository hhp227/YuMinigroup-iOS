//
//  LoginView.swift
//  YuMinigroup
//
//  Android activity_login.xml + LoginViewModel 대응 — 로고, 아이디(학번)/비밀번호 입력, 로그인 버튼,
//  로딩 오버레이, 토스트로 구성한다. 아이디 필드는 Android의 inputType="number"를 그대로
//  .keyboardType(.numberPad)로 미러한다(형식 검증이 아니라 키보드 종류일 뿐 — task-8-report.md 참고).
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = LoginViewModel()

    let onLoginSuccess: () -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Spacer(minLength: 24)

                Image(systemName: "graduationcap.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 60)

                Text("영남대 LMS소셜네트워크")
                    .italic()
                    .font(.system(size: 15))

                Spacer(minLength: 24)

                Text("ID와 Password는 포털시스템과 동일합니다.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 6) {
                    Text("아이디 또는 학번")

                    TextField("ID", text: $viewModel.state.id)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("패스워드")
                        .padding(.top, 4)

                    SecureField("Password", text: $viewModel.state.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Button(action: viewModel.login) {
                    Text("로그인")
                        .frame(width: 200)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)

                Text("영남대학교 포털시스템으로 \n로그인 가능합니다.")
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .padding(5)

                Spacer()
            }
            .padding(16)

            if viewModel.state.isLoading {
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                ProgressView()
            }
        }
        .toast(message: $viewModel.state.message)
        .onChange(of: viewModel.state.loggedInUser) { loggedInUser in
            if loggedInUser != nil {
                onLoginSuccess()
            }
        }
    }
}
