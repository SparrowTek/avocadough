//
//  PaymentReceivedView.swift
//  Avocadough
//

import SwiftUI

// MARK: - PaymentReceivedView

/// A celebratory view shown after receiving a payment
struct PaymentReceivedView: View {
    let amount: UInt64
    let btcPrice: Double?
    let onDismiss: () -> Void

    @State private var showIcon = false
    @State private var showContent = false
    @State private var showButton = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var receivedTrigger = false

    init(
        amount: UInt64,
        btcPrice: Double? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.amount = amount
        self.btcPrice = btcPrice
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xl) {
            Spacer()

            // Received Icon with animation
            ZStack {
                // Pulse rings
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .stroke(DesignTokens.Colors.Accent.primary.opacity(0.2), lineWidth: 2)
                        .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                        .scaleEffect(pulseScale)
                        .opacity(showIcon ? (1 - Double(index) * 0.3) : 0)
                }

                // Main circle
                Circle()
                    .fill(DesignTokens.Colors.Accent.primary)
                    .frame(width: 100, height: 100)
                    .scaleEffect(showIcon ? 1 : 0.5)
                    .opacity(showIcon ? 1 : 0)

                // Icon
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(showIcon ? 1 : 0)
                    .opacity(showIcon ? 1 : 0)
            }
            .animation(DesignTokens.Animation.bouncy, value: showIcon)

            // Content
            VStack(spacing: DesignTokens.Spacing.md) {
                Text("Payment Received!")
                    .font(DesignTokens.Typography.title1)
                    .foregroundStyle(Color.ds.textPrimary)

                // Amount
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("+\(formattedAmount)")
                        .font(DesignTokens.Typography.amountLarge)
                        .foregroundStyle(DesignTokens.Colors.Accent.primary)

                    Text("sats")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(Color.ds.textSecondary)

                    if let fiatAmount = formattedFiatAmount {
                        Text("≈ \(fiatAmount)")
                            .font(DesignTokens.Typography.title3)
                            .foregroundStyle(Color.ds.textTertiary)
                    }
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
        .sensoryFeedback(AppHaptics.paymentReceived, trigger: receivedTrigger)
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
        receivedTrigger.toggle()

        withAnimation(DesignTokens.Animation.bouncy) {
            showIcon = true
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

// MARK: - Preview

#Preview("Payment Received") {
    PaymentReceivedView(
        amount: 50_000,
        btcPrice: 95000
    ) {
        print("Dismissed")
    }
}
