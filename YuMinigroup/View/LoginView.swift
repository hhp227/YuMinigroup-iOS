//
//  LoginView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/08/28.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct LoginView: View {
    @State
    private var isShowRegister = false
    
    @StateObject
    var viewModel: LoginViewModel = InjectorUtils.instance.provideLoginViewModel()
    
    var body: some View {
        ZStack {
            VStack {
                VStack {
                    Text("Welcome!").font(.title)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Email").padding(.bottom, 10)
                        TextField("Email", text: $viewModel.state.email)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disableAutocorrection(true)
                            .padding(15)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2))
                        Text("Password").padding(.vertical, 10)
                        SecureField("Password", text: $viewModel.state.password)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2))
                    }
                    .padding(10)
                }
                Button(action: viewModel.login) {
                    Text("LOGIN")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                }
                .buttonStyle(.borderedProminent)
                .padding(10)
                Button(action: { isShowRegister.toggle() }) {
                    Text("Register")
                        .font(.system(size: 13))
                        .padding(5)
                }
                .sheet(isPresented: $isShowRegister) {
                    RegisterView()
                }
            }
            .padding(16)
            .onReceive(viewModel.$state) { state in
                if let user = state.user {
                    viewModel.storeUser(user)
                } else if !state.message.isEmpty {
                    viewModel.showSnackBar()
                }
            }
            if viewModel.state.isLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
