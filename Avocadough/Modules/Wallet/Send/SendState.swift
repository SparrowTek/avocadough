//
//  SendState.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 1/14/24.
//

import Foundation
import SwiftUI

@Observable
@MainActor
class SendState {
    enum NavigationLink: Hashable {
        case sendInvoice(DecodedInvoice)
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

    /// Starts a fresh send flow at the destination for `input`. Used when another app or
    /// an NFC tag hands us a `lightning:` / `bitcoin:` URI.
    func start(with input: String) {
        path = []
        continueWithInput(input)
    }
    
    /// Pushes the destination for `lightningInput`, or surfaces an error and leaves the
    /// path alone when the input isn't payable.
    ///
    /// With `replaceCurrentPath` the destination swaps in for the screen on top of the
    /// stack (the QR scanner). On an error that screen is popped instead so the alert on
    /// the root view is visible.
    func continueWithInput(_ lightningInput: String, replaceCurrentPath: Bool = false) {
        guard let destination = destination(for: lightningInput) else {
            if replaceCurrentPath {
                path.removeAll { $0 == .scanQR }
            }
            return
        }

        if replaceCurrentPath, !path.isEmpty {
            path[path.index(before: path.endIndex)] = destination
        } else {
            path.append(destination)
        }
    }

    private func destination(for lightningInput: String) -> NavigationLink? {
        guard let input = LightningInput(lightningInput) else {
            errorMessage = "Enter an invoice, Lightning address, or LNURL."
            return nil
        }

        switch input {
        case .bolt11(let invoice):
            guard let decoded = DecodedInvoice(invoice) else {
                errorMessage = "That Lightning invoice couldn't be read. Ask for a new one and try again."
                return nil
            }
            guard !decoded.isExpired else {
                errorMessage = "That Lightning invoice has expired. Ask for a new one and try again."
                return nil
            }
            guard let amount = decoded.amountSats, amount > 0 else {
                errorMessage = "Invoices without an amount aren't supported yet."
                return nil
            }
            return .sendInvoice(decoded)
        case .recipient(let recipient):
            return .getLightningAddressDetails(recipient)
        case .onChainOnly:
            errorMessage = "On-chain bitcoin addresses aren't supported. Ask for a Lightning invoice instead."
            return nil
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
