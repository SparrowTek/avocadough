//
//  LogoutTracker.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 6/6/25.
//

import SwiftUI
import SwiftData

fileprivate struct LogoutTracker: ViewModifier {
    @Environment(AppState.self) private var state
    @Environment(\.nwc) private var nwc
    @Environment(\.modelContext) private var context
    @State private var logoutTrigger = PlainTaskTrigger()
    @Query private var nwcConnections: [NWCConnection]
    @Query private var transactions: [Transaction]
    @Query private var wallets: [Wallet]
    
    func body(content: Content) -> some View {
        content
            .onChange(of: state.triggerLogout, triggerLogout)
            .task($logoutTrigger, logout)
    }
    
    private func triggerLogout() {
        logoutTrigger.trigger()
    }
    
    private func logout() async {
        nwc.logout()
        nwcConnections.forEach { context.delete($0) }
        transactions.forEach { context.delete($0) }
        wallets.forEach { context.delete($0) }
        try? context.save()
    }
}

extension View {
    func logoutTracker() -> some View {
        modifier(LogoutTracker())
    }
}

#Preview {
    Text("Logout Data")
        .logoutTracker()
        .environment(AppState())
        .environment(\.nwc, NWC())
}
