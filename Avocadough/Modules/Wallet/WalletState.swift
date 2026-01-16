//
//  WalletState.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/30/23.
//

import Foundation
import SwiftUI

@Observable
@MainActor
class WalletState {
    enum Sheet: Identifiable {
        case send
        case receive
        case open(Transaction)

        var id: Int {
            switch self {
            case .send: 1
            case .receive: 2
            case .open: 3
            }
        }
    }
    
    var sheet: Sheet?
    var triggerTransactionSync = false
    var highlightTopTransaction = false
    var transactionDataLimit: UInt64 = 20
    var transactionDataOffset: UInt64 = 0
    var errorMessage: LocalizedStringKey?
    var btcPrice: BTCPrice?
    
    private unowned let parentState: AppState
    
    @ObservationIgnored
    lazy var sendState = SendState(parentState: self)
    @ObservationIgnored
    lazy var receiveState = ReceiveState(parentState: self)
    
    
    init(parentState: AppState) {
        self.parentState = parentState
    }
    
    func isCanvasSetBTCPrice() {
        btcPrice = BTCPrice(amount: "85000", lastUpdatedAtInUtcEpochSeconds: "", currency: "USD", version: "1", base: "BTC")
    }
    
    func closeSheet() {
        sheet = nil
    }
    
    func paymentSent() {
        triggerTransactionSync = true
        triggerDataSync()
        highlightTopTransaction = true
    }
    
    func disconnectNWC() {
        sheet = nil
        parentState.logout()
    }
    
    func getMoreTransactions() {
        transactionDataOffset += transactionDataLimit
        triggerTransactionSync = true
    }
    
    func refresh() {
        transactionDataOffset = 0
        triggerDataSync()
        triggerTransactionSync = true
    }
    
    func routeToSupport() {
        sheet = .send
        sendState.routeToSupport()
    }
}

extension WalletState: ReachabilityDelegate {
    func triggerDataSync() {
        parentState.triggerDataSync = true
    }
}
