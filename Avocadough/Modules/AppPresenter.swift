//
//  ContentView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/9/23.
//

import SwiftUI

struct AppPresenter: View {
    @Environment(AppState.self) private var state
    @Environment(\.nwc) private var nwc
    
    var body: some View {
        @Bindable var state = state
        
        Group {
            switch state.route {
            case .setup:
                SetupPresenter()
                    .environment(state.setupState)
            case .config:
                ConfigView()
            case .wallet:
                WalletPresenter()
                    .environment(state.walletState)
            }
        }
        .onOpenURL()
        .onAppear(perform: determineRoute)
        .logoutTracker()
    }
    
    private func determineRoute() {
        state.determineRoute()
    }
}

#Preview {
    AppPresenter()
        .setupModel()
        .environment(\.nwc, NWC())
        .environment(AppState())
        .environment(ScanQRCodeState(parentState: SetupState(parentState: .init())))
}
