//
//  WalletSwitcher.swift
//  Avocadough
//

import SwiftUI

// MARK: - Wallet Switcher (Segmented Control)

/// A segmented control for switching between wallet types
struct WalletSwitcher: View {
    @Binding var selectedType: WalletType
    let availableTypes: [WalletType]
    @State private var switchTrigger = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            ForEach(availableTypes, id: \.self) { type in
                WalletTypeButton(
                    type: type,
                    isSelected: selectedType == type
                ) {
                    guard selectedType != type else { return }
                    switchTrigger.toggle()
                    withAnimation(DesignTokens.Animation.snappy) {
                        selectedType = type
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.Component.fillSecondary)
        .clipShape(Capsule())
        .sensoryFeedback(.selection, trigger: switchTrigger)
    }
}

// MARK: - Wallet Type Button

private struct WalletTypeButton: View {
    let type: WalletType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(type == .nwc ? "Lightning" : "Cashu")
                    .font(DesignTokens.Typography.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .foregroundStyle(isSelected ? .white : Color.ds.textSecondary)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isSelected ? DesignTokens.Colors.Accent.primary : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Wallet Card

/// A card displaying wallet information with optional selection
struct WalletCard: View {
    let config: WalletConfig
    let balance: UInt64?
    let isSelected: Bool
    let onTap: () -> Void
    @State private var tapTrigger = false

    var body: some View {
        Button(action: {
            tapTrigger.toggle()
            onTap()
        }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                // Wallet icon
                Image(systemName: config.walletType.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : DesignTokens.Colors.Accent.primary)
                    .frame(width: 44, height: 44)
                    .background(
                        isSelected
                            ? DesignTokens.Colors.Accent.primary
                            : DesignTokens.Colors.Accent.primary.opacity(0.15)
                    )
                    .clipShape(Circle())

                // Wallet info
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(config.name)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(Color.ds.textPrimary)

                    if let address = config.nwcLightningAddress {
                        Text(address)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(Color.ds.textTertiary)
                    } else {
                        Text(config.walletType.displayName)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(Color.ds.textTertiary)
                    }
                }

                Spacer()

                // Balance or chevron
                if let balance {
                    VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                        Text("\(balance.currency)")
                            .font(DesignTokens.Typography.headline)
                            .foregroundStyle(Color.ds.textPrimary)
                        Text("sats")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(Color.ds.textTertiary)
                    }
                }

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(DesignTokens.Colors.Accent.success)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(isSelected ? DesignTokens.Colors.Accent.primary.opacity(0.08) : DesignTokens.Colors.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(
                        isSelected ? DesignTokens.Colors.Accent.primary : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(AppHaptics.selection, trigger: tapTrigger)
    }
}

// MARK: - Wallet Type Picker

/// A card-based picker for selecting wallet type during setup
struct WalletTypePicker: View {
    @Binding var selectedType: WalletType?
    @State private var selectionTrigger = false

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            ForEach(WalletType.allCases, id: \.self) { type in
                WalletTypePickerCard(
                    type: type,
                    isSelected: selectedType == type,
                    isComingSoon: type == .cashu
                ) {
                    guard type != .cashu else { return }
                    selectionTrigger.toggle()
                    withAnimation(DesignTokens.Animation.snappy) {
                        selectedType = type
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectionTrigger)
    }
}

// MARK: - Wallet Type Picker Card

private struct WalletTypePickerCard: View {
    let type: WalletType
    let isSelected: Bool
    let isComingSoon: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    // Icon
                    Image(systemName: type.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isComingSoon ? Color.ds.textTertiary : DesignTokens.Colors.Accent.primary)
                        .frame(width: 48, height: 48)
                        .background(
                            isComingSoon
                                ? Color.ds.textTertiary.opacity(0.15)
                                : DesignTokens.Colors.Accent.primary.opacity(0.15)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))

                    Spacer()

                    // Selection indicator or coming soon badge
                    if isComingSoon {
                        Text("Coming Soon")
                            .font(DesignTokens.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.ds.textTertiary)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(DesignTokens.Colors.Component.fillSecondary)
                            .clipShape(Capsule())
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(DesignTokens.Colors.Accent.primary)
                    } else {
                        Circle()
                            .stroke(DesignTokens.Colors.Component.border, lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }

                // Title and description
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(type.displayName)
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(isComingSoon ? Color.ds.textTertiary : Color.ds.textPrimary)

                    Text(type.description)
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(Color.ds.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(
                isSelected && !isComingSoon
                    ? DesignTokens.Colors.Accent.primary.opacity(0.08)
                    : DesignTokens.Colors.Background.secondary
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(
                        isSelected && !isComingSoon
                            ? DesignTokens.Colors.Accent.primary
                            : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isComingSoon)
        .opacity(isComingSoon ? 0.7 : 1)
    }
}

// MARK: - Add Wallet Button

/// A button for adding a new wallet
struct AddWalletButton: View {
    let action: () -> Void
    @State private var tapTrigger = false

    var body: some View {
        Button(action: {
            tapTrigger.toggle()
            action()
        }) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignTokens.Colors.Accent.primary)

                Text("Add Wallet")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(DesignTokens.Colors.Accent.primary)

                Spacer()
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.Accent.primary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .stroke(DesignTokens.Colors.Accent.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [8]))
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(AppHaptics.buttonTap, trigger: tapTrigger)
    }
}

// MARK: - Previews

#Preview("Wallet Switcher") {
    VStack(spacing: 20) {
        WalletSwitcher(
            selectedType: .constant(.nwc),
            availableTypes: [.nwc, .cashu]
        )

        WalletSwitcher(
            selectedType: .constant(.cashu),
            availableTypes: [.nwc, .cashu]
        )
    }
    .padding()
    .background(DesignTokens.Colors.Background.primary)
}

#Preview("Wallet Type Picker") {
    WalletTypePicker(selectedType: .constant(.nwc))
        .padding()
        .background(DesignTokens.Colors.Background.primary)
}

#Preview("Add Wallet Button") {
    AddWalletButton {}
        .padding()
        .background(DesignTokens.Colors.Background.primary)
}
