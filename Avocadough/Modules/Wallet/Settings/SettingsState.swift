//
//  SettingsState.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/10/23.
//

import Foundation

@Observable
@MainActor
class SettingsState {
    enum NavigationLink: Hashable {
        case about
        case privacy
        case theme
        case support
    }
    
    private unowned let parentState: WalletState
    var path: [SettingsState.NavigationLink] = []
    var presentNWCDisconnectDialog = false
    
    init(parentState: WalletState) {
        self.parentState = parentState
    }
    
    func disconnectNWC() {
        parentState.disconnectNWC()
    }
    
    func routeToSupport() {
        path = []
        parentState.routeToSupport()
    }
}
