//
//  FirebaseRef.swift
//  YuMinigroup
//
//  Android FirebaseDatabase.getInstance().reference 대응. GoogleService-Info.plist가
//  없으면 FirebaseApp.configure()가 호출되지 않으므로, 사용처는 isConfigured/database()의
//  nil을 보고 Firebase 병합(프레즌스 등)을 생략한다. SPM 링크는 Task 6에서 이루어지며
//  그 전까지는 이 파일 단독으로는 빌드되지 않는다(계획상 정상).
//

import FirebaseCore
import FirebaseDatabase

enum FirebaseRef {
    static var isConfigured: Bool {
        FirebaseApp.app() != nil
    }

    static func database() -> DatabaseReference? {
        guard isConfigured else {
            return nil
        }
        return Database.database().reference()
    }
}
