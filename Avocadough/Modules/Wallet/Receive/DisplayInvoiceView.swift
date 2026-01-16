//
//  DisplayInvoiceView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 2/28/24.
//

import SwiftUI
import SwiftData
import LightningDevKit

struct DisplayInvoiceView: View {
    var invoice: MakeInvoiceResponse
    @State private var invoiceCopied = false
    @State private var copyTrigger = false
    @State private var checkInvoiceTrigger = PlainTaskTrigger()
    @State private var copyInvoiceTrigger = PlainTaskTrigger()
    @Environment(ReceiveState.self) private var state
    @State private var requestInProgress = false
    @State private var bolt11: Bolt11Invoice?
    @State private var pulsePhase: CGFloat = 0
    @Query private var transactions: [Transaction]

    private var thisTransaction: Transaction? {
        for transaction in transactions {
            if transaction.invoice == invoice.invoice {
                return transaction
            }
        }
        return nil
    }

    private var isSettled: Bool {
        guard let thisTransaction else { return false }
        return thisTransaction.settledAt != nil
    }

    private var amountSats: UInt64 {
        let millisats = bolt11?.amountMilliSatoshis() ?? 0
        return millisats / 1000
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amountSats)) ?? "\(amountSats)"
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            amountDisplay
            qrCodeSection
            statusView
            Spacer()
            copyButton
            Spacer()
        }
        .fullScreenColorView()
        .navigationTitle("Invoice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: doneTapped)
            }
        }
        .task($checkInvoiceTrigger) { await checkInvoiceStatus() }
        .task($copyInvoiceTrigger) { await copyInvoice() }
        .onAppear {
            setupBolt11()
            startPulseAnimation()
        }
        .onChange(of: isSettled) { _, newValue in
            if newValue {
                state.showPaymentReceived(amount: amountSats)
            }
        }
        .syncTransactionData(requestInProgress: $requestInProgress)
        .sensoryFeedback(AppHaptics.copy, trigger: copyTrigger)
    }

    // MARK: - Amount Display

    private var amountDisplay: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text(formattedAmount)
                .font(DesignTokens.Typography.amountLarge)
                .foregroundStyle(Color.ds.textPrimary)

            Text("sats")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    // MARK: - QR Code Section

    private var qrCodeSection: some View {
        ZStack {
            pulseRings
            qrCodeContainer
        }
    }

    private var pulseRings: some View {
        Group {
            if !isSettled {
                ForEach(0..<3, id: \.self) { index in
                    pulseRing(index: index)
                }
            }
        }
    }

    private func pulseRing(index: Int) -> some View {
        let size: CGFloat = 248 + CGFloat(index * 16)
        let strokeOpacity: Double = 0.3 - Double(index) * 0.1
        let scale: CGFloat = 1 + pulsePhase * 0.05 * CGFloat(index + 1)
        let viewOpacity: Double = Double(1 - pulsePhase * 0.3)
        return RoundedRectangle(cornerRadius: DesignTokens.Radius.lg + 8)
            .stroke(DesignTokens.Colors.Accent.primary.opacity(strokeOpacity), lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(viewOpacity)
    }

    private var qrCodeContainer: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .fill(Color.white)
                .frame(width: 240, height: 240)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)

            QRCodeImage(code: invoice.invoice)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
    }

    // MARK: - Subviews

    private var statusView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            if isSettled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(DesignTokens.Colors.Semantic.connected)
                Text("Paid")
                    .foregroundStyle(DesignTokens.Colors.Semantic.connected)
            } else {
                WaitingIndicator()
                Text("Waiting for payment...")
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .font(DesignTokens.Typography.subheadline)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .background(
            isSettled
                ? DesignTokens.Colors.Semantic.connected.opacity(0.1)
                : DesignTokens.Colors.Background.secondary
        )
        .clipShape(Capsule())
    }

    private var copyButton: some View {
        Button(action: triggerCopyInvoice) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ZStack {
                    Image(systemName: "doc.on.doc")
                        .opacity(invoiceCopied ? 0 : 1)

                    Image(systemName: "checkmark")
                        .foregroundStyle(DesignTokens.Colors.Semantic.connected)
                        .opacity(invoiceCopied ? 1 : 0)
                }

                Text(invoiceCopied ? "Copied!" : "Copy Invoice")
            }
            .font(DesignTokens.Typography.headline)
            .foregroundStyle(invoiceCopied ? DesignTokens.Colors.Semantic.connected : Color.ds.textPrimary)
            .padding(.vertical, DesignTokens.Spacing.md)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .background(DesignTokens.Colors.Background.secondary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(DesignTokens.Animation.snappy, value: invoiceCopied)
    }

    // MARK: - Actions

    private func setupBolt11() {
        bolt11 = Bolt11Invoice.fromStr(s: invoice.invoice).getValue()
    }

    private func startPulseAnimation() {
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulsePhase = 1
        }
    }

    private func doneTapped() {
        state.doneTapped()
    }

    private func triggerCheckInvoiceStatus() {
        checkInvoiceTrigger.trigger()
    }

    private func checkInvoiceStatus() async {
        state.refreshTransactions()
    }

    private func triggerCopyInvoice() {
        copyInvoiceTrigger.trigger()
    }
    
    private func copyInvoice() async {
        UIPasteboard.general.string = bolt11?.toStr()
        invoiceCopied = true
        copyTrigger.toggle()
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        invoiceCopied = false
    }
}

// MARK: - Waiting Indicator

private struct WaitingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(DesignTokens.Colors.Accent.primary)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .opacity(isAnimating ? 1 : 0.3)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever()
                        .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview(traits: .sampleTransactions) {
    @Previewable @State var state = AppState()
    
    NavigationStack {
        DisplayInvoiceView(invoice: MakeInvoiceResponse(invoice: "mkewr34rt8ug", paymentHash: "fmjnds"))
            .environment(state.walletState.receiveState)
            .environment(state.walletState)
    }
}
