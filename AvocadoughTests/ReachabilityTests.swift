//
//  ReachabilityTests.swift
//  AvocadoughTests
//

import Foundation
import Testing
@testable import Avocadough

@MainActor
@Suite("Reachability")
struct ReachabilityTests {
    private final class Listener: ReachabilityDelegate {
        private(set) var syncRequests = 0

        func triggerDataSync() {
            syncRequests += 1
        }
    }

    @Test("The path the monitor starts on doesn't ask for a sync")
    func startsOnline() {
        let reachability = Reachability()
        let listener = Listener()
        reachability.delegate = listener

        reachability.pathChanged(isSatisfied: true)

        #expect(reachability.connectionState == .good)
        #expect(listener.syncRequests == 0)
    }

    @Test("Getting the network back asks for one sync")
    func recovers() {
        let reachability = Reachability()
        let listener = Listener()
        reachability.delegate = listener
        reachability.pathChanged(isSatisfied: true)

        reachability.pathChanged(isSatisfied: false)
        #expect(reachability.connectionState == .notReachable)
        #expect(listener.syncRequests == 0)

        reachability.pathChanged(isSatisfied: true)
        #expect(reachability.connectionState == .good)
        #expect(listener.syncRequests == 1)
    }

    @Test("A change of interface while online doesn't ask again")
    func interfaceChange() {
        let reachability = Reachability()
        let listener = Listener()
        reachability.delegate = listener
        reachability.pathChanged(isSatisfied: false)
        reachability.pathChanged(isSatisfied: true)

        reachability.pathChanged(isSatisfied: true)

        #expect(listener.syncRequests == 1)
    }

    @Test("A launch without a network asks for a sync once one appears")
    func startsOffline() {
        let reachability = Reachability()
        let listener = Listener()
        reachability.delegate = listener

        reachability.pathChanged(isSatisfied: false)
        reachability.pathChanged(isSatisfied: true)

        #expect(listener.syncRequests == 1)
    }

    @Test("The wallet asks for a data sync when the network returns")
    func walletHearsRecovery() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ReachabilityTests-\(UUID().uuidString)")
        let state = AppState(diagnostics: DiagnosticsLog(store: DiagnosticsStore(directory: directory)))
        let reachability = Reachability()
        reachability.delegate = state.walletState

        reachability.pathChanged(isSatisfied: false)
        #expect(!state.triggerDataSync)

        reachability.pathChanged(isSatisfied: true)
        #expect(state.triggerDataSync)
    }
}
