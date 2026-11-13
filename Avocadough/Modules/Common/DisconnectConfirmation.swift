//
//  DisconnectConfirmation.swift
//  Avocadough
//

import SwiftUI

/// Asks before the wallet pairing and all local data are removed, then removes them.
///
/// Clearing local data includes the AT Protocol session. It goes first, because
/// disconnecting the wallet replaces the screen this is attached to.
fileprivate struct DisconnectConfirmation: ViewModifier {
    @Environment(AuthManager.self) private var authManager
    @State private var disconnectTrigger = PlainTaskTrigger()
    @Binding var isPresented: Bool
    let disconnect: @MainActor () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Are you sure you want to disconnect?", isPresented: $isPresented, titleVisibility: .visible) {
                Button("Disconnect", role: .destructive, action: triggerDisconnect)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(message)
            }
            .task($disconnectTrigger) { await signOutAndDisconnect() }
    }

    private var message: LocalizedStringKey {
        if authManager.isLoggedIn {
            "This will remove your wallet connection and all local data, and sign you out of your AT Protocol identity. Your published payment address stays in place."
        } else {
            "This will remove your wallet connection and all local data."
        }
    }

    private func triggerDisconnect() {
        disconnectTrigger.trigger()
    }

    private func signOutAndDisconnect() async {
        await authManager.logout()
        disconnect()
    }
}

extension View {
    /// Presents the "disconnect and clear data" confirmation. `disconnect` runs once the
    /// user confirms and the identity session has been signed out.
    func disconnectConfirmation(isPresented: Binding<Bool>, disconnect: @escaping @MainActor () -> Void) -> some View {
        modifier(DisconnectConfirmation(isPresented: isPresented, disconnect: disconnect))
    }
}

#Preview {
    @Previewable @State var isPresented = true

    Button("Disconnect Wallet", role: .destructive) { isPresented = true }
        .disconnectConfirmation(isPresented: $isPresented) {}
        .environment(AuthManager())
}
