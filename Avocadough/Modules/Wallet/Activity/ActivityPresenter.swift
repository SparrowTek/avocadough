//
//  ActivityPresenter.swift
//  Avocadough
//

import SwiftUI
import SwiftData

// MARK: - Transaction Filter

enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case received = "Received"
    case sent = "Sent"
}

struct ActivityPresenter: View {
    @Environment(ActivityState.self) private var state
    
    var body: some View {
        @Bindable var state = state
        
        NavigationStack(path: $state.path) {
            ActivityList()
                .navigationDestination(for: Transaction.self) {
                    TransactionDetailsView(transaction: $0)
                }
        }
    }
}

fileprivate struct ActivityList: View {
    @Environment(ActivityState.self) private var state
    @State private var selectedFilter: TransactionFilter = .all
    @State private var requestInProgress: Bool = false
    @State private var searchText = ""
    @Query(sort: \Transaction.createdAt, order: .reverse) private var allTransactions: [Transaction]

    private var filteredTransactions: [Transaction] {
        var result = allTransactions

        // Apply type filter
        switch selectedFilter {
        case .all:
            break
        case .received:
            result = result.filter { $0.transactionType == .incoming }
        case .sent:
            result = result.filter { $0.transactionType == .outgoing }
        }

        if !searchText.isEmpty {
            result = result.filter { transaction in
                let description = transaction.transactionDescription?.lowercased() ?? ""
                let amount = String(transaction.amount.millisatsToSats)
                return description.contains(searchText.lowercased()) || amount.contains(searchText)
            }
        }
        
        return result
    }

    private var groupedTransactions: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: filteredTransactions) { transaction -> String in
            guard let timestamp = transaction.createdAt else { return "Unknown" }
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            return date.sectionHeader
        }
        return grouped.sorted { first, second in
            guard let firstTimestamp = first.value.first?.createdAt,
                  let secondTimestamp = second.value.first?.createdAt else {
                return false
            }
            return firstTimestamp > secondTimestamp
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // Filter Pills
            FilterPillsView(selectedFilter: $selectedFilter)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.bottom, DesignTokens.Spacing.sm)

            // Transaction List
            if filteredTransactions.isEmpty && requestInProgress {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if filteredTransactions.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "bolt.slash.fill",
                    title: searchText.isEmpty ? "No Transactions" : "No Results",
                    message: searchText.isEmpty
                    ? "Your transaction history will appear here"
                    : "Try a different search term"
                )
                Spacer()
            } else {
                TransactionListView(
                    groupedTransactions: groupedTransactions,
                    requestInProgress: $requestInProgress,
                    searchText: $searchText
                )
            }
        }
        .padding(.top, 32)
        .fullScreenColorView()
        .navigationTitle("Activity")
        .refreshable { refresh() }
        .syncTransactionData(requestInProgress: $requestInProgress)
        .toolbarTitleDisplayMode(.inline)
    }

    private func refresh() {
        state.refresh()
    }
}

// MARK: - Filter Pills View

private struct FilterPillsView: View {
    @Binding var selectedFilter: TransactionFilter
    @State private var filterTrigger = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ForEach(TransactionFilter.allCases, id: \.self) { filter in
                FilterPill(
                    title: filter.rawValue,
                    isSelected: selectedFilter == filter
                ) {
                    filterTrigger.toggle()
                    withAnimation(DesignTokens.Animation.snappy) {
                        selectedFilter = filter
                    }
                }
            }
            Spacer()
        }
        .sensoryFeedback(.selection, trigger: filterTrigger)
    }
}

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignTokens.Typography.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : Color.ds.textSecondary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(isSelected ? DesignTokens.Colors.Accent.primary : DesignTokens.Colors.Component.fillSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Transaction List View

private struct TransactionListView: View {
    @Environment(ActivityState.self) private var state
    let groupedTransactions: [(String, [Transaction])]
    @Binding var requestInProgress: Bool
    @Binding var searchText: String
    @State private var hasAppeared = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.Spacing.md, pinnedViews: [.sectionHeaders]) {
                ForEach(Array(groupedTransactions.enumerated()), id: \.element.0) { sectionIndex, sectionData in
                    let (section, transactions) = sectionData
                    Section {
                        ForEach(Array(transactions.enumerated()), id: \.element.id) { rowIndex, transaction in
                            let globalIndex = sectionIndex * 10 + rowIndex
                            ActivityTransactionRow(transaction: transaction)
                                .onAppear {
                                    checkIfAtBottomAndFetchMore(transaction)
                                }
                                .opacity(hasAppeared ? 1 : 0)
                                .offset(y: hasAppeared ? 0 : 15)
                                .animation(
                                    DesignTokens.Animation.smooth.delay(Double(min(globalIndex, 10)) * 0.03),
                                    value: hasAppeared
                                )
                        }
                    } header: {
                        SectionHeader(title: section)
                    }
                }

                if requestInProgress {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
        }
        .searchable(text: $searchText)
        .onAppear {
            if !hasAppeared {
                hasAppeared = true
            }
        }
    }

    private func checkIfAtBottomAndFetchMore(_ transaction: Transaction) {
        guard let lastSection = groupedTransactions.last,
              lastSection.1.last == transaction else { return }
        state.getMoreTransactions()
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(DesignTokens.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.ds.textSecondary)
            Spacer()
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(DesignTokens.Colors.Background.primary)
    }
}

// MARK: - Activity Transaction Row

private struct ActivityTransactionRow: View {
    @Environment(ActivityState.self) private var state
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

    private var formattedTime: String {
        guard let timestamp = transaction.createdAt else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return date.timeFormat
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
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                Text(formattedTime)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color.ds.textTertiary)
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.ds.textTertiary)
        }
        .avocadogeCard(style: .standard, padding: DesignTokens.Spacing.md)
        .contentShape(Rectangle())
        .onTapGesture { state.openTransaction(transaction) }
        .sensoryFeedback(AppHaptics.buttonTap, trigger: tapTrigger)
    }
}

// MARK: - Date Extensions

private extension Date {
    var sectionHeader: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "Today"
        } else if calendar.isDateInYesterday(self) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: self)
        }
    }

    var timeFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}

// MARK: - Preview

#Preview(traits: .sampleTransactions) {
    @Previewable @State var state = AppState()
    @Previewable @State var isPresented = true
    
    Text("")
        .sheet(isPresented: $isPresented) {
            ActivityPresenter()
                .environment(state)
                .environment(state.walletState.activityState)
                .presentationDragIndicator(.visible)
        }
}
