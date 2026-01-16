//
//  MainTabView.swift
//  Avocadough
//

import SwiftUI

// MARK: - MainTabView

struct MainTabView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        
        TabView(selection: $state.selectedTab) {
            Tab(AppState.Tab.wallet.title, systemImage: AppState.Tab.wallet.icon, value: .wallet) {
                WalletPresenter()
                    .environment(state.walletState)
            }
            
            Tab(AppState.Tab.activity.title, systemImage: AppState.Tab.activity.icon, value: .activity) {
                ActivityPresenter()
                    .environment(state.activityState)
            }
            
            Tab(AppState.Tab.settings.title, systemImage: AppState.Tab.settings.icon, value: .settings) {
                SettingsPresenter()
                    .environment(state.settingsState)
            }
        }
        .tint(DesignTokens.Colors.Accent.primary)
    }
}

// MARK: - Preview

#Preview(traits: .sampleComposite) {
    @Previewable @State var state = AppState()
    
    MainTabView()
        .environment(state)
        .environment(\.reachability, Reachability())
}
