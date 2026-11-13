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
    
    var route: Route = .setup
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
    
    func determineRoute() async {
        if (try? await Vault.shared.read(configuration: .nwcSecret)) != nil {
            route = .config
        } else {
            route = .setup
        }
    }
    
    func walletSuccessfullyConnected() {
        route = .config
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
        pendingPaymentInput = nil
        setupState.errorMessage = error
        route = .setup
    }
}
