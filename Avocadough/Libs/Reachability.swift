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
            pathChanged(isSatisfied: path.status == .satisfied)
        }
    }

    /// Records the latest path and asks for a data sync when the network comes back.
    ///
    /// The monitor also reports every interface change and the path it starts on, so a
    /// sync is only worth asking for after the network had actually been lost.
    func pathChanged(isSatisfied: Bool) {
        let recovered = isSatisfied && connectionState != .good

        withAnimation(.easeInOut(duration: 1.0)) {
            connectionState = isSatisfied ? .good : .notReachable
        }

        if recovered {
            delegate?.triggerDataSync()
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
