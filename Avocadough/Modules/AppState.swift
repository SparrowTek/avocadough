//
//  AppState.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/10/23.
//

import SwiftUI
import Vault
import NostrKit

@Observable
@MainActor
public class AppState {
    enum Route: Int, Identifiable {
        case wallet
        case setup
        case config
        
        var id: Int { rawValue }
    }
    
    /// What the launch screen shows while `route` is `.config`.
    enum ConfigStatus {
        /// Connecting to the paired wallet.
        case connecting
        /// The wallet couldn't be reached and nothing is cached to show in its place.
        case unreachable
    }

    var route: Route = .setup
    var configStatus: ConfigStatus = .connecting
    var presentDisconnectDialog = false
    var triggerDataSync = false
    var triggerLogout = false

    /// A `lightning:` or `bitcoin:` URI that arrived before the wallet was ready to pay it.
    private var pendingPaymentInput: String?

    let diagnostics: DiagnosticsLog
    
    @ObservationIgnored
    lazy var walletState = WalletState(parentState: self)
    @ObservationIgnored
    lazy var setupState = SetupState(parentState: self)

    init(diagnostics: DiagnosticsLog = .shared) {
        self.diagnostics = diagnostics
    }
    
    func onOpenURL(_ url: URL) async {
        guard let scheme = url.scheme?.lowercased() else {
            diagnostics.record(.url, "Ignored a URL without a scheme", detail: url.absoluteString)
            return
        }

        switch scheme {
        case "lightning", "bitcoin":
            diagnostics.record(.url, "Received a \(scheme): URL", detail: url.absoluteString)
            pay(url.absoluteString)
        case "avocadough":
            diagnostics.record(.url, "Received an avocadough: URL; nothing handles its host yet", detail: url.absoluteString)
            switch url.host() {
            default:
                break
            }
        default:
            diagnostics.record(.url, "Ignored a URL with an unsupported scheme", detail: url.absoluteString)
        }
    }

    /// Hands a payment URI to the wallet, or holds on to it until the wallet is showing.
    private func pay(_ input: String) {
        guard route == .wallet else {
            pendingPaymentInput = input
            diagnostics.record(.url, "The wallet isn't showing yet (route: \(route)); holding the payment URI")
            return
        }
        diagnostics.record(.url, "Handing the payment URI to the send flow")
        walletState.send(input)
    }
    
    /// Only a keychain that holds no secret means there is nothing to connect to. A
    /// keychain that can't be read goes to the launch screen like a pairing does, which
    /// keeps whatever is stored if it can't connect.
    func determineRoute() async {
        do {
            _ = try await Vault.shared.read(configuration: .nwcSecret)
            route = .config
        } catch {
            let failure = NWCError(readingSecret: error)
            if !failure.invalidatesPairing {
                diagnostics.record(.app, "Couldn't read the keychain at launch", detail: String(describing: error))
            }
            route = failure.invalidatesPairing ? .setup : .config
        }
    }
    
    func walletSuccessfullyConnected() {
        configStatus = .connecting
        route = .config
    }

    /// The paired wallet couldn't be reached. The pairing is kept either way, because
    /// only the wallet can issue a new one: with a wallet cached from an earlier launch
    /// the app opens on it and catches up once the connection is back, and without one
    /// the launch screen offers to try again.
    ///
    /// Has no effect once the wallet is showing, where a failed refresh changes nothing.
    func walletUnreachable(hasCachedWallet: Bool) {
        guard route == .config else { return }

        if hasCachedWallet {
            diagnostics.record(.wallet, "Couldn't reach the wallet; showing the cached one until the connection is back")
            configSuccessful()
        } else {
            diagnostics.record(.wallet, "Couldn't reach the wallet and nothing is cached; the pairing is kept")
            configStatus = .unreachable
        }
    }

    /// Asks for the wallet connection to be tried again.
    func retryWalletConnection() {
        if route == .config {
            configStatus = .connecting
        }
        triggerDataSync = true
    }

    /// The connection came back while the wallet was already showing cached data, so
    /// the transactions that couldn't load are fetched now.
    func walletReconnected() {
        guard route == .wallet else { return }
        diagnostics.record(.wallet, "Reconnected to the wallet; catching up")
        walletState.triggerTransactionSync = true
    }
    
    func configSuccessful() {
        route = .wallet

        guard let pendingPaymentInput else { return }
        self.pendingPaymentInput = nil
        diagnostics.record(.url, "The wallet is ready; handing over the held payment URI")
        walletState.send(pendingPaymentInput)
    }
    
    func saveInfo(_ info: WalletConnectManager.WalletInfo) {
        configSuccessful()
    }
    
    func savePrice(_ price: BTCPrice?) {
        walletState.btcPrice = price
    }
    
    /// Routes back to setup. The credential and connection teardown runs in
    /// `LogoutTracker`, which observes `triggerLogout`.
    func logout(error: LocalizedStringKey? = nil) {
        triggerLogout.toggle()
        triggerDataSync = false
        configStatus = .connecting
        presentDisconnectDialog = false
        pendingPaymentInput = nil
        setupState.errorMessage = error
        route = .setup
    }
}
