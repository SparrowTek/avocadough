//
//  SendState.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 1/14/24.
//

import Foundation
import SwiftUI
import LightningDevKit

@Observable
@MainActor
class SendState {
    enum NavigationLink: Hashable {
        case sendInvoice(Bolt11Invoice)
        case getLightningAddressDetails(String)
        case reviewPayment(recipient: String, amount: UInt64, invoicePR: String)
        case paymentSuccess(amount: UInt64, recipient: String)
        case scanQR
    }
    
    enum LightningAddressError: Error {
        case badLightningAddress
        case unsupported
    }
    
    enum LightningAddressType: Sendable {
        case bolt11Invoice(String)
        case bolt11LookupRequired(String)
    }
    
    private unowned let parentState: WalletState
    var path: [SendState.NavigationLink] = []
    var errorMessage: LocalizedStringKey?
    var btcPrice: Double? {
        parentState.btcPrice?.priceAsDouble
    }
    
    @ObservationIgnored
    lazy var scanQRCodeState = ScanQRCodeState(parentState: self)
    
    init(parentState: WalletState) {
        self.parentState = parentState
    }

    func navigateToReview(recipient: String, amount: UInt64, invoicePR: String) {
        path.append(.reviewPayment(recipient: recipient, amount: amount, invoicePR: invoicePR))
    }

    func showPaymentSuccess(amount: UInt64, recipient: String) {
        // Replace entire path with success screen
        path = [.paymentSuccess(amount: amount, recipient: recipient)]
        parentState.paymentSent()
    }

    func paymentSent() {
        parentState.paymentSent()
        clearPathAndCloseSheet()
    }
    
    func continueWithInput(_ lightningInput: String, replaceCurrentPath: Bool = false) {
        let navigationPath: NavigationLink = if let bolt11 = Bolt11Invoice.fromStr(s: lightningInput).getValue() {
            .sendInvoice(bolt11)
        } else {
            .getLightningAddressDetails(lightningInput)
        }
        
        if replaceCurrentPath {
            path[path.index(before: path.endIndex)] = navigationPath
        } else {
            path.append(navigationPath)
        }
    }
    
    private func clearPathAndCloseSheet() {
        path = []
        parentState.sheet = nil
    }
    
    func routeToSupport() {
        path.append(.getLightningAddressDetails("sparrowtek@getalby.com"))
    }
}

extension SendState: ScanQRCodeStateParent {
    func exitScanQRCode() {
        _ = path.popLast()
    }
    
    func postQRCodeScanComplete() {
        path.removeAll { $0 == .scanQR }
    }
    
    func foundQRCode(_ code: String) {
        continueWithInput(code, replaceCurrentPath: true)
    }
}
