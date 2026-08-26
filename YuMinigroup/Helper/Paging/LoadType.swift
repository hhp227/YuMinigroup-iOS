//
//  LoadType.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/06/19.
//

public enum LoadType: CaseIterable {
    var ordinal: Int {
        return LoadType.allCases.firstIndex(of: self) ?? -1
    }
    case REFRESH
    case PREPEND
    case APPEND
}
