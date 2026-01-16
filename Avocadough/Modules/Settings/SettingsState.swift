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
    
    private unowned let parentState: AppState
    var path: [SettingsState.NavigationLink] = []
    var presentNWCDisconnectDialog = false
    
    init(parentState: AppState) {
        self.parentState = parentState
    }
    
    func disconnectNWC() {
        // TODO: figure this out now that parent state is not walletState anymore
//        parentState.disconnectNWC()
    }
    
    func routeToSupport() {
        path = []
//        parentState.routeToSupport()
    }
}
