//
//  UiReceiver.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/06/19.
//

internal protocol UiReceiver {
    func accessHint(viewportHint: ViewportHint)
    
    func retry()
    
    func refresh()
}
