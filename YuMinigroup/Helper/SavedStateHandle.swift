//
//  SavedStateHandle.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/11/23.
//

import Foundation
import Combine

class SavedStateHandle {
    private var regular = [String: Any?]()
    
    private var valueSubjects = [String: CurrentValueSubject<Any?, Never>]()
    
    func contains(_ key: String) -> Bool {
        return regular.keys.contains(key)
    }
    
    func getValueSubject(_ key: String, _ initialValue: Any?) -> CurrentValueSubject<Any?, Never> {
        return getOrPut(key) {
            if !regular.keys.contains(key) {
                regular[key] = initialValue
            }
            let subject = CurrentValueSubject<Any?, Never>(regular[key]!)
            valueSubjects[key] = subject
            return subject
        }
    }
    
    func keys() -> Array<CodingKey> {
        return regular.keys.map { $0.codingKey } + valueSubjects.keys.map { $0.codingKey }
    }
    
    func get<T>(_ key: String) -> T? {
        return regular[key] as? T
    }
    
    func set<T>(_ key: String, _ value: T?) {
        regular[key] = value
        valueSubjects[key]?.value = value
    }
    
    func remove<T>(_ key: String) -> T? {
        let latestValue = regular.removeValue(forKey: key) as? T
        
        valueSubjects.removeValue(forKey: key)
        return latestValue
    }
    
    func getOrPut(_ key: String, _ defaultValue: () -> CurrentValueSubject<Any?, Never>) -> CurrentValueSubject<Any?, Never> {
        if let value = valueSubjects[key] {
            return value
        } else {
            let answer = defaultValue()
            valueSubjects[key] = answer
            return answer
        }
    }
    
    init() {}
    
    init(_ initialState: [String: Any?]) {
        regular = initialState
    }
}
