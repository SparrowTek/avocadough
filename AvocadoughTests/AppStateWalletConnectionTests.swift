//
//  AppStateWalletConnectionTests.swift
//  AvocadoughTests
//

import Foundation
import Testing
@testable import Avocadough

/// What the app does when the paired wallet can't be reached, at launch and afterwards.
@MainActor
@Suite("App state: wallet connection")
struct AppStateWalletConnectionTests {
    private func makeState(route: AppState.Route) -> AppState {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "AppStateWalletConnectionTests-\(UUID().uuidString)")
        let state = AppState(diagnostics: DiagnosticsLog(store: DiagnosticsStore(directory: directory)))
        state.route = route
        return state
    }

    // MARK: - Launch

    @Test("An unreachable wallet opens on the cached one and stays paired")
    func unreachableWithCachedWallet() {
        let state = makeState(route: .config)
        let logoutTrigger = state.triggerLogout

        state.walletUnreachable(hasCachedWallet: true)

        #expect(state.route == .wallet)
        #expect(state.triggerLogout == logoutTrigger)
    }

    @Test("An unreachable wallet with nothing cached waits on the launch screen, still paired")
    func unreachableWithoutCachedWallet() {
        let state = makeState(route: .config)
        let logoutTrigger = state.triggerLogout

        state.walletUnreachable(hasCachedWallet: false)

        #expect(state.route == .config)
        #expect(state.configStatus == .unreachable)
        #expect(state.triggerLogout == logoutTrigger)
    }

    @Test("Trying again shows the connection attempt and asks for a sync")
    func retryFromLaunchScreen() {
        let state = makeState(route: .config)
        state.walletUnreachable(hasCachedWallet: false)

        state.retryWalletConnection()

        #expect(state.route == .config)
        #expect(state.configStatus == .connecting)
        #expect(state.triggerDataSync)
    }

    @Test("A retry that fails again goes back to offering one")
    func retryFailsAgain() {
        let state = makeState(route: .config)
        state.walletUnreachable(hasCachedWallet: false)
        state.retryWalletConnection()

        state.walletUnreachable(hasCachedWallet: false)

        #expect(state.configStatus == .unreachable)
    }

    @Test("Connecting at launch leaves the first transaction fetch to the wallet screen")
    func connectedAtLaunch() {
        let state = makeState(route: .config)

        state.walletReconnected()

        #expect(!state.walletState.triggerTransactionSync)
    }

    // MARK: - Wallet showing

    @Test("A refresh that fails leaves the wallet screen as it is")
    func failedRefresh() {
        let state = makeState(route: .wallet)
        let logoutTrigger = state.triggerLogout

        state.walletUnreachable(hasCachedWallet: false)

        #expect(state.route == .wallet)
        #expect(state.configStatus == .connecting)
        #expect(state.triggerLogout == logoutTrigger)
    }

    @Test("A retry from the wallet screen asks for a sync")
    func retryFromWalletScreen() {
        let state = makeState(route: .wallet)

        state.retryWalletConnection()

        #expect(state.route == .wallet)
        #expect(state.triggerDataSync)
    }

    @Test("Reconnecting behind cached data fetches the transactions")
    func reconnectedWhileShowingWallet() {
        let state = makeState(route: .wallet)

        state.walletReconnected()

        #expect(state.walletState.triggerTransactionSync)
    }

    // MARK: - Disconnecting

    @Test("Logging out returns to setup and drops a pending retry")
    func logout() {
        let state = makeState(route: .config)
        state.walletUnreachable(hasCachedWallet: false)
        state.retryWalletConnection()
        state.presentDisconnectDialog = true
        let logoutTrigger = state.triggerLogout

        state.logout()

        #expect(state.route == .setup)
        #expect(state.triggerLogout != logoutTrigger)
        #expect(!state.triggerDataSync)
        #expect(!state.presentDisconnectDialog)
        #expect(state.configStatus == .connecting)
    }

    @Test("Pairing again after a failed launch starts on the connection attempt")
    func pairingAgain() {
        let state = makeState(route: .config)
        state.walletUnreachable(hasCachedWallet: false)
        state.logout()

        state.walletSuccessfullyConnected()

        #expect(state.route == .config)
        #expect(state.configStatus == .connecting)
    }
}
