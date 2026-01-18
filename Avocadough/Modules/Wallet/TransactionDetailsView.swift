//
//  TransactionDetailsView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 3/18/25.
//

import SwiftUI
import SwiftData

struct TransactionDetailsView: View {
    @Environment(WalletState.self) private var state
    var transaction: Transaction
    @State private var copyTrigger = false
    @State private var copiedField: String?

    private var displayType: TransactionCard.TransactionDisplayType {
        transaction.transactionType == .incoming ? .incoming : .outgoing
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        let amount = transaction.amount.millisatsToSats
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

    private var fiatAmount: String? {
        state.btcPrice?.amount.asDollars(for: transaction.amount.millisatsToSats)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image(systemName: displayType.icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(displayType.color)
                .frame(width: 64, height: 64)
                .background(displayType.color.opacity(0.15))
                .clipShape(Circle())
            VStack(spacing: DesignTokens.Spacing.lg) {
                // Header with icon and amount
                headerSection
                
                // Details card
                detailsCard
                
                Spacer()
            }
        }
        .padding(.top, 32)
        .padding(DesignTokens.Spacing.md)
        .fullScreenColorView()
        .sensoryFeedback(AppHaptics.copy, trigger: copyTrigger)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // Amount
            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("\(displayType.prefix)\(formattedAmount)")
                    .font(DesignTokens.Typography.amountLarge)
                    .foregroundStyle(displayType.color)
                
                Text("sats")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(Color.ds.textSecondary)
                
                if let fiat = fiatAmount {
                    Text("≈ \(fiat)")
                        .font(DesignTokens.Typography.title3)
                        .foregroundStyle(Color.ds.textTertiary)
                }
            }
            
            // Status badge
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: transaction.settledAt != nil ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 12))
            Text(transaction.settledAt != nil ? "Completed" : "Pending")
                .font(DesignTokens.Typography.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(transaction.settledAt != nil ? DesignTokens.Colors.Semantic.connected : DesignTokens.Colors.Accent.primary)
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            (transaction.settledAt != nil ? DesignTokens.Colors.Semantic.connected : DesignTokens.Colors.Accent.primary)
                .opacity(0.15)
        )
        .clipShape(Capsule())
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            // Date
            if let settledAt = transaction.settledAt {
                detailRow(
                    title: "Date",
                    value: formatDate(settledAt),
                    showDivider: true
                )
            }
            
            // Description
            if let description = transaction.transactionDescription, !description.isEmpty {
                detailRow(
                    title: "Description",
                    value: description,
                    showDivider: true
                )
            }
            
            // Fees
            if transaction.feesPaid > 0 {
                detailRow(
                    title: "Fees Paid",
                    value: "\(transaction.feesPaid.millisatsToSats) sats",
                    showDivider: true
                )
            }
            
            // Payment Hash (copyable)
            copyableDetailRow(
                title: "Payment Hash",
                value: transaction.paymentHash,
                fieldId: "hash",
                showDivider: transaction.preimage != nil
            )
            
            // Preimage (copyable)
            if let preimage = transaction.preimage {
                copyableDetailRow(
                    title: "Preimage",
                    value: preimage,
                    fieldId: "preimage",
                    showDivider: false
                )
            }
        }
        .padding(DesignTokens.Spacing.md)
        .avocadogeCard(style: .elevated)
    }

    private func detailRow(title: String, value: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(Color.ds.textSecondary)

                Spacer()

                Text(value)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(1)
            }
            .padding(.vertical, DesignTokens.Spacing.sm)

            if showDivider {
                Divider()
            }
        }
    }

    private func copyableDetailRow(title: String, value: String, fieldId: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(Color.ds.textSecondary)

                Spacer()

                Button(action: { copyValue(value, fieldId: fieldId) }) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(truncateMiddle(value, maxLength: 16))
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(Color.ds.textPrimary)

                        Image(systemName: copiedField == fieldId ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(copiedField == fieldId ? DesignTokens.Colors.Semantic.connected : Color.ds.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, DesignTokens.Spacing.sm)

            if showDivider {
                Divider()
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ timestamp: UInt64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func truncateMiddle(_ string: String, maxLength: Int) -> String {
        guard string.count > maxLength else { return string }
        let half = (maxLength - 3) / 2
        let start = string.prefix(half)
        let end = string.suffix(half)
        return "\(start)...\(end)"
    }

    private func copyValue(_ value: String, fieldId: String) {
        UIPasteboard.general.string = value
        copiedField = fieldId
        copyTrigger.toggle()

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copiedField = nil
        }
    }
}

// MARK: - Preview

#Preview(traits: .sampleTransactions) {
    @Previewable @State var state = AppState()

    TransactionDetailsView(
        transaction: Transaction(
            transactionType: .incoming,
            invoice: "lnbc...",
            transactionDescription: "Zap from @jack",
            preimage: "preimage123456789",
            paymentHash: "abc123def456789012345678901234567890",
            amount: 21000000,
            feesPaid: 10000,
            createdAt: 1705000000,
            settledAt: 1705000060
        )
    )
    .environment(state.walletState)
    .presentationDetents([.medium])
}
