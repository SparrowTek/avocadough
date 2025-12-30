//
//  SyncTransactionData.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 4/4/24.
//

import SwiftUI
import CoreNostr

fileprivate struct SyncTransactionData: ViewModifier {
    @Environment(WalletState.self) private var state
    @Environment(\.modelContext) private var context
    @Environment(\.nwc) private var nwc
    @State private var transactionSyncTrigger = PlainTaskTrigger()
    @Binding var requestInProgress: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: state.triggerTransactionSync, triggerTransactionSync)
            .task { await getTransactionData() }
            .task($transactionSyncTrigger) { await getTransactionData() }
    }

    private func triggerTransactionSync() {
        guard state.triggerTransactionSync else { return }
        state.triggerTransactionSync = false
        transactionSyncTrigger.trigger()
    }

    private func getTransactionData() async {
        defer { requestInProgress = false }
        requestInProgress = true

        do {
            let transactions = try await nwc.listTransactions(
                from: nil,
                until: nil,
                limit: state.transactionDataLimit,
                offset: state.transactionDataOffset,
                unpaid: nil,
                transactionType: nil
            )
            try saveTransactions(transactions)
        } catch {
            return // intentionally not handling errors
        }
    }

    private func saveTransactions(_ nwcTransactions: [NWCTransaction]) throws {
        for nwcTransaction in nwcTransactions {
            let transaction = Transaction(nwcTransaction: nwcTransaction)
            context.insert(transaction)
        }

        try context.save()
    }
}

extension View {
    func syncTransactionData(requestInProgress: Binding<Bool>) -> some View {
        modifier(SyncTransactionData(requestInProgress: requestInProgress))
    }
}

#Preview {
    Text("Sync Transaction Data")
        .syncTransactionData(requestInProgress: .constant(true))
        .environment(AppState())
        .environment(WalletState(parentState: .init()))
}
