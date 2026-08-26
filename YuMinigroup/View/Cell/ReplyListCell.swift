//
//  ReplyListCell.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/06/04.
//  Copyright © 2022 홍희표. All rights reserved.
//

import Foundation
import SwiftUI

struct ReplyListCell: View {
    @State
    private var isNavigateUpdateReplyView = false
    
    @State
    private var isActionSheetVisible = false
    
    @State
    var reply: ReplyItem
    
    let user: User?
    
    let onAction: (ReplyItem) -> Void
    
    var body: some View {
        VStack(alignment: .trailing) {
            HStack(alignment: .top) {
                AsyncImage(url: URL(string: URL_POST_IMAGE_PATH + (reply.profileImage ?? ""))!) { result in
                    switch result {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "photo")
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 55, height: 55)
                .cornerRadius(45)
                VStack(alignment: .leading) {
                    Text(reply.name).fontWeight(.bold)
                    Text(reply.reply)
                }
                .padding(.leading, 7)
                Spacer()
            }
            .padding(.horizontal, 5)
            Text(DateUtil.getPeriodTimeGenerator(DateUtil.parseDate(reply.timeStamp))).font(.system(size: 14))
        }
        .navigationDestination(isPresented: $isNavigateUpdateReplyView) {
            UpdateReplyView(viewModel: InjectorUtils.proviteUpdateReplyViewModel(InjectorUtils.instance)($reply))
        }
        .padding(8)
        .onLongPressGesture {
            isActionSheetVisible.toggle()
        }
        .actionSheet(isPresented: $isActionSheetVisible, content: getActionSheet)
    }
    
    func getActionSheet() -> ActionSheet {
        var buttons = [ActionSheet.Button]()
        
        buttons.append(.default(Text("Copy Content")) {
            UIPasteboard.general.string = reply.reply
        })
        if user != nil, user?.id == reply.userId {
            buttons.append(.default(Text("Edit Comment")) { isNavigateUpdateReplyView.toggle() })
            buttons.append(.destructive(Text("Delete Comment"), action: { onAction(reply) }))
        }
        buttons.append(.cancel())
        return ActionSheet(title: Text("Selection Action"), buttons: buttons)
    }
}

struct ReplyListCell_Previews: PreviewProvider {
    static var previews: some View {
        ReplyListCell(reply: .EMPTY, user: nil, onAction: { _ in })
    }
}
