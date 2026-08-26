//
//  ConflatedEventBus.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/06/26.
//

import Combine

internal class ConflatedEventBus<T : Any> {
    //@Published private var state: (Int, T?)
    private var state: CurrentValueSubject<(Int, T?), Never>
    
    var publisher: AnyPublisher<T, Never> {
        get {
            //$state.compactMap { $0.1 }.eraseToAnyPublisher()
            state.compactMap { $0.1 }.eraseToAnyPublisher()
        }
    }
    
    func send(data: T) {
        //state = (state.0 + 1, data)
        state.send((state.value.0 + 1, data))
    }
    
    init(_ initialValue: T? = nil) {
        //self.state = (Int.min, initialValue)
        self.state = CurrentValueSubject<(Int, T?), Never>((Int.min, initialValue))
    }
}
