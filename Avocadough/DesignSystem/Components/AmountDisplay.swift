//
//  AmountDisplay.swift
//  Avocadough
//

import SwiftUI

// MARK: - Display Unit

/// Currency display units
enum AmountDisplayUnit: CaseIterable {
    case sats
    case btc
    case fiat

    var label: String {
        switch self {
        case .sats: "sats"
        case .btc: "BTC"
        case .fiat: "USD"
        }
    }
}

// MARK: - AmountDisplay

/// A component for displaying Bitcoin amounts with animated currency switching
struct AmountDisplay: View {
    let sats: UInt64
    let btcPrice: Double?
    let isHidden: Bool
    let isLoading: Bool
    let size: AmountDisplaySize
    let onTap: (() -> Void)?

    @State private var displayUnit: AmountDisplayUnit = .sats
    @State private var animationTrigger = false

    enum AmountDisplaySize {
        case small
        case medium
        case large

        var amountFont: Font {
            switch self {
            case .small: DesignTokens.Typography.amountSmall
            case .medium: DesignTokens.Typography.amountMedium
            case .large: DesignTokens.Typography.amountLarge
            }
        }

        var unitFont: Font {
            switch self {
            case .small: DesignTokens.Typography.caption
            case .medium: DesignTokens.Typography.subheadline
            case .large: DesignTokens.Typography.headline
            }
        }

        var secondaryFont: Font {
            switch self {
            case .small: DesignTokens.Typography.caption
            case .medium: DesignTokens.Typography.subheadline
            case .large: DesignTokens.Typography.title3
            }
        }
    }

    init(
        sats: UInt64,
        btcPrice: Double? = nil,
        isHidden: Bool = false,
        isLoading: Bool = false,
        size: AmountDisplaySize = .large,
        onTap: (() -> Void)? = nil
    ) {
        self.sats = sats
        self.btcPrice = btcPrice
        self.isHidden = isHidden
        self.isLoading = isLoading
        self.size = size
        self.onTap = onTap
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            if isLoading {
                loadingView
            } else if isHidden {
                hiddenView
            } else {
                amountView
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: handleTap)
        .sensoryFeedback(.selection, trigger: displayUnit)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to switch currency display")
    }

    // MARK: - Subviews

    private var amountView: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            // Primary amount
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Text(primaryAmount)
                    .font(size.amountFont)
                    .foregroundStyle(Color.ds.textPrimary)
                    .contentTransition(.numericText())

                Text(displayUnit.label)
                    .font(size.unitFont)
                    .foregroundStyle(Color.ds.textSecondary)
            }
            .id(displayUnit)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity),
                removal: .scale(scale: 1.2).combined(with: .opacity)
            ))

            // Secondary amount
            if let secondary = secondaryAmount {
                Text(secondary)
                    .font(size.secondaryFont)
                    .foregroundStyle(Color.ds.textTertiary)
                    .contentTransition(.numericText())
            }
        }
        .animation(DesignTokens.Animation.bouncy, value: displayUnit)
    }

    private var hiddenView: some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text("••••••")
                .font(size.amountFont)
                .foregroundStyle(Color.ds.textPrimary)

            Text("Tap to reveal")
                .font(size.secondaryFont)
                .foregroundStyle(Color.ds.textTertiary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading...")
                .font(size.secondaryFont)
                .foregroundStyle(Color.ds.textTertiary)
        }
    }

    // MARK: - Computed Values

    private var primaryAmount: String {
        switch displayUnit {
        case .sats:
            formatSats(sats)
        case .btc:
            formatBTC(sats)
        case .fiat:
            formatFiat(sats, price: btcPrice)
        }
    }

    private var secondaryAmount: String? {
        switch displayUnit {
        case .sats:
            if let btcPrice {
                return "≈ \(formatFiat(sats, price: btcPrice))"
            }
            return nil
        case .btc:
            return "≈ \(formatSats(sats)) sats"
        case .fiat:
            return "≈ \(formatSats(sats)) sats"
        }
    }

    private var accessibilityLabel: String {
        if isHidden {
            return "Balance hidden"
        }
        if isLoading {
            return "Loading balance"
        }
        let satsString = formatSats(sats)
        if let btcPrice {
            let fiatString = formatFiat(sats, price: btcPrice)
            return "\(satsString) sats, approximately \(fiatString)"
        }
        return "\(satsString) sats"
    }

    // MARK: - Formatting

    private func formatSats(_ amount: UInt64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private func formatBTC(_ sats: UInt64) -> String {
        let btc = Double(sats) / 100_000_000
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 8
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: btc)) ?? String(format: "%.8f", btc)
    }

    private func formatFiat(_ sats: UInt64, price: Double?) -> String {
        guard let price else { return "$--" }
        let btc = Double(sats) / 100_000_000
        let fiatValue = btc * price
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: fiatValue)) ?? String(format: "$%.2f", fiatValue)
    }

    // MARK: - Actions

    private func handleTap() {
        if isHidden {
            onTap?()
            return
        }

        withAnimation(DesignTokens.Animation.bouncy) {
            // Cycle through display units
            switch displayUnit {
            case .sats:
                displayUnit = btcPrice != nil ? .fiat : .btc
            case .fiat:
                displayUnit = .btc
            case .btc:
                displayUnit = .sats
            }
        }

        onTap?()
    }
}

