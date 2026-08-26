//
//  Resource.swift
//  YuMinigroup
//
//  Android의 helper.Callback(onLoading/onSuccess/onFailure) 대응
//

import Foundation

enum Resource<T> {
    case loading
    case success(T)
    case error(String, T? = nil)
}
