//
//  NumPad.swift
//  Avocadough
//

import SwiftUI

// MARK: - NumPad

/// A custom numeric keypad for amount entry
struct NumPad: View {
    @Binding var value: UInt64
    let maxValue: UInt64?
    let quickAmounts: [UInt64]
    let onComplete: (() -> Void)?

    @State private var stringValue: String = ""
    @State private var warningTrigger = false
    @State private var quickAmountTrigger = false

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    init(
        value: Binding<UInt64>,
        maxValue: UInt64? = nil,
        quickAmounts: [UInt64] = [1_000, 5_000, 10_000, 25_000],
        onComplete: (() -> Void)? = nil
    ) {
        self._value = value
        self.maxValue = maxValue
        self.quickAmounts = quickAmounts
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Quick amount buttons
            if !quickAmounts.isEmpty {
                quickAmountButtons
            }

            // Number pad
            LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.sm) {
                ForEach(1...9, id: \.self) { number in
                    numPadButton(String(number))
                }

                // Bottom row
                numPadButton("00")
                numPadButton("0")
                deleteButton
            }
        }
        .sensoryFeedback(.selection, trigger: value)
        .sensoryFeedback(.warning, trigger: warningTrigger)
        .sensoryFeedback(AppHaptics.heavyImpact, trigger: quickAmountTrigger)
        .onAppear {
            if value > 0 {
                stringValue = String(value)
            }
        }
    }

    // MARK: - Quick Amount Buttons

    private var quickAmountButtons: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(quickAmounts, id: \.self) { amount in
                Button(action: {
                    setQuickAmount(amount)
                }) {
                    Text(formatQuickAmount(amount))
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignTokens.Colors.Accent.primary)
                        .padding(.horizontal, DesignTokens.Spacing.md)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.Accent.primary.opacity(0.1))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Num Pad Button

    private func numPadButton(_ digit: String) -> some View {
        Button(action: {
            appendDigit(digit)
        }) {
            Text(digit)
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundStyle(Color.ds.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DesignTokens.Colors.Component.fillTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(NumPadButtonStyle())
    }

    private var deleteButton: some View {
        Button(action: deleteLastDigit) {
            Image(systemName: "delete.left")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color.ds.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DesignTokens.Colors.Component.fillTertiary)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(NumPadButtonStyle())
    }

    // MARK: - Actions

    private func appendDigit(_ digit: String) {
        let newValue = stringValue + digit

        // Check max length (prevent overflow)
        guard newValue.count <= 15 else { return }

        // Parse and validate
        if let parsed = UInt64(newValue) {
            if let max = maxValue, parsed > max {
                // Don't allow exceeding max - trigger warning haptic
                warningTrigger.toggle()
                return
            }

            stringValue = newValue
            value = parsed
            // Selection haptic handled by .sensoryFeedback(.selection, trigger: value)
        }
    }

    private func deleteLastDigit() {
        guard !stringValue.isEmpty else { return }

        stringValue.removeLast()

        if stringValue.isEmpty {
            value = 0
        } else if let parsed = UInt64(stringValue) {
            value = parsed
        }
        // Selection haptic handled by .sensoryFeedback(.selection, trigger: value)
    }

    private func setQuickAmount(_ amount: UInt64) {
        if let max = maxValue, amount > max {
            value = max
            stringValue = String(max)
        } else {
            value = amount
            stringValue = String(amount)
        }

        quickAmountTrigger.toggle()
    }

    // MARK: - Formatting

    private func formatQuickAmount(_ amount: UInt64) -> String {
        if amount >= 1_000_000 {
            return "\(amount / 1_000_000)M"
        } else if amount >= 1_000 {
            return "\(amount / 1_000)K"
        }
        return String(amount)
    }
}

// MARK: - NumPad Button Style

private struct NumPadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(DesignTokens.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Complete Amount Entry View

/// A full amount entry screen with display, numpad, and action button
struct AmountEntryView: View {
    @Binding var amount: UInt64
    let maxAmount: UInt64?
    let btcPrice: Double?
    let buttonTitle: LocalizedStringKey
    let isLoading: Bool
    let onSubmit: () -> Void

    @State private var showMaxWarning = false
    @State private var maxButtonTrigger = false

    init(
        amount: Binding<UInt64>,
        maxAmount: UInt64? = nil,
        btcPrice: Double? = nil,
        buttonTitle: LocalizedStringKey = "Continue",
        isLoading: Bool = false,
        onSubmit: @escaping () -> Void
    ) {
        self._amount = amount
        self.maxAmount = maxAmount
        self.btcPrice = btcPrice
        self.buttonTitle = buttonTitle
        self.isLoading = isLoading
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            // Amount display
            AmountInputDisplay(amount: amount, btcPrice: btcPrice)

            Spacer()

            // NumPad
            NumPad(
                value: $amount,
                maxValue: maxAmount
            )

            // Available balance
            if let max = maxAmount {
                HStack {
                    Text("Available:")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(Color.ds.textSecondary)

                    Text(formatSats(max))
                        .font(DesignTokens.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.ds.textPrimary)

                    Text("sats")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(Color.ds.textSecondary)

                    Spacer()

                    Button("Max") {
                        maxButtonTrigger.toggle()
                        amount = max
                    }
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignTokens.Colors.Accent.primary)
                    .sensoryFeedback(AppHaptics.heavyImpact, trigger: maxButtonTrigger)
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }

            // Submit button
            AvocadoButton(
                buttonTitle,
                variant: .primary,
                isLoading: isLoading
            ) {
                onSubmit()
            }
            .disabled(amount == 0 || isLoading)
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .padding(.bottom, DesignTokens.Spacing.md)
    }

    private func formatSats(_ amount: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
}

// MARK: - Previews

#Preview("NumPad") {
    struct PreviewWrapper: View {
        @State private var value: UInt64 = 0

        var body: some View {
            VStack(spacing: DesignTokens.Spacing.lg) {
                Text("\(value) sats")
                    .font(DesignTokens.Typography.amountLarge)

                NumPad(value: $value, maxValue: 1_000_000)
            }
            .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Amount Entry") {
    struct PreviewWrapper: View {
        @State private var amount: UInt64 = 0

        var body: some View {
            AmountEntryView(
                amount: $amount,
                maxAmount: 500_000,
                btcPrice: 45000,
                buttonTitle: "Continue"
            ) {
                print("Submit: \(amount)")
            }
        }
    }

    return PreviewWrapper()
}
