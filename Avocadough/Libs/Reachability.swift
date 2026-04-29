//
//  Reachability.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/31/23.
//

import Network
import SwiftUI

@MainActor
protocol ReachabilityDelegate: AnyObject {
    func triggerDataSync()
}

@Observable
@MainActor
class Reachability {
    enum ConnectionState {
        case notReachable
        case degradedPerformance
        case good
    }
    
    weak var delegate: ReachabilityDelegate?
    var connectionState: ConnectionState = .good
    
    func startMonitoring() async {
        let monitor = NWPathMonitor()
        for await path in monitor.paths() {
            evaluatePath(path)
        }
    }
    
    private func evaluatePath(_ path: NWPath) {
        withAnimation(.easeInOut(duration: 1.0)) {
            if path.status == .satisfied {
                connectionState = .good
                delegate?.triggerDataSync()
            } else {
                connectionState = .notReachable
            }
        }
    }
}

@MainActor
private struct ReachabilityKey: @preconcurrency EnvironmentKey {
    static let defaultValue = Reachability()
}

extension EnvironmentValues {
    var reachability: Reachability {
        get { self[ReachabilityKey.self] }
        set { self[ReachabilityKey.self] = newValue }
    }
}
