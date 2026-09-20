//
//  SendDetailsView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 1/21/24.
//

import SwiftUI
import SwiftData
import LightningDevKit

struct SendDetailsView: View {
    @Environment(SendState.self) private var state
    @Environment(\.diagnostics) private var diagnostics
    var lightningAddress: String
    @State private var amount: UInt64 = 0
    @State private var isLoading = false
    @State private var errorMessage: LocalizedStringKey?
    @State private var generateInvoiceTrigger = PlainTaskTrigger()
    @Query private var wallets: [Wallet]

    private var wallet: Wallet? {
        wallets.first
    }

    private var maxAmount: UInt64 {
        UInt64(wallet?.balance.millisatsToSats ?? 0)
    }

    private var btcPrice: Double? {
        state.btcPrice
    }

    var body: some View {
        VStack(spacing: 0) {
            // Recipient header
            recipientHeader

            // Amount entry
            AmountEntryView(
                amount: $amount,
                maxAmount: maxAmount,
                btcPrice: btcPrice,
                buttonTitle: "Continue",
                isLoading: isLoading
            ) {
                triggerGenerateInvoice()
            }
        }
        .fullScreenColorView()
        .navigationTitle("Send")
        .navigationBarTitleDisplayMode(.inline)
        .alert($errorMessage)
        .task($generateInvoiceTrigger) { await generateInvoiceAndContinue() }
    }

    // MARK: - Subviews

    private var recipientHeader: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.Accent.primary)
                .frame(width: 32, height: 32)
                .background(DesignTokens.Colors.Accent.primary.opacity(0.15))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Sending to")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color.ds.textTertiary)

                Text(lightningAddress)
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(DesignTokens.Colors.Background.secondary)
    }

    // MARK: - Actions

    private func triggerGenerateInvoice() {
        generateInvoiceTrigger.trigger()
    }

    private func generateInvoiceAndContinue() async {
        isLoading = true
        defer { isLoading = false }

        guard amount >= 1 else {
            diagnostics.record(.send, "Rejected the amount: none entered")
            errorMessage = "Please enter an amount"
            return
        }

        guard amount <= 5_000_000 else {
            diagnostics.record(.send, "Rejected the amount: \(amount) sats is over the 5,000,000 sat cap")
            errorMessage = "Amount must be 5,000,000 sats or less"
            return
        }

        guard amount <= maxAmount else {
            diagnostics.record(.send, "Rejected the amount: \(amount) sats exceeds the \(maxAmount) sat balance")
            errorMessage = "Amount exceeds available balance"
            return
        }

        let millisats = "\(amount * 1000)"
        diagnostics.record(.send, "Requesting an invoice for \(amount) sats over LNURL-pay", detail: lightningAddress)

        do {
            let invoice = try await GenerateInvoiceService().generateInvoice(
                lightningAddress: lightningAddress,
                amount: millisats,
                comment: nil
            )

            guard let invoicePR = invoice.pr, !invoicePR.isEmpty else {
                diagnostics.record(.send, "LNURL-pay answered without an invoice")
                errorMessage = "Failed to create invoice. Please try again."
                return
            }

            // Validate the invoice using LightningDevKit
            guard Bolt11Invoice.fromStr(s: invoicePR).getValue() != nil else {
                diagnostics.record(.send, "LNURL-pay returned an invoice LDK couldn't parse", detail: invoicePR)
                errorMessage = "Failed to create invoice. Please try again."
                return
            }

            diagnostics.record(.send, "Received an invoice over LNURL-pay; moving to review", detail: invoicePR)

            // Navigate to review screen
            state.navigateToReview(recipient: lightningAddress, amount: amount, invoicePR: invoicePR)
        } catch {
            diagnostics.record(.send, "The LNURL-pay request failed", detail: String(describing: error))
            errorMessage = "Failed to create invoice. Please try again."
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var appState = AppState()

    NavigationStack {
        SendDetailsView(lightningAddress: "sparrowtek@getalby.com")
            .environment(appState.walletState.sendState)
    }
}
