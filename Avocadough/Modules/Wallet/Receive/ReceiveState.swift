//
//  ReceiveState.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 2/11/24.
//

import Foundation
import SwiftUI

@Observable
@MainActor
class ReceiveState {
    enum NavigationLink: Hashable {
        case createInvoice
        case displayInvoice(MakeInvoiceResponse)
        case paymentReceived(amount: UInt64)
    }

    private unowned let parentState: WalletState

    var path: [ReceiveState.NavigationLink] = []
    var errorMessage: LocalizedStringKey?
    
    var btcPrice: Double? {
        parentState.btcPrice?.priceAsDouble
    }
    
    init(parentState: WalletState) {
        self.parentState = parentState
    }

    func doneTapped() {
        parentState.closeSheet()
        path = []
    }

    func showPaymentReceived(amount: UInt64) {
        path = [.paymentReceived(amount: amount)]
        refreshTransactions()
    }

    func refreshTransactions() {
        parentState.refresh()
    }
}
