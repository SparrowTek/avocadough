//
//  CreateInvoiceView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 2/23/24.
//

import SwiftUI

struct CreateInvoiceView: View {
    @Environment(ReceiveState.self) private var state
    @Environment(\.nwc) private var nwc
    @State private var amount: UInt64 = 0
    @State private var isLoading = false
    @State private var createInvoiceTrigger = PlainTaskTrigger()

    private var btcPrice: Double? {
        state.btcPrice
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Enter amount to request")
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(Color.ds.textSecondary)
                .padding(.top, DesignTokens.Spacing.md)

            // Amount entry
            AmountEntryView(
                amount: $amount,
                maxAmount: nil,
                btcPrice: btcPrice,
                buttonTitle: "Create Invoice",
                isLoading: isLoading
            ) {
                triggerCreateInvoice()
            }
        }
        .fullScreenColorView()
        .navigationTitle("Request Payment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: doneTapped)
            }
        }
        .task($createInvoiceTrigger) { await createInvoice() }
    }

    private func doneTapped() {
        state.doneTapped()
    }

    private func triggerCreateInvoice() {
        createInvoiceTrigger.trigger()
    }

    private func createInvoice() async {
        guard amount > 0 else {
            state.errorMessage = "Please enter an amount"
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let invoice = try? await nwc.makeInvoice(amount: amount, description: nil, descriptionHash: nil, expiry: nil) else {
            state.errorMessage = "Failed to create invoice. Please try again."
            return
        }
        state.path.append(.displayInvoice(invoice))
    }
}

#Preview {
    @Previewable @State var present = true
    @Previewable @State var appState = AppState()

    Text("wallet")
        .sheet(isPresented: $present) {
            NavigationStack {
                CreateInvoiceView()
                    .environment(appState.walletState.receiveState)
                    .environment(\.nwc, NWC())
            }
        }
}
