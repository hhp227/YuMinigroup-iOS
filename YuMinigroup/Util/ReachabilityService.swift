//
//  ReachabilityService.swift
//  YuMinigroup
//
//  Created by 홍희표 on 2021/11/24.
//  Copyright © 2021 홍희표. All rights reserved.
//

import Combine
import Network

enum NetworkType {
    case wifi
    case celluar
    case loopback
    case wired
    case other
}

final class ReachabilityService: ObservableObject {
    @Published
    var reachabilityInfos: NWPath?
    
    @Published
    var isNetworkAvailable: Bool?
    
    @Published
    var typeOfCurrentConnection: NetworkType?
    
    private let monitor = NWPathMonitor()
    
    private let backgroundQueue = DispatchQueue.global(qos: .background)
    
    init() {
        setUp()
    }
    
    init(with interfaceType: NWInterface.InterfaceType) {
        setUp()
    }
    
    func setUp() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.reachabilityInfos = path
            
            switch path.status {
            case .satisfied:
                self?.isNetworkAvailable = true
                break
            case .unsatisfied:
                if #available(iOS 14.2, *) {
                    switch path.unsatisfiedReason {
                    case .notAvailable:
                        break
                    case .cellularDenied:
                        break
                    case .wifiDenied:
                        break
                    case .localNetworkDenied:
                        break
                    @unknown default: break
                    }
                } else {
                    
                }
                self?.isNetworkAvailable = false
                break
            case .requiresConnection:
                self?.isNetworkAvailable = false
                break
            @unknown default:
                self?.isNetworkAvailable = false
            }
            if path.usesInterfaceType(.wifi) {
                self?.typeOfCurrentConnection = .wifi
            } else if path.usesInterfaceType(.cellular) {
                self?.typeOfCurrentConnection = .celluar
            } else if path.usesInterfaceType(.loopback) {
                self?.typeOfCurrentConnection = .loopback
            } else if path.usesInterfaceType(.wiredEthernet) {
                self?.typeOfCurrentConnection = .wired
            } else if path.usesInterfaceType(.other) {
                self?.typeOfCurrentConnection = .other
            }
        }
        monitor.start(queue: backgroundQueue)
    }
    
    deinit {
        monitor.cancel()
    }
}
