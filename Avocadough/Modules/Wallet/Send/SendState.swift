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

    /// Why an input can't start a payment: what the user is told, and how the
    /// diagnostics log names it.
    private enum InputRejection: Error {
        case nothingPayable
        case unreadableInvoice
        case expiredInvoice
        case amountlessInvoice
        case onChainOnly

        var message: LocalizedStringKey {
            switch self {
            case .nothingPayable: "Enter an invoice, Lightning address, or LNURL."
            case .unreadableInvoice: "That Lightning invoice couldn't be read. Ask for a new one and try again."
            case .expiredInvoice: "That Lightning invoice has expired. Ask for a new one and try again."
            case .amountlessInvoice: "Invoices without an amount aren't supported yet."
            case .onChainOnly: "On-chain bitcoin addresses aren't supported. Ask for a Lightning invoice instead."
            }
        }

        var diagnosticName: String {
            switch self {
            case .nothingPayable: "nothing payable"
            case .unreadableInvoice: "unreadable invoice"
            case .expiredInvoice: "expired invoice"
            case .amountlessInvoice: "invoice without an amount"
            case .onChainOnly: "on-chain only"
            }
        }
    }
    
    private unowned let parentState: WalletState
    let diagnostics: DiagnosticsLog
    var path: [SendState.NavigationLink] = []
    var errorMessage: LocalizedStringKey?
    var btcPrice: Double? {
        parentState.btcPrice?.priceAsDouble
    }
    
    @ObservationIgnored
    lazy var scanQRCodeState = ScanQRCodeState(parentState: self)
    
    init(parentState: WalletState, diagnostics: DiagnosticsLog = .shared) {
        self.parentState = parentState
        self.diagnostics = diagnostics
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
    /// the root view is visible. Every decision along the way is recorded in the
    /// diagnostics log.
    func continueWithInput(_ lightningInput: String, replaceCurrentPath: Bool = false) {
        diagnostics.record(.send, replaceCurrentPath ? "Received a scanned code" : "Received input", detail: lightningInput)

        switch destination(for: lightningInput) {
        case .success(let destination):
            if replaceCurrentPath, !path.isEmpty {
                path[path.index(before: path.endIndex)] = destination
                diagnostics.record(.send, "Replaced the top screen with \(destination.diagnosticName)")
            } else {
                path.append(destination)
                diagnostics.record(.send, "Pushed \(destination.diagnosticName)")
            }
        case .failure(let rejection):
            errorMessage = rejection.message
            diagnostics.record(.send, "Rejected input: \(rejection.diagnosticName)")
            if replaceCurrentPath {
                path.removeAll { $0 == .scanQR }
                diagnostics.record(.send, "Popped the scanner so the error alert can show")
            }
        }
    }

    private func destination(for lightningInput: String) -> Result<NavigationLink, InputRejection> {
        guard let input = LightningInput(lightningInput) else {
            return .failure(.nothingPayable)
        }

        switch input {
        case .bolt11(let invoice):
            guard let decoded = DecodedInvoice(invoice) else {
                diagnostics.record(.send, "Looks like a BOLT11 invoice, but LDK couldn't parse it", detail: invoice)
                return .failure(.unreadableInvoice)
            }
            diagnostics.record(.send, "Decoded a BOLT11 invoice", detail: decoded.diagnosticDescription)
            guard !decoded.isExpired else {
                return .failure(.expiredInvoice)
            }
            guard let amount = decoded.amountSats, amount > 0 else {
                return .failure(.amountlessInvoice)
            }
            return .success(.sendInvoice(decoded))
        case .recipient(let recipient):
            diagnostics.record(.send, "Treating the input as a recipient to look up over LNURL-pay", detail: recipient)
            return .success(.getLightningAddressDetails(recipient))
        case .onChainOnly(let address):
            diagnostics.record(.send, "The input only carries an on-chain address", detail: address)
            return .failure(.onChainOnly)
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

// MARK: - Diagnostics descriptions

private extension SendState.NavigationLink {
    var diagnosticName: String {
        switch self {
        case .sendInvoice: "the invoice review screen"
        case .getLightningAddressDetails: "the lightning address screen"
        case .reviewPayment: "the payment review screen"
        case .paymentSuccess: "the payment success screen"
        case .scanQR: "the QR scanner"
        }
    }
}

private extension DecodedInvoice {
    var diagnosticDescription: String {
        let amount = amountSats.map { "\($0) sats" } ?? "no amount"
        let expiry = isExpired ? "expired" : "not expired"
        return "\(amount) · \(expiry) · payee \(payeeLabel) · payment hash \(paymentHash)"
    }
}
