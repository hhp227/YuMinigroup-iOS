//
//  RemoteMediatorAccessor.swift
//  YuMinigroup
//
//  Created by hhp227 on 2023/01/26.
//

import Combine
import Foundation

internal protocol RemoteMediatorConnection {
    associatedtype Key
    associatedtype Value
    
    func requestRefreshIfAllowed(_ pagingState: PagingState<Key, Value>)
    
    func requestLoad(_ loadType: LoadType, _ pagingState: PagingState<Key, Value>)
    
    func retryFailed(_ pagingState: PagingState<Key, Value>)
    
    func allowRefresh()
}

internal protocol RemoteMediatorAccessor: RemoteMediatorConnection {
    var state: AnyPublisher<LoadStates, Never> { get }

    func initialize() -> RemoteMediator<Key, Value>.InitializeAction
}

func remoteMediatorAccessor<Key: Any, Value: Any>(
    delegate: RemoteMediator<Key, Value>
) -> some RemoteMediatorAccessor {
    return RemoteMediatorAccessImpl(delegate: delegate)
}

private class AccessorStateHolder<Key, Value> {
    private let lock = NSLock()
    private var _loadStates = CurrentValueSubject<LoadStates, Never>(.IDLE)
    var loadStates: AnyPublisher<LoadStates, Never> {
        return _loadStates.eraseToAnyPublisher()
    }
    private var internalState = AccessorState<Key, Value>()

    func use<R>(_ block: (AccessorState<Key, Value>) -> R) -> R {
        return lock.withLock {
            let result = block(internalState)
            _loadStates.send(internalState.computeLoadStates())
            return result
        }
    }
    
    func requestLoad(
        _ loadType: LoadType,
        _ pagingState: PagingState<Key, Value>,
        _ launchRefresh: @escaping () -> Void,
        _ launchBoundary: @escaping () -> Void
    ) {
        let newRequest = use {
            $0.append(loadType: loadType, pagingState: pagingState)
        }
        
        if newRequest {
            if loadType == .REFRESH {
                launchRefresh()
            } else {
                launchBoundary()
            }
        }
    }
}

private class AccessorState<Key, Value> {
    private var blockStates = Array(repeating: BlockState.unblocked, count: LoadType.allCases.count)
    private var errors = Array<LoadState.Error?>(repeating: nil, count: LoadType.allCases.count)
    private var pendingRequests = [PendingRequest<Key, Value>]()
    var refreshAllowed: Bool = false

    func computeLoadStates() -> LoadStates {
        return LoadStates(
            refresh: computeLoadTypeState(loadType: .REFRESH),
            prepend: computeLoadTypeState(loadType: .PREPEND),
            append: computeLoadTypeState(loadType: .APPEND)
        )
    }

    private func computeLoadTypeState(loadType: LoadType) -> LoadState {
        let blockState = blockStates[loadType.ordinal]
        let hasPending = pendingRequests.contains { $0.loadType == loadType }
        
        if hasPending && blockState != .requiresRefresh {
            return .Loading.instance
        }
        if let error = errors[loadType.ordinal] {
            return error
        }
        switch blockState {
        case .completed:
            return loadType == .REFRESH ? .NotLoading(false) : .NotLoading(true)
        case .requiresRefresh, .unblocked:
            return .NotLoading(false)
        }
    }

    func append(loadType: LoadType, pagingState: PagingState<Key, Value>) -> Bool {
        if let existing = pendingRequests.first(where: { $0.loadType == loadType }) {
            existing.pagingState = pagingState
            return false
        }

        let blockState = blockStates[loadType.ordinal]
        if blockState == .requiresRefresh && loadType != .REFRESH {
            pendingRequests.append(PendingRequest(loadType: loadType, pagingState: pagingState))
            return false
        }
        if blockState != .unblocked && loadType != .REFRESH {
            return false
        }
        if loadType == .REFRESH {
            setError(loadType: .REFRESH, errorState: nil)
        }
        return errors[loadType.ordinal] == nil && pendingRequests.append(PendingRequest(loadType: loadType, pagingState: pagingState)) != nil
    }

    func setBlockState(loadType: LoadType, state: BlockState) {
        blockStates[loadType.ordinal] = state
    }

    func getPendingRefresh() -> PagingState<Key, Value>? {
        return pendingRequests.first { $0.loadType == .REFRESH }?.pagingState
    }

    func getPendingBoundary() -> (LoadType, PagingState<Key, Value>)? {
        guard let request = pendingRequests.first(where: { $0.loadType != .REFRESH && blockStates[$0.loadType.ordinal] == .unblocked }) else {
            return nil
        }
        return (request.loadType, request.pagingState)
    }

    func clearPendingRequests() {
        pendingRequests.removeAll()
    }

    func clearPendingRequest(loadType: LoadType) {
        pendingRequests.removeAll { $0.loadType == loadType }
    }

    func clearErrors() {
        for i in errors.indices {
            errors[i] = nil
        }
    }

    func setError(loadType: LoadType, errorState: LoadState.Error?) {
        errors[loadType.ordinal] = errorState
    }

