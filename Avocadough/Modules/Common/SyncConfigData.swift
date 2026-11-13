//
//  SyncConfigData.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 1/7/24.
//

import SwiftUI
import SwiftData
import NostrKit

/// Connects to the paired wallet and caches its info and balance.
///
/// It runs when `AppState.triggerDataSync` is raised: a payment went out, the user
/// refreshed, or the network came back. The launch screen also runs it on appearing, and
/// the wallet screen does when it appeared on cached data without a connection.
///
/// A failure never removes the pairing by itself. Only a pairing that can't work at all,
/// one with no connection record or no secret, sends the app back to setup.
fileprivate struct SyncConfigData: ViewModifier {
    @Environment(AppState.self) private var state
    @Environment(\.nwc) private var nwc
    @Environment(\.modelContext) private var context
    @Environment(\.diagnostics) private var diagnostics
    @Environment(\.scenePhase) private var scenePhase
    @Query private var nwcCodes: [NWCConnection]
    @Query private var wallets: [Wallet]
    @State private var dataSyncTrigger = PlainTaskTrigger()
    @State private var isSyncing = false

    /// The launch screen always syncs when it appears. The wallet screen only does when
    /// it has no connection, because otherwise launch synced a moment ago.
    let syncsOnAppear: Bool

    func body(content: Content) -> some View {
        let isCanvas = content.isCanvas

        content
            .onChange(of: state.triggerDataSync, triggerDataSync)
            .onChange(of: scenePhase, retryWhenActive)
            .task { await syncOnAppear(isCanvas) }
            .task { await getBTCPrice(isCanvas) }
            .task($dataSyncTrigger) { await sync(isCanvas) }
    }

    /// A sync that is already running serves the request when it finishes. Restarting it
    /// here would cancel a connection attempt halfway through.
    private func triggerDataSync() {
        guard state.triggerDataSync, !isSyncing else { return }
        state.triggerDataSync = false
        dataSyncTrigger.trigger()
    }

    /// Coming back to the app is a good moment to try a wallet that couldn't be reached.
    private func retryWhenActive() {
        guard scenePhase == .active, !nwc.hasConnected, !isSyncing else { return }
        state.retryWalletConnection()
    }

    private func syncOnAppear(_ isCanvas: Bool) async {
        guard syncsOnAppear || !nwc.hasConnected else { return }
        await sync(isCanvas)
    }

    private func sync(_ isCanvas: Bool) async {
        guard !isCanvas, !isSyncing else { return }
        isSyncing = true
        state.triggerDataSync = false

        await getWalletInfo()
        await getBTCPrice(isCanvas)

        isSyncing = false
        triggerDataSync()
    }

    private func getWalletInfo() async {
        guard let nwcCode = nwcCodes.first else {
            diagnostics.record(.wallet, "No wallet connection is stored; returning to setup")
            state.logout()
            return
        }

        let wasConnected = nwc.hasConnected

        do {
            try await nwc.initializeNWCClient(pubKey: nwcCode.pubKey, relay: nwcCode.relay, lud16: nwcCode.lud16)
            if !wasConnected {
                state.walletReconnected()
            }

            let info = try await nwc.getInfo()
            let balance = try await nwc.getBalance()
            try saveWallet(info: info, balance: balance)
            state.configSuccessful()
        } catch let error as NWCError where error.invalidatesPairing {
            diagnostics.record(.wallet, "The wallet secret is missing from the keychain; returning to setup")
            state.logout()
        } catch {
            state.walletUnreachable(hasCachedWallet: !wallets.isEmpty)
        }
    }

    private func saveWallet(info: WalletConnectManager.WalletInfo, balance: UInt64) throws {
        let wallet = Wallet(info: info, balance: balance)
        context.insert(wallet)
        try context.save()
    }

    /// Fetches the price once. A launch without a network leaves it empty, so every
    /// later sync tries again until one succeeds.
    private func getBTCPrice(_ isCanvas: Bool) async {
        guard state.walletState.btcPrice == nil else { return }

        let price = if isCanvas {
            BTCPrice(amount: "83939.07", lastUpdatedAtInUtcEpochSeconds: "1744395173", currency: "USD", version: "1", base: "BTC")
        } else {
            try? await BlockBTCPriceService().getCurrentPrice()
        }

        guard let price else { return }
        state.savePrice(price)
    }
}

extension View {
    /// Connects to the wallet as soon as the view appears, and again whenever a data
    /// sync is requested. For the launch screen.
    func syncConfigData() -> some View {
        modifier(SyncConfigData(syncsOnAppear: true))
    }

    /// Refreshes the wallet whenever a data sync is requested, and reconnects one that
    /// couldn't be reached at launch. For the wallet screen.
    func refreshConfigData() -> some View {
        modifier(SyncConfigData(syncsOnAppear: false))
    }
}

#Preview {
    Text("Sync Config Data")
        .syncConfigData()
        .environment(AppState())
        .environment(\.nwc, NWC())
}
