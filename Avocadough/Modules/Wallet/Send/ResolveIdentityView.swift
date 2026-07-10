//
//  ResolveIdentityView.swift
//  Avocadough
//

import SwiftUI
import AvocadoughKit

struct ResolveIdentityView: View {
    @Environment(SendState.self) private var state
    var identifier: String
    @State private var resolutionErrorMessage: String?
    @State private var resolutionAttempt = 0

    private var displayIdentifier: String {
        identifier.hasPrefix("did:") ? identifier : "@\(identifier)"
    }

    var body: some View {
        Group {
            if let resolutionErrorMessage {
                errorContent(resolutionErrorMessage)
            } else {
                resolvingContent
            }
        }
        .fullScreenColorView()
        .navigationTitle("Send")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: resolutionAttempt) { await resolve() }
    }

    // MARK: - Subviews

    private var resolvingContent: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            ProgressView()
                .controlSize(.large)
                .tint(DesignTokens.Colors.Accent.primary)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("Looking up")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color.ds.textTertiary)

                Text(displayIdentifier)
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(DesignTokens.Spacing.lg)
    }

    private func errorContent(_ message: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.Accent.primary)

            Text(message)
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(Color.ds.textPrimary)
                .multilineTextAlignment(.center)

            AvocadoButton("Retry", action: retry)

            AvocadoButton("Back", variant: .ghost, action: goBack)
        }
        .padding(DesignTokens.Spacing.lg)
    }

    // MARK: - Actions

    private func retry() {
        resolutionErrorMessage = nil
        resolutionAttempt += 1
    }

    private func goBack() {
        _ = state.path.popLast()
    }

    private func resolve() async {
        do {
            let resolved = try await PaymentTargetResolver().resolve(.atIdentifier(identifier))

            guard let lightningAddress = resolved.preferredLightningAddress else {
                resolutionErrorMessage = "\(displayIdentifier) has not published a Lightning address."
                return
            }

            state.identityResolved(resolved.identity, lightningAddress: lightningAddress)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            resolutionErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var appState = AppState()

    NavigationStack {
        ResolveIdentityView(identifier: "alice.bsky.social")
            .environment(appState.walletState.sendState)
    }
}
