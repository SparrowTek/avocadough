//
//  WalletPresenter.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/29/23.
//

import SwiftUI
import SwiftData

struct WalletPresenter: View {
    @Environment(WalletState.self) private var state
    
    var body: some View {
        @Bindable var state = state
        
        NavigationStack {
            WalletView()
                .sheet(item: $state.sheet) {
                    switch $0 {
                    case .send:
                        SendPresenter()
                            .environment(state.sendState)
                            .interactiveDismissDisabled()
                    case .receive:
                        ReceivePresenter()
                            .environment(state.receiveState)
                            .interactiveDismissDisabled()
                    case .open(let transaction):
                        TransactionDetailsView(transaction: transaction)
                            .presentationDragIndicator(.visible)
                            .presentationDetents([.medium])
                    case .settings:
                        SettingsPresenter()
                            .environment(state.settingsState)
                            .presentationDragIndicator(.visible)
                    case .moreActivity:
                        ActivityPresenter()
                            .environment(state.activityState)
                            .presentationDragIndicator(.visible)
                    }
                }
                .alert($state.errorMessage)
        }
    }
}

// MARK: - WalletTabContent

private struct WalletView: View {
    @Environment(\.reachability) private var reachability
    @Environment(WalletState.self) private var state
    @State private var requestInProgress = false
    @Query private var wallets: [Wallet]
    
    private var wallet: Wallet? {
        wallets.first
    }
    
    private var redacted: Bool {
        guard let wallet else { return true }
        return !wallet.methods.contains(where: { $0 == .getBalance })
    }
    
    private var redactDollarText: Bool {
        wallet == nil && state.btcPrice == nil
    }
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            // Network status banner
            if reachability.connectionState != .good {
                NetworkStatusBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Balance Card
            BalanceCard {
                AmountDisplay(
                    sats: wallet?.balance.millisatsToSats ?? 0,
                    btcPrice: state.btcPrice?.priceAsDouble,
                    isHidden: false,
                    isLoading: redacted && wallet == nil,
                    size: .large
                ) {
                    if redacted {
                        tappedBalance()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            // Quick Actions
            HStack(spacing: DesignTokens.Spacing.md) {
                AvocadoButton("Send", icon: "arrow.up.right", variant: .primary, size: .large) {
                    sendSats()
                }
                
                AvocadoButton("Receive", icon: "arrow.down.left", variant: .secondary, size: .large) {
                    receiveSats()
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            // Recent Activity Section
            RecentActivitySection()
        }
        .padding(.top, DesignTokens.Spacing.md)
        .fullScreenColorView()
        .navigationTitle("Avocadough")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("", systemImage: "slider.horizontal.3", action: openSettings)
            }
        }
        .refreshable { await refresh() }
        .syncTransactionData(requestInProgress: $requestInProgress)
        .task { await reachability.startMonitoring() }
        .onAppear(perform: setBTCPrice)
    }
    
    private func setBTCPrice() {
        if isCanvas {
            state.isCanvasSetBTCPrice()
        }
    }
    
    private func tappedBalance() {
        guard redacted else { return }
        state.errorMessage = "The current NWC wallet connection does not have permission to see your balance"
    }
    
    private func sendSats() {
        if let wallet, wallet.methods.contains(where: { $0 == .payInvoice }) {
            state.sheet = .send
        } else {
            state.errorMessage = "The current NWC wallet connection does not have permission to send sats"
        }
    }
    
    private func receiveSats() {
        if let wallet, wallet.methods.contains(where: { $0 == .makeInvoice }) {
            state.sheet = .receive
        } else {
            state.errorMessage = "The current NWC wallet connection does not have permission to make an invoice"
        }
    }
    
    private func openSettings() {
        state.sheet = .settings
    }
    
    private func refresh() async {
        state.refresh()
    }
}

// MARK: - Network Status Banner

private struct NetworkStatusBanner: View {
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "network.slash")
            Text("Poor network connection")
                .font(DesignTokens.Typography.subheadline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.Semantic.error)
    }
}

// MARK: - Recent Activity Section

private struct RecentActivitySection: View {
    @Environment(WalletState.self) private var state
    @Query(sort: \Transaction.createdAt, order: .reverse) private var transactions: [Transaction]
    @State private var hasAppeared = false
    
    private var recentTransactions: [Transaction] {
        Array(transactions.prefix(5))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Recent Activity")
                    .font(DesignTokens.Typography.headline)
                    .foregroundStyle(Color.ds.textPrimary)
                
                Spacer()
                
                Button("See more", action: seeMoreActivity)
                    .foregroundStyle(.accentPrimary)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            
            if recentTransactions.isEmpty {
                EmptyStateView(
                    icon: "bolt.slash.fill",
                    title: "No Transactions Yet",
                    message: "Your recent transactions will appear here"
                )
                .padding(.horizontal, DesignTokens.Spacing.md)
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(Array(recentTransactions.enumerated()), id: \.element.id) { index, transaction in
                        RecentTransactionRow(transaction: transaction)
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                DesignTokens.Animation.smooth.delay(Double(index) * 0.05),
                                value: hasAppeared
                            )
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
            }
        }
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
            }
        }
    }
    
    private func seeMoreActivity() {
        state.sheet = .moreActivity
    }
}

// MARK: - Recent Transaction Row

private struct RecentTransactionRow: View {
    @Environment(WalletState.self) private var state
    let transaction: Transaction
    @State private var tapTrigger = false
    
    private var displayType: TransactionCard.TransactionDisplayType {
        transaction.transactionType == .incoming ? .incoming : .outgoing
    }
    
    private var transactionDisplayText: LocalizedStringKey {
        if let description = transaction.transactionDescription, !description.isEmpty {
            return LocalizedStringKey(description)
        }
        return transaction.transactionType?.title ?? "Transaction"
    }
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            // Icon
            Image(systemName: displayType.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(displayType.color)
                .frame(width: 36, height: 36)
                .background(displayType.color.opacity(0.15))
                .clipShape(Circle())
            
            // Details
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("\(displayType.prefix)\(transaction.amount.millisatsToSats.currency)")
                    .font(DesignTokens.Typography.amountRow)
                    .foregroundStyle(displayType.color)
                
                Text(transactionDisplayText)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(Color.ds.textSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Timestamp
            Text(transaction.createdAt?.invoiceFormat ?? "")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(Color.ds.textTertiary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            state.sheet = .open(transaction)
        }
        .avocadogeCard(style: .standard, padding: DesignTokens.Spacing.md)
        .sensoryFeedback(AppHaptics.buttonTap, trigger: tapTrigger)
    }
}

#Preview(traits: .sampleComposite) {
    @Previewable @State var state = AppState()
    
    WalletPresenter()
        .environment(state)
        .environment(state.walletState)
        .environment(\.reachability, Reachability())
}
