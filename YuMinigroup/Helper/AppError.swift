//
//  AppError.swift
//  YuMinigroup
//
//  단순 메시지 기반 에러 — try!/fatalError 없이 실패를 Result/Resource로 전달하기 위한 최소 타입
//

import Foundation

struct AppError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
