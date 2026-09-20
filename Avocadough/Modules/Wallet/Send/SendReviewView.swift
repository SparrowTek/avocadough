//
//  SendReviewView.swift
//  Avocadough
//

import SwiftUI
import NostrKit

struct SendReviewView: View {
    @Environment(SendState.self) private var state
    @Environment(\.nwc) private var nwc
    @Environment(\.diagnostics) private var diagnostics

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

        diagnostics.record(.send, "Paying \(amount) sats", detail: "to \(recipient)\n\(invoicePR)")

        do {
            let _ = try await nwc.payInvoice(invoicePR)
            diagnostics.record(.send, "Payment succeeded; showing the success screen")
            state.showPaymentSuccess(amount: amount, recipient: recipient)
        } catch {
            if case .nostrKit(let inner) = error,
               let relayError = inner as? RelayError,
               case .timeout = relayError {
                diagnostics.record(.send, "The relay didn't answer in time; asking the wallet what happened")
                await resolveTimedOutPayment()
            } else {
                diagnostics.record(.send, "Payment failed; showing the error alert", detail: String(describing: error))
                errorMessage = "Payment failed. Please check your wallet and try again."
            }
        }
    }

    /// The request went out but no response arrived in time, so the outcome is unknown.
    /// Ask the wallet before deciding: only a payment it reports as failed is shown as
    /// one. Anything else (settled, still pending, or a wallet that can't look payments
    /// up) keeps the optimistic path, and transaction sync shows the final state.
    private func resolveTimedOutPayment() async {
        guard let paymentHash = DecodedInvoice(invoicePR)?.paymentHash,
              let payment = try? await nwc.lookupInvoice(paymentHash: paymentHash),
              payment.state == .failed else {
            diagnostics.record(.send, "The wallet didn't report a failure; showing the success screen")
            state.showPaymentSuccess(amount: amount, recipient: recipient)
            return
        }

        diagnostics.record(.send, "The wallet reports the payment failed; showing the error alert")
        errorMessage = "Payment failed. Please check your wallet and try again."
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
