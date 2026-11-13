//
//  ATProtoIdentityView.swift
//  Avocadough
//

import SwiftUI
import SwiftData
import AvocadoughKit

/// Settings → Identity: sign in with an AT Protocol identity and publish the connected
/// wallet's Lightning address as an `xyz.avocadough.payment.endpoint` record, the piece
/// that makes `@handle` a payable address for anyone running a resolver.
struct ATProtoIdentityView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.diagnostics) private var diagnostics
    @Query private var nwcConnections: [NWCConnection]

    @State private var handleInput = ""
    @State private var publishedAddress: PublishedPaymentAddress = .unknown
    @State private var isWorking = false
    @State private var actionError: String?
    @State private var signInTrigger = PlainTaskTrigger()
    @State private var refreshTrigger = PlainTaskTrigger()
    @State private var publishTrigger = PlainTaskTrigger()
    @State private var unpublishTrigger = PlainTaskTrigger()
    @State private var signOutTrigger = PlainTaskTrigger()

    /// The Lightning address of the connected wallet, the only address this screen
    /// offers to publish.
    private var walletAddress: String? {
        guard let address = nwcConnections.first?.lud16, !address.isEmpty else { return nil }
        return address
    }

    private var displayHandle: String {
        authManager.currentHandle.map { "@\($0)" } ?? String(localized: "your handle")
    }

    var body: some View {
        Form {
            if authManager.isLoggedIn {
                accountSection
                paymentAddressSection
                signOutSection
            } else if authManager.isRestoringSession {
                restoringSection
            } else {
                signInSection
            }
        }
        .fullScreenColorView()
        .navigationTitle("Identity")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: authManager.currentDID) { await refreshPublishedAddress() }
        .task($signInTrigger) { await signIn() }
        .task($refreshTrigger) { await refreshPublishedAddress() }
        .task($publishTrigger) { await publish() }
        .task($unpublishTrigger) { await unpublish() }
        .task($signOutTrigger) { await signOut() }
        .onDisappear { authManager.clearAuthError() }
    }

    // MARK: - Signed out

    private var signInSection: some View {
        Section {
            TextField("you.bsky.social", text: $handleInput)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .submitLabel(.go)
                .onSubmit(triggerSignIn)

            Button(action: triggerSignIn) {
                if authManager.isAuthenticating {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        ProgressView()
                        Text("Signing in…")
                    }
                } else {
                    Text("Sign in")
                }
            }
            .tint(DesignTokens.Colors.Accent.primary)
            .disabled(!canSignIn)
        } header: {
            Text("Sign in with your handle")
        } footer: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Sign in with an AT Protocol identity, like your Bluesky account, to let people pay you at your handle. You sign in on your account host's own page, and Avocadough only asks for permission to manage its payment address record.")

                if let error = authManager.authError {
                    Text(error)
                        .foregroundStyle(DesignTokens.Colors.Semantic.error)
                }
            }
        }
    }

    private var canSignIn: Bool {
        !authManager.isAuthenticating && SignInIdentifier.normalized(handleInput) != nil
    }

    private var restoringSection: some View {
        Section {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ProgressView()
                Text("Checking your session…")
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
    }

    // MARK: - Signed in

    private var accountSection: some View {
        Section("Signed in as") {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayHandle)
                    .foregroundStyle(Color.ds.textPrimary)

                if let did = authManager.currentDID {
                    Text(did)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(Color.ds.textTertiary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var paymentAddressSection: some View {
        Section {
            publishedAddressRow

            ForEach(actions, id: \.self) { action in
                actionButton(for: action)
            }
        } header: {
            Text("Payment address")
        } footer: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(paymentAddressExplanation)

                if let actionError {
                    Text(actionError)
                        .foregroundStyle(DesignTokens.Colors.Semantic.error)
                }
            }
        }
    }

    @ViewBuilder
    private var publishedAddressRow: some View {
        switch publishedAddress {
        case .unknown, .loading:
            HStack(spacing: DesignTokens.Spacing.sm) {
                ProgressView()
                Text("Checking published address…")
                    .foregroundStyle(Color.ds.textSecondary)
            }
        case .published(let address):
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Published")
                        .font(DesignTokens.Typography.caption.bold())
                        .foregroundStyle(DesignTokens.Colors.Semantic.connected)
                    Text(address)
                        .foregroundStyle(Color.ds.textPrimary)
                        .textSelection(.enabled)
                }
                Spacer()
                workingIndicator
            }
        case .notPublished:
            HStack {
                Text("Not published")
                    .foregroundStyle(Color.ds.textSecondary)
                Spacer()
                workingIndicator
            }
        case .unavailable:
            Text("The published address could not be checked")
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    /// Spins while a change to the published address is on its way to the account host.
    @ViewBuilder
    private var workingIndicator: some View {
        if isWorking {
            ProgressView()
        }
    }

    private var actions: [PublishedPaymentAddress.Action] {
        publishedAddress.actions(
            walletAddress: walletAddress,
            canPublish: authManager.canPublishPaymentEndpoint
        )
    }

    @ViewBuilder
    private func actionButton(for action: PublishedPaymentAddress.Action) -> some View {
        switch action {
        case .publish(let address):
            Button("Publish \(address)", action: triggerPublish)
                .tint(DesignTokens.Colors.Accent.primary)
                .disabled(isWorking)
        case .update(let address):
            Button("Update to \(address)", action: triggerPublish)
                .tint(DesignTokens.Colors.Accent.primary)
                .disabled(isWorking)
        case .unpublish:
            Button("Unpublish payment address", role: .destructive, action: triggerUnpublish)
                .disabled(isWorking)
        case .retry:
            Button("Try again", action: triggerRefresh)
                .tint(DesignTokens.Colors.Accent.primary)
        }
    }

    private var paymentAddressExplanation: LocalizedStringKey {
        if !authManager.canPublishPaymentEndpoint {
            "Your account host signed you in without permission to manage the payment address record, so Avocadough can't change it for this account."
        } else if publishedAddress == .unavailable {
            "Avocadough could not reach your account host to see what is published at \(displayHandle). Check your connection and try again."
        } else if publishedAddress.matches(walletAddress: walletAddress) {
            "Anyone can pay you at \(displayHandle). The payment goes to your connected wallet's Lightning address."
        } else if walletAddress == nil {
            "Your connected wallet has no Lightning address, so there is nothing to publish. Connect a wallet that provides one to be payable at your handle."
        } else {
            "Publishing writes a public record to your AT Protocol account that links \(displayHandle) to this Lightning address, so anyone can pay you at your handle."
        }
    }

    private var signOutSection: some View {
        Section {
            Button("Sign out", role: .destructive, action: triggerSignOut)
                .disabled(isWorking)
        } footer: {
            Text("Signing out leaves your published payment address in place. Unpublish it first if you no longer want to be paid at your handle.")
        }
    }

    // MARK: - Triggers

    private func triggerSignIn() {
        guard canSignIn else { return }
        signInTrigger.trigger()
    }

    private func triggerRefresh() { refreshTrigger.trigger() }
    private func triggerPublish() { publishTrigger.trigger() }
    private func triggerUnpublish() { unpublishTrigger.trigger() }
    private func triggerSignOut() { signOutTrigger.trigger() }

    // MARK: - Actions

    private func signIn() async {
        guard let identifier = SignInIdentifier.normalized(handleInput) else { return }

        diagnostics.record(.identity, "Signing in", detail: identifier)
        await authManager.login(identifier: identifier)

        if authManager.isLoggedIn {
            diagnostics.record(.identity, "Signed in", detail: authManager.currentDID)
            handleInput = ""
        } else if let error = authManager.authError {
            diagnostics.record(.identity, "Sign-in failed", detail: error)
        } else {
            diagnostics.record(.identity, "Sign-in was cancelled")
        }
    }

    /// Reads the record the way anyone paying the handle would: without the session,
    /// straight from the account's host.
    private func refreshPublishedAddress() async {
        guard let did = authManager.currentDID, let host = authManager.currentPDSEndpoint else {
            publishedAddress = .unknown
            actionError = nil
            return
        }

        publishedAddress = .loading
        actionError = nil

        do {
            let record = try await PaymentEndpointPublisher().currentEndpoint(repo: did, host: host)
            publishedAddress = record?.preferredLightningAddress.map { .published($0) } ?? .notPublished
        } catch {
            guard !Task.isCancelled else { return }
            publishedAddress = .unavailable
            diagnostics.record(.identity, "The published payment address could not be read", detail: IdentityFailure.diagnosticDetail(for: error))
        }
    }

    private func publish() async {
        guard let walletAddress, !isWorking else { return }

        isWorking = true
        actionError = nil
        defer { isWorking = false }

        // A session that has run out ends here, and the screen falls back to sign-in.
        await authManager.refreshSessionIfNeeded()
        guard let did = authManager.currentDID else { return }

        do {
            try await PaymentEndpointPublisher().publish(lightningAddress: walletAddress, repo: did)
            publishedAddress = .published(walletAddress)
            diagnostics.record(.identity, "Published the payment address", detail: walletAddress)
        } catch {
            actionError = IdentityFailure.paymentAddressMessage(for: error)
            diagnostics.record(.identity, "Publishing the payment address failed", detail: IdentityFailure.diagnosticDetail(for: error))
        }
    }

    private func unpublish() async {
        guard !isWorking else { return }

        isWorking = true
        actionError = nil
        defer { isWorking = false }

        await authManager.refreshSessionIfNeeded()
        guard let did = authManager.currentDID else { return }

        do {
            try await PaymentEndpointPublisher().unpublish(repo: did)
            publishedAddress = .notPublished
            diagnostics.record(.identity, "Unpublished the payment address")
        } catch {
            actionError = IdentityFailure.paymentAddressMessage(for: error)
            diagnostics.record(.identity, "Unpublishing the payment address failed", detail: IdentityFailure.diagnosticDetail(for: error))
        }
    }

    private func signOut() async {
        await authManager.logout()
        diagnostics.record(.identity, "Signed out")
    }
}

// MARK: - Preview

#Preview(traits: .sampleWalletConnection) {
    NavigationStack {
        ATProtoIdentityView()
    }
    .environment(AuthManager())
}