// MARK: - Compact Amount Display

/// A smaller inline amount display for lists and compact views
struct CompactAmountDisplay: View {
    let sats: UInt64
    let type: TransactionCard.TransactionDisplayType?
    let showUnit: Bool

    init(
        sats: UInt64,
        type: TransactionCard.TransactionDisplayType? = nil,
        showUnit: Bool = true
    ) {
        self.sats = sats
        self.type = type
        self.showUnit = showUnit
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            if let type {
                Text(type.prefix)
                    .foregroundStyle(type.color)
            }

            Text(formattedAmount)
                .foregroundStyle(type?.color ?? Color.ds.textPrimary)

            if showUnit {
                Text("sats")
                    .foregroundStyle(Color.ds.textSecondary)
            }
        }
        .font(DesignTokens.Typography.amountRow)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: sats)) ?? "\(sats)"
    }
}

// MARK: - Amount Input Display

/// Display for amount input screens with large typography
struct AmountInputDisplay: View {
    let amount: UInt64
    let btcPrice: Double?
    let placeholder: String

    init(
        amount: UInt64,
        btcPrice: Double? = nil,
        placeholder: String = "0"
    ) {
        self.amount = amount
        self.btcPrice = btcPrice
        self.placeholder = placeholder
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            // Main amount
            Text(amount > 0 ? formattedAmount : placeholder)
                .font(DesignTokens.Typography.amountLarge)
                .foregroundStyle(amount > 0 ? Color.ds.textPrimary : Color.ds.textTertiary)
                .contentTransition(.numericText())
                .animation(DesignTokens.Animation.snappy, value: amount)

            // Unit
            Text("sats")
                .font(DesignTokens.Typography.headline)
                .foregroundStyle(Color.ds.textSecondary)

            // Fiat conversion
            if let btcPrice, amount > 0 {
                Text("≈ \(fiatAmount(price: btcPrice))")
                    .font(DesignTokens.Typography.title3)
                    .foregroundStyle(Color.ds.textTertiary)
                    .contentTransition(.numericText())
            }
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private func fiatAmount(price: Double) -> String {
        let btc = Double(amount) / 100_000_000
        let fiatValue = btc * price
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: fiatValue)) ?? String(format: "$%.2f", fiatValue)
    }
}

// MARK: - Previews

#Preview("Amount Display Sizes") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        AmountDisplay(sats: 1_234_567, btcPrice: 45000, size: .large)

        AmountDisplay(sats: 1_234_567, btcPrice: 45000, size: .medium)

        AmountDisplay(sats: 1_234_567, btcPrice: 45000, size: .small)
    }
    .padding()
}

#Preview("Amount Display States") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        AmountDisplay(sats: 1_234_567, btcPrice: 45000)

        AmountDisplay(sats: 1_234_567, btcPrice: 45000, isHidden: true)

        AmountDisplay(sats: 0, isLoading: true)
    }
    .padding()
}

#Preview("Compact Amount") {
    VStack(spacing: DesignTokens.Spacing.md) {
        CompactAmountDisplay(sats: 21_000, type: .incoming)
        CompactAmountDisplay(sats: 5_000, type: .outgoing)
        CompactAmountDisplay(sats: 100_000)
    }
    .padding()
}

#Preview("Amount Input") {
    VStack(spacing: DesignTokens.Spacing.xl) {
        AmountInputDisplay(amount: 0, btcPrice: 45000)
        AmountInputDisplay(amount: 21_000, btcPrice: 45000)
    }
    .padding()
}
