//
//  MyInfoView.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2023/06/03.
//

import SwiftUI

struct MyInfoView: View {
    var body: some View {
        ZStack {
            Color(.white).edgesIgnoringSafeArea(.all)
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        VStack(spacing: 0) {
                            VStack {
                                HStack {
                                    Text("이메일").frame(width: 80)
                                    Spacer()
                                    Text("{{tv_email}}")
                                }
                                .frame(height: 35)
                                .padding(.top, 15)
                                
                                Color(.systemGray)
                                    .frame(height: 0.5)
                                
                                HStack {
                                    Text("패스워드").frame(width: 80)
                                    Spacer()
                                    Text("변경하기")
                                        .frame(width: nil, height: nil, alignment: .trailing)
                                        .padding(.trailing, 15)
                                        .background(Color.clear)
                                        .overlay(Image(systemName: "ic_keyboard_arrow_right_gray_24dp").padding(.leading, 15), alignment: .trailing)
                                }
                                .frame(height: 35)
                                .padding(.top, 15)
                                
                                Color(.systemGray)
                                    .frame(height: 0.5)
                                
                                HStack {
                                    Text("가입일").frame(width: 80)
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Text("{{tv_create_at}}")
                                    }
                                }
                                .frame(height: 35)
                                .padding(.top, 15)
                            }
                            .background(Color.white)
                            .padding(.horizontal, 20)
                            .padding(.top, 120)
                            
                            Color(.systemGray)
                                .frame(height: 0.5)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text("기본정보")
                                    .font(.headline)
                                    .padding(.leading, 10)
                                    .padding(.bottom, 5)
                                    .frame(height: 40)
                                    .background(Color(.systemGray6))
                                
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("이름").frame(width: 80)
                                        Spacer()
                                        Text("{{tv_name}}")
                                    }
                                    .frame(height: 35)
                                    .padding(.top, 15)
                                    
                                    Color(.systemGray)
                                        .frame(height: 0.5)
                                    
                                    HStack {
                                        Text("생년월일").frame(width: 80)
                                        Spacer()
                                        Text("{{tv_birth_date}}")
                                    }
                                    .frame(height: 35)
                                    .padding(.top, 15)
                                    
                                    Color(.systemGray)
                                        .frame(height: 0.5)
                                    
                                    HStack {
                                        Text("성별")
                                            .frame(width: 80)
                                        Spacer()
                                        Text("{{tv_gender}}")
                                    }
                                    .frame(height: 35)
                                    .padding(.top, 15)
                                }
                                .padding(.horizontal, 20)
                            }
                            .background(Color.white)
                            
                            Color(.systemGray)
                                .frame(height: 0.5)
                        }
                        
                        VStack(alignment: .leading, spacing: 0) {
                            Text("추가정보")
                                .font(.headline)
                                .padding(.leading, 10)
                                .padding(.bottom, 5)
                                .frame(height: 40)
                                .background(Color(.systemGray6))
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("전화번호").frame(width: 80)
                                    Spacer()
                                    Text("{{tv_phone}}")
                                }
                                .frame(height: 35)
                                .padding(.top, 15)
                                
                                Color(.systemGray)
                                    .frame(height: 0.5)
                                
                                HStack {
                                    Text("지역").frame(width: 80)
                                    Spacer()
                                    Text("{{tv_address}}")
                                }
                                .frame(height: 35)
                                .padding(.top, 15)
                            }
                            .padding(.horizontal, 20)
                        }
                        .background(Color.white)
                        
                        Color(.systemGray)
                            .frame(height: 0.5)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 30)
            }
            VStack {
                Spacer()
                
                Button(action: {
                    // Perform action on button click
                }) {
                    Text("로그아웃")
                        .foregroundColor(.white)
                        .frame(width: 350, height: 50)
                        .background(Color(.green))
                        .cornerRadius(5)
                }
                .padding(.bottom, 20)
                .padding(.horizontal, 20)
            }
        }
    }
}

struct MyInfoView_Previews: PreviewProvider {
    static var previews: some View {
        MyInfoView()
    }
}
