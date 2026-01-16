//
//  SetupPresenter.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/6/24.
//

import SwiftUI
import SwiftData
@preconcurrency import AVFoundation

struct SetupPresenter: View {
    @Environment(SetupState.self) private var state
    @Environment(\.nwc) private var nwc

    var body: some View {
        @Bindable var state = state

        Group {
            switch state.step {
            case .welcome:
                WelcomeView()
            case .connect:
                ConnectWalletView()
            }
        }
        .sheet(item: $state.sheet) {
            switch $0 {
            case .scanQR:
                NavigationStack {
                    ScanQRCodeView()
                        .environment(state.scanQRCodeState)
                }
            }
        }
        .alert($state.errorMessage)
    }
}

// MARK: - Welcome View

private struct WelcomeView: View {
    @Environment(SetupState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showLogo = false
    @State private var showContent = false
    @State private var showButton = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Animated logo
            logoSection

            // Welcome text
            contentSection

            Spacer()

            // Get Started button
            buttonSection
        }
        .padding(DesignTokens.Spacing.xl)
        .fullScreenColorView()
        .onAppear(perform: animateIn)
    }

    private var logoSection: some View {
        ZStack {
            // Pulse rings
            if !reduceMotion {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .stroke(DesignTokens.Colors.Accent.primary.opacity(0.2), lineWidth: 2)
                        .frame(width: 140 + CGFloat(index * 30), height: 140 + CGFloat(index * 30))
                        .scaleEffect(pulseScale)
                        .opacity(showLogo ? 1 : 0)
                }
            }

            // Logo circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [DesignTokens.Colors.Accent.primary, DesignTokens.Colors.Accent.primary.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .shadow(color: DesignTokens.Colors.Accent.primary.opacity(0.3), radius: 20, x: 0, y: 10)
                .scaleEffect(showLogo ? 1 : 0.5)
                .opacity(showLogo ? 1 : 0)

            // Lightning bolts
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                Image(systemName: "bolt.fill")
            }
            .font(.system(size: 40, weight: .bold))
            .foregroundStyle(.white)
            .scaleEffect(showLogo ? 1 : 0)
            .opacity(showLogo ? 1 : 0)
        }
        .animation(reduceMotion ? .none : DesignTokens.Animation.bouncy, value: showLogo)
    }

    private var contentSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Text("Avocadough")
                .font(DesignTokens.Typography.largeTitle)
                .foregroundStyle(Color.ds.textPrimary)

            Text("Your Bitcoin,\nYour Control.")
                .font(DesignTokens.Typography.title2)
                .foregroundStyle(Color.ds.textSecondary)
                .multilineTextAlignment(.center)

            Text("A beautiful wallet for the\nLightning Network")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(Color.ds.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, DesignTokens.Spacing.sm)
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 20)
        .animation(reduceMotion ? .none : DesignTokens.Animation.smooth.delay(0.2), value: showContent)
    }

    private var buttonSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            AvocadoButton("Get Started", variant: .primary, size: .large) {
                state.continueFromWelcome()
            }
        }
        .opacity(showButton ? 1 : 0)
        .offset(y: showButton ? 0 : 20)
        .animation(reduceMotion ? .none : DesignTokens.Animation.smooth.delay(0.4), value: showButton)
    }

    private func animateIn() {
        if reduceMotion {
            showLogo = true
            showContent = true
            showButton = true
        } else {
            withAnimation(DesignTokens.Animation.bouncy) {
                showLogo = true
            }

            withAnimation(
                .easeInOut(duration: 2)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.1
            }

            showContent = true
            showButton = true
        }
    }
}

// MARK: - Connect Wallet View

private struct ConnectWalletView: View {
    @Environment(SetupState.self) private var state
    @Environment(\.nwc) private var nwc
    @Environment(\.modelContext) private var context
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var nwcCodes: [NWCConnection]
    @State private var requestCameraAccessTrigger = PlainTaskTrigger()
    @State private var evaluateConnectionSecretTrigger = PlainTaskTrigger()
    @State private var isConnecting = false
    @State private var hasAppeared = false

