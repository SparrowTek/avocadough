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
    }

    private unowned let parentState: WalletState

    var path: [ReceiveState.NavigationLink] = []
    var errorMessage: LocalizedStringKey?

    init(parentState: WalletState) {
        self.parentState = parentState
    }

    func doneTapped() {
        parentState.closeSheet()
        path = []
    }

    func refreshTransactions() {
        parentState.refresh()
    }
}
