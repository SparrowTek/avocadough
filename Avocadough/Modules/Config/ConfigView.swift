//
//  ConfigView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/31/23.
//

import SwiftUI

struct ConfigView: View {
    @Environment(AppState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showContent = false
    @State private var pulseScale: CGFloat = 1.0

    private var isConnecting: Bool {
        state.configStatus == .connecting
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Logo with pulse
            ZStack {
                if !reduceMotion {
                    Circle()
                        .stroke(DesignTokens.Colors.Accent.primary.opacity(0.2), lineWidth: 2)
                        .frame(width: 100, height: 100)
                        .scaleEffect(pulseScale)
                        .opacity(isConnecting ? 1 : 0)
                }

                Circle()
                    .fill(DesignTokens.Colors.Accent.primary)
                    .frame(width: 80, height: 80)

                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                    Image(systemName: "bolt.fill")
                }
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            }
            .opacity(showContent ? 1 : 0)
            .scaleEffect(showContent ? 1 : 0.8)

            Group {
                switch state.configStatus {
                case .connecting:
                    // Loading text
                    VStack(spacing: DesignTokens.Spacing.md) {
                        Text("Preparing your wallet")
                            .font(DesignTokens.Typography.title2)
                            .foregroundStyle(Color.ds.textPrimary)

                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(DesignTokens.Colors.Accent.primary)
                    }
                case .unreachable:
                    WalletUnreachableView()
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)

            Spacer()
        }
        .fullScreenColorView()
        .syncConfigData()
        .onAppear(perform: animateIn)
        .animation(reduceMotion ? .none : DesignTokens.Animation.smooth, value: showContent)
        .animation(reduceMotion ? .none : DesignTokens.Animation.smooth, value: state.configStatus)
    }

    private func animateIn() {
        showContent = true

        if !reduceMotion {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.2
            }
        }
    }
}

// MARK: - Wallet Unreachable

/// Shown when the paired wallet couldn't be reached and nothing is cached to open on.
/// The pairing is kept, so the only ways forward are trying again or disconnecting on
/// purpose.
private struct WalletUnreachableView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state

        VStack(spacing: DesignTokens.Spacing.lg) {
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text("Can't reach your wallet")
                    .font(DesignTokens.Typography.title2)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("Check your internet connection and that your wallet is online, then try again. Your wallet stays paired until you disconnect it.")
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            .multilineTextAlignment(.center)

            AvocadoButton("Try Again", icon: "arrow.clockwise", action: retry)

            Button("Disconnect Wallet", role: .destructive, action: confirmDisconnect)
                .font(DesignTokens.Typography.subheadline)
                .disconnectConfirmation(isPresented: $state.presentDisconnectDialog, disconnect: disconnect)
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }

    private func retry() {
        state.retryWalletConnection()
    }

    private func confirmDisconnect() {
        state.presentDisconnectDialog = true
    }

    private func disconnect() {
        state.logout()
    }
}

#Preview("Connecting") {
    ConfigView()
        .setupModel(inMemory: true)
        .environment(AppState())
        .environment(AuthManager())
}

#Preview("Unreachable") {
    @Previewable @State var state = AppState()

    ConfigView()
        .setupModel(inMemory: true)
        .environment(state)
        .environment(AuthManager())
        .onAppear { state.configStatus = .unreachable }
}
