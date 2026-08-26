//
//  RegisterView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/07/29.
//  Copyright © 2021 홍희표. All rights reserved.
//

import SwiftUI

struct RegisterView: View {
    @StateObject
    var viewModel: RegisterViewModel = InjectorUtils.instance.provideRegisterViewModel()
    
    var body: some View {
        ZStack {
            VStack {
                VStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Name").padding(.bottom, 10)
                        TextField("Name", text: $viewModel.state.name)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disableAutocorrection(true)
                            .padding(15)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2))
                        Text("Email").padding(.vertical, 10)
                        TextField("Email", text: $viewModel.state.email)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2))
                        Text("Password").padding(.vertical, 10)
                        SecureField("Password", text: $viewModel.state.password)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2))
                        Text("Confirm Password").padding(.vertical, 10)
                        SecureField("Confirm Password", text: $viewModel.state.confirmPassword)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.accentColor, lineWidth: 2))//.textContentType(.newPassword)
                    }
                    .padding(10)
                }
                Button(action: viewModel.register) {
                    Text("REGISTER")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                }
                .buttonStyle(.borderedProminent)
                .padding(10)
            }
            .padding(16)
            .onReceive(viewModel.$state) { state in
                if state.isSuccess {
                    print("isSuccess")
                }
            }
            if viewModel.state.isLoading {
                ProgressView().progressViewStyle(.circular)
            }
        }
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
    }
}
