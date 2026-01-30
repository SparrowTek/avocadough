//
//  SendReviewView.swift
//  Avocadough
//

import SwiftUI
import NostrKit

struct SendReviewView: View {
    @Environment(SendState.self) private var state
    @Environment(\.nwc) private var nwc

    let recipient: String
    let amount: UInt64
    let invoicePR: String
    let btcPrice: Double?

    @State private var isLoading = false
    @State private var errorMessage: LocalizedStringKey?
    @State private var performPaymentTrigger = PlainTaskTrigger()

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Amount display
            VStack(spacing: DesignTokens.Spacing.sm) {
                Text(formattedAmount)
                    .font(DesignTokens.Typography.amountLarge)
                    .foregroundStyle(Color.ds.textPrimary)

                Text("sats")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(Color.ds.textSecondary)

                if let fiatAmount = formattedFiatAmount {
                    Text("≈ \(fiatAmount)")
                        .font(DesignTokens.Typography.title3)
                        .foregroundStyle(Color.ds.textTertiary)
                }
            }

            // Recipient card
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text("Sending to")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color.ds.textTertiary)
                
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(DesignTokens.Colors.Accent.primary)
                    
                    Text(recipient)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(Color.ds.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.md)
            .avocadogeCard(style: .elevated)
            .padding(.horizontal, DesignTokens.Spacing.md)

            Spacer()

            // Slide to send
            SlideToConfirm(
                title: "Slide to Send",
                subtitle: "\(formattedAmount) sats",
                isLoading: isLoading
            ) {
                sendPayment()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .fullScreenColorView()
        .navigationTitle("Review Payment")
        .navigationBarTitleDisplayMode(.inline)
        .alert($errorMessage)
        .task($performPaymentTrigger) { await performPayment() }
    }

    // MARK: - Formatting

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private var formattedFiatAmount: String? {
        guard let btcPrice else { return nil }
        let btc = Double(amount) / 100_000_000
        let fiatValue = btc * btcPrice
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: fiatValue))
    }

    // MARK: - Actions

    private func sendPayment() {
        performPaymentTrigger.trigger()
    }

    private func performPayment() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let _ = try await nwc.payInvoice(invoicePR)
            state.showPaymentSuccess(amount: amount, recipient: recipient)
        } catch {
            if case .nostrKit(let inner) = error,
               let relayError = inner as? RelayError,
               case .timeout = relayError {
                // Request was published but no response received in time.
                // Payment may have succeeded, so show success and let transaction sync resolve.
                state.showPaymentSuccess(amount: amount, recipient: recipient)
            } else {
                errorMessage = "Payment failed. Please check your wallet and try again."
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SendReviewView(
            recipient: "sparrowtek@getalby.com",
            amount: 21_000,
            invoicePR: "lnbc...",
            btcPrice: 95000
        )
        .environment(SendState(parentState: .init(parentState: .init())))
    }
}
