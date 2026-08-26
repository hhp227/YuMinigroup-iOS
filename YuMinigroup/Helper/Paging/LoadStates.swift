//
//  LoadStates.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2022/06/19.
//

struct LoadStates: Equatable {
    let refresh: LoadState
    
    let prepend: LoadState
    
    let append: LoadState

    func forEach(_ op: (LoadType, LoadState) -> Void) {
        op(.REFRESH, refresh)
        op(.PREPEND, prepend)
        op(.APPEND, append)
    }

    func modifyState(_ loadType: LoadType, _ newState: LoadState) -> LoadStates {
        switch loadType {
        case .APPEND:
            return LoadStates(
                refresh: self.refresh,
                prepend: self.prepend,
                append: newState
            )
        case .PREPEND:
            return LoadStates(
                refresh: self.refresh,
                prepend: newState,
                append: self.append
            )
        case .REFRESH:
            return LoadStates(
                refresh: newState,
                prepend: self.prepend,
                append: self.append
            )
        }
    }
    
    func get(_ loadType: LoadType) -> LoadState {
        switch loadType {
        case .REFRESH:
            return self.refresh
        case .APPEND:
            return self.append
        case .PREPEND:
            return self.prepend
        }
    }
    
    func toString() -> String {
        return "LoadStates(refresh=\(refresh), prepend=\(prepend), append=\(append)"
    }
    
    static let IDLE = LoadStates(
        refresh: LoadState.NotLoading(false),
        prepend: LoadState.NotLoading(false),
        append: LoadState.NotLoading(false)
    )
}
