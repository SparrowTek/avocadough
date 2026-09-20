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
    @Environment(\.diagnostics) private var diagnostics

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
        .task { await launch() }
        .logoutTracker()
    }
    
    /// Notes the launch in the diagnostics trail, then lets AppState pick the route.
    private func launch() async {
        diagnostics.record(.app, "Launched Avocadough \(Build.shared.version) (\(Build.shared.build)) · \(Build.shared.environment.rawValue)")
        await state.determineRoute()
        diagnostics.record(.app, "Initial route: \(state.route)")
    }
}

#Preview {
    AppPresenter()
        .setupModel()
        .environment(\.nwc, NWC())
        .environment(AppState())
        .environment(ScanQRCodeState(parentState: SetupState(parentState: .init())))
}
