//
//  ActivityState.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 1/19/26.
//

import SwiftUI

@MainActor
@Observable
class ActivityState {
    unowned var parentState: WalletState
    var path: [Transaction] = []
    
    init(parentState: WalletState) {
        self.parentState = parentState
    }
    
    func refresh() {
        parentState.refresh()
    }
    
    func getMoreTransactions() {
        parentState.getMoreTransactions()
    }
    
    func openTransaction(_ transaction: Transaction) {
        path.append(transaction)
    }
}