    class PendingRequest<Key: Any, Value: Any> {
        let loadType: LoadType
        var pagingState: PagingState<Key, Value>

        init(loadType: LoadType, pagingState: PagingState<Key, Value>) {
            self.loadType = loadType
            self.pagingState = pagingState
        }
    }

    enum BlockState {
        case unblocked
        case completed
        case requiresRefresh
    }
}

private class RemoteMediatorAccessImpl<Key: Any, Value: Any>: RemoteMediatorAccessor {
    private let remoteMediator: RemoteMediator<Key, Value>

    var state: AnyPublisher<LoadStates, Never> {
        return accessorState.loadStates
    }

    private let accessorState = AccessorStateHolder<Key, Value>()

    func requestRefreshIfAllowed(_ pagingState: PagingState<Key, Value>) {
        accessorState.use {
            if $0.refreshAllowed {
                $0.refreshAllowed = false
                accessorState.requestLoad(LoadType.REFRESH, pagingState, launchRefresh, launchBoundary)
            }
        }
    }
    
    func allowRefresh() {
        accessorState.use { $0.refreshAllowed = true }
    }
    
    func requestLoad(_ loadType: LoadType, _ pagingState: PagingState<Key, Value>) {
        accessorState.requestLoad(loadType, pagingState, launchRefresh, launchBoundary)
    }

    private func launchRefresh() {
        var launchAppendPrepend = false

        let pendingPagingState = accessorState.use {
            $0.getPendingRefresh()
        }
        if let pendingPagingState = pendingPagingState {
            let loadResult = remoteMediator.load(loadType: .REFRESH, state: pendingPagingState)

            switch (loadResult) {
            case .Success(let endOfPaginationReached):
                launchAppendPrepend = accessorState.use {
                    $0.clearPendingRequest(loadType: .REFRESH)
                    if endOfPaginationReached {
                        $0.setBlockState(loadType: .REFRESH, state: .completed)
                        $0.setBlockState(loadType: .PREPEND, state: .completed)
                        $0.setBlockState(loadType: .APPEND, state: .completed)
                        $0.clearPendingRequests()
                    } else {
                        $0.setBlockState(loadType: .PREPEND, state: .unblocked)
                        $0.setBlockState(loadType: .APPEND, state: .unblocked)
                    }
                    $0.setError(loadType: .PREPEND, errorState: nil)
                    $0.setError(loadType: .APPEND, errorState: nil)
                    return $0.getPendingBoundary() != nil
                }
                break
            case .Error(let e):
                launchAppendPrepend = accessorState.use {
                    $0.clearPendingRequest(loadType: .REFRESH)
                    $0.setError(loadType: .REFRESH, errorState: LoadState.Error(e))
                    return $0.getPendingBoundary() != nil
                }
                break
            }
        }
        if launchAppendPrepend {
            launchBoundary()
        }
    }

    private func launchBoundary() {
        while true {
            guard let (loadType, pendingPagingState) = accessorState.use ({
                $0.getPendingBoundary()
            }) else {
                break
            }
            switch remoteMediator.load(loadType: loadType, state: pendingPagingState) {
            case .Success(endOfPaginationReached: let endOfPaginationReached):
                accessorState.use {
                    $0.clearPendingRequest(loadType: loadType)
                    if endOfPaginationReached {
                        $0.setBlockState(loadType: loadType, state: .completed)
                    }
                }
                break
            case .Error(let e):
                accessorState.use {
                    $0.clearPendingRequest(loadType: loadType)
                    $0.setError(loadType: loadType, errorState: LoadState.Error(e))
                }
                break
            }
        }
    }

    func retryFailed(_ pagingState: PagingState<Key, Value>) {
        var toBeStarted = [LoadType]()

        accessorState.use {
            let loadStates = $0.computeLoadStates()
            let willTriggerRefresh = loadStates.refresh is LoadState.Error

            $0.clearErrors()
            if willTriggerRefresh {
                toBeStarted.append(.REFRESH)
                $0.setBlockState(loadType: .REFRESH, state: .unblocked)
            }
            if loadStates.append is LoadState.Error {
                if !willTriggerRefresh {
                    toBeStarted.append(.APPEND)
                }
                $0.clearPendingRequest(loadType: .APPEND)
            }
            if loadStates.prepend is LoadState.Error {
                if !willTriggerRefresh {
                    toBeStarted.append(.PREPEND)
                }
                $0.clearPendingRequest(loadType: .PREPEND)
            }
        }
        toBeStarted.forEach {
            requestLoad($0, pagingState)
        }
    }

    func initialize() -> RemoteMediator<Key, Value>.InitializeAction {
        let action = remoteMediator.initialize()

        if action == RemoteMediator.InitializeAction.LAUNCH_INITIAL_REFRESH {
            accessorState.use {
                $0.setBlockState(loadType: .APPEND, state: .requiresRefresh)
                $0.setBlockState(loadType: .PREPEND, state: .requiresRefresh)
            }
        }
        return action
    }

    init(delegate: RemoteMediator<Key, Value>) {
        self.remoteMediator = delegate
    }
}
