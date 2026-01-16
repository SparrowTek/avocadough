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
    
    enum Tab: Int, CaseIterable {
        case wallet
        case activity
        case settings

        var title: LocalizedStringKey {
            switch self {
            case .wallet: "Wallet"
            case .activity: "Activity"
            case .settings: "Settings"
            }
        }

        var icon: String {
            switch self {
            case .wallet: "bitcoinsign.circle.fill"
            case .activity: "list.bullet.rectangle.portrait.fill"
            case .settings: "gearshape.fill"
            }
        }
    }
    
    var route: Route = .setup
    var selectedTab: AppState.Tab = .wallet
    var triggerDataSync = false
    var triggerLogout = false
    
    @ObservationIgnored
    lazy var walletState = WalletState(parentState: self)
    @ObservationIgnored
    lazy var setupState = SetupState(parentState: self)
    @ObservationIgnored
    lazy var settingsState = SettingsState(parentState: self)
    @ObservationIgnored
    lazy var activityState = ActivityState(parentState: self)
    
    func onOpenURL(_ url: URL) async {
        guard url.scheme == "avocadough" else { return }
        
        switch url.host() {
        default:
            break
        }
    }
    
    func determineRoute() {
        do {
            let _ = try Vault.getPrivateKey(keychainConfiguration: .nwcSecret)
            route = .config
        } catch {
            route = .setup
        }
    }
    
    func walletSuccessfullyConnected() {
        route = .config
    }
    
    func configSuccessful() {
        route = .wallet
    }
    
    func saveInfo(_ info: WalletConnectManager.WalletInfo) {
        configSuccessful()
    }
    
    func savePrice(_ price: BTCPrice?) {
        walletState.btcPrice = price
    }
    
    func logout(error: LocalizedStringKey? = nil) {
        triggerLogout.toggle()
        setupState.errorMessage = error
        try? Vault.deletePrivateKey(keychainConfiguration: .nwcSecret)
        route = .setup
    }
}
