//
//  PaymentSuccessView.swift
//  Avocadough
//

import SwiftUI

// MARK: - PaymentSuccessView

/// A celebratory success view shown after a successful payment
struct PaymentSuccessView: View {
    let amount: UInt64
    let recipient: String?
    let btcPrice: Double?
    let onDismiss: () -> Void

    @State private var showCheckmark = false
    @State private var showContent = false
    @State private var showButton = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var successTrigger = false

    init(
        amount: UInt64,
        recipient: String? = nil,
        btcPrice: Double? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.amount = amount
        self.recipient = recipient
        self.btcPrice = btcPrice
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Success Icon with animation
            ZStack {
                // Pulse rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(DesignTokens.Colors.Semantic.connected.opacity(0.2), lineWidth: 2)
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(pulseScale)
                        .opacity(showCheckmark ? (1 - Double(index) * 0.3) : 0)
                }

                // Main circle
                Circle()
                    .fill(DesignTokens.Colors.Semantic.connected)
                    .frame(width: 100, height: 100)
                    .scaleEffect(showCheckmark ? 1 : 0.5)
                    .opacity(showCheckmark ? 1 : 0)

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(showCheckmark ? 1 : 0)
                    .opacity(showCheckmark ? 1 : 0)
            }
            .animation(DesignTokens.Animation.bouncy, value: showCheckmark)

            // Content
            VStack(spacing: DesignTokens.Spacing.md) {
                Text("Payment Sent!")
                    .font(DesignTokens.Typography.title1)
                    .foregroundStyle(Color.ds.textPrimary)

                // Amount
                VStack(spacing: DesignTokens.Spacing.xs) {
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

                // Recipient
                if let recipient {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text("to")
                            .foregroundStyle(Color.ds.textTertiary)
                        Text(recipient)
                            .foregroundStyle(Color.ds.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .font(DesignTokens.Typography.subheadline)
                }
            }
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 20)
            .animation(DesignTokens.Animation.smooth.delay(0.2), value: showContent)

            Spacer()

            // Done button
            AvocadoButton("Done", variant: .primary) {
                onDismiss()
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .opacity(showButton ? 1 : 0)
            .offset(y: showButton ? 0 : 20)
            .animation(DesignTokens.Animation.smooth.delay(0.4), value: showButton)
        }
        .padding(.bottom, DesignTokens.Spacing.xl)
        .fullScreenColorView()
        .sensoryFeedback(AppHaptics.paymentSent, trigger: successTrigger)
        .onAppear {
            animateIn()
        }
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

    // MARK: - Animation

    private func animateIn() {
        successTrigger.toggle()

        withAnimation(DesignTokens.Animation.bouncy) {
            showCheckmark = true
        }

        // Pulse animation
        withAnimation(
            .easeInOut(duration: 1.5)
            .repeatForever(autoreverses: true)
        ) {
            pulseScale = 1.1
        }

        showContent = true
        showButton = true
    }
}

// MARK: - Compact Success View

/// A smaller inline success indicator
struct CompactSuccessIndicator: View {
    @State private var show = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(DesignTokens.Colors.Semantic.connected)
                .scaleEffect(show ? 1 : 0)

            Text("Sent!")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(DesignTokens.Colors.Semantic.connected)
                .opacity(show ? 1 : 0)
        }
        .animation(DesignTokens.Animation.bouncy, value: show)
        .onAppear {
            show = true
        }
    }
}

// MARK: - Preview

#Preview("Payment Success") {
    PaymentSuccessView(
        amount: 21_000,
        recipient: "jack@getalby.com",
        btcPrice: 95000
    ) {
        print("Dismissed")
    }
}

#Preview("Compact Success") {
    CompactSuccessIndicator()
        .padding()
}
