//
//  DisplayInvoiceView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 2/28/24.
//

import SwiftUI
import SwiftData
import LightningDevKit

struct DisplayInvoiceView: View {
    var invoice: MakeInvoiceResponse
    @State private var invoiceCopied = false
    @State private var checkInvoiceTrigger = PlainTaskTrigger()
    @Environment(ReceiveState.self) private var state
    @State private var requestInProgress = false
    @State private var bolt11: Bolt11Invoice?
    @Query private var transactions: [Transaction]

    private var thisTransaction: Transaction? {
        for transaction in transactions {
            if transaction.invoice == invoice.invoice {
                return transaction
            }
        }

        return nil
    }

    private var isSettled: Bool {
        guard let thisTransaction else { return false }
        return thisTransaction.settledAt != nil
    }

    private var sats: LocalizedStringKey {
        let sats = bolt11?.amountMilliSatoshis() ?? 0
        return if sats == 1 {
            "1 SAT"
        } else {
            "\(sats) SATS"
        }
    }

    var body: some View {
        VStack {
            QRCodeImage(code: invoice.invoice)
            Text(sats)
                .bold()
                .padding()

            Text(isSettled ? "paid" : "waiting for payment...")
            Button(action: triggerCheckInvoiceStatus) {
                ZStack {
                    Text("check status")
                        .opacity(requestInProgress ? 0 : 1)
                    ProgressView()
                        .opacity(requestInProgress ? 1 : 0)
                }
            }
                .buttonStyle(.bordered)
                .disabled(isSettled)
                .opacity(isSettled ? 0 : 1)

            ZStack {
                Button(action: copyInvoice) {
                    HStack {
                        Text("copy invoice")
                        Image(systemName: "doc.on.doc")
                    }
                }
                .buttonStyle(.avocadough)
                .opacity(invoiceCopied ? 0 : 1)

                Text("copied!")
                    .foregroundStyle(Color.green)
                    .opacity(invoiceCopied ? 1 : 0)
            }
            .padding(.vertical)
        }
        .padding()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: doneTapped)
            }
        }
        .task($checkInvoiceTrigger) { await checkInvoiceStatus() }
        .onAppear(perform: setupBolt11)
        .syncTransactionData(requestInProgress: $requestInProgress)
    }

    private func setupBolt11() {
        bolt11 = Bolt11Invoice.fromStr(s: invoice.invoice).getValue()
    }

    private func doneTapped() {
        state.doneTapped()
    }

    private func triggerCheckInvoiceStatus() {
        checkInvoiceTrigger.trigger()
    }

    private func checkInvoiceStatus() async {
        state.refreshTransactions()
    }

    private func copyInvoice() {
        UIPasteboard.general.string = bolt11?.toStr()
        invoiceCopied = true

        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            invoiceCopied = false
        }
    }
}

#Preview(traits: .sampleTransactions) {
    DisplayInvoiceView(invoice: MakeInvoiceResponse(invoice: "mkewr34rt8ug", paymentHash: "fmjnds"))
        .environment(ReceiveState(parentState: .init(parentState: .init())))
        .environment(WalletState(parentState: .init()))
}