    var body: some View {
        @Bindable var state = state

        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Header
            headerSection

            // Connection options
            connectionOptions

            Spacer()

            // Manual input
            manualInputSection
        }
        .padding(DesignTokens.Spacing.xl)
        .fullScreenColorView()
        .onChange(of: nwc.hasConnected) { configApp() }
        .task(id: state.foundQRCode) { await parseWalletCode() }
        .task($requestCameraAccessTrigger) { await requestCameraAccess() }
        .task($evaluateConnectionSecretTrigger) { await evaluateConnectionSecret() }
        .onAppear {
            if !reduceMotion {
                hasAppeared = true
            } else {
                hasAppeared = true
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(DesignTokens.Colors.Accent.primary)
                .opacity(hasAppeared ? 1 : 0)
                .scaleEffect(hasAppeared ? 1 : 0.8)
                .animation(reduceMotion ? .none : DesignTokens.Animation.bouncy, value: hasAppeared)

            Text("Connect Your Wallet")
                .font(DesignTokens.Typography.title1)
                .foregroundStyle(Color.ds.textPrimary)

            Text("Scan the NWC QR code from your\nwallet provider to get started")
                .font(DesignTokens.Typography.body)
                .foregroundStyle(Color.ds.textSecondary)
                .multilineTextAlignment(.center)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(reduceMotion ? .none : DesignTokens.Animation.smooth.delay(0.1), value: hasAppeared)
    }

    private var connectionOptions: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Scan QR option
            Button(action: tappedScanQR) {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 28))
                        .foregroundStyle(DesignTokens.Colors.Accent.primary)
                        .frame(width: 56, height: 56)
                        .background(DesignTokens.Colors.Accent.primary.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Scan QR Code")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(Color.ds.textPrimary)

                        Text("Use your camera to scan")
                            .font(DesignTokens.Typography.subheadline)
                            .foregroundStyle(Color.ds.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.ds.textTertiary)
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.Background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            }
            .buttonStyle(.plain)
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(reduceMotion ? .none : DesignTokens.Animation.smooth.delay(0.2), value: hasAppeared)
    }

    private var manualInputSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Divider with text
            HStack {
                Rectangle()
                    .fill(DesignTokens.Colors.Component.border)
                    .frame(height: 1)
                Text("or paste connection string")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color.ds.textTertiary)
                Rectangle()
                    .fill(DesignTokens.Colors.Component.border)
                    .frame(height: 1)
            }

            // Input field
            HStack(spacing: DesignTokens.Spacing.sm) {
                TextField("nostr+walletconnect://...", text: Binding(
                    get: { state.connectionSecret },
                    set: { state.connectionSecret = $0 }
                ))
                .font(DesignTokens.Typography.body)
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.Background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button(action: triggerEvaluateConnectionSecret) {
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(DesignTokens.Colors.Accent.primary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
                .disabled(state.connectionSecret.isEmpty || isConnecting)
                .opacity(state.connectionSecret.isEmpty ? 0.5 : 1)
            }

            // Help link
            Link(destination: URL(string: "https://nwc.dev")!) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text("Need a wallet?")
                        .foregroundStyle(Color.ds.textTertiary)
                    Text("Get one here")
                        .foregroundStyle(DesignTokens.Colors.Accent.primary)
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Colors.Accent.primary)
                }
                .font(DesignTokens.Typography.subheadline)
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .animation(reduceMotion ? .none : DesignTokens.Animation.smooth.delay(0.3), value: hasAppeared)
    }

    // MARK: - Actions

    private func triggerEvaluateConnectionSecret() {
        evaluateConnectionSecretTrigger.trigger()
    }

    private func evaluateConnectionSecret() async {
        guard !state.connectionSecret.isEmpty else { return }
        isConnecting = true
        await parseWalletCode(state.connectionSecret)
        isConnecting = false
    }

    private func tappedScanQR() {
        state.foundQRCode = nil
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

        if cameraAuthorizationStatus == .authorized {
            state.sheet = .scanQR
        } else {
            triggerRequestCameraAccess()
        }
    }

    private func triggerRequestCameraAccess() {
        requestCameraAccessTrigger.trigger()
    }

    private func requestCameraAccess() async {
        let isPermissionGranted = await AVCaptureDevice.requestAccess(for: .video)

        if isPermissionGranted {
            state.sheet = .scanQR
        }
    }

    private func parseWalletCode() async {
        guard let code = state.foundQRCode else { return }
        isConnecting = true
        await parseWalletCode(code)
        isConnecting = false
    }

    private func parseWalletCode(_ code: String) async {
        do {
            let nwcCode = try nwc.parseWalletCode(code)
            context.insert(nwcCode)
            try context.save()

            do {
                try await nwc.initializeNWCClient(pubKey: nwcCode.pubKey, relay: nwcCode.relay, lud16: nwcCode.lud16)
            } catch {
                state.errorMessage = "Failed to connect wallet. Please check your connection string and try again."
            }
        } catch {
            state.errorMessage = "Invalid connection string. Please scan a valid NWC QR code."
        }
    }

    private func configApp() {
        state.walletSuccessfullyConnected()
    }
}

// MARK: - Preview

#Preview("Welcome") {
    let state = SetupState(parentState: AppState())
    state.step = .welcome

    return SetupPresenter()
        .environment(state)
        .environment(state.scanQRCodeState)
        .environment(\.nwc, NWC())
}

#Preview("Connect") {
    let state = SetupState(parentState: AppState())
    state.step = .connect

    return SetupPresenter()
        .environment(state)
        .environment(state.scanQRCodeState)
        .environment(\.nwc, NWC())
}
