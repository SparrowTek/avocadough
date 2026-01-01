//
//  Transaction.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 2/21/25.
//

@preconcurrency import SwiftData
import CoreNostr
import SwiftUI

enum AvocadoughTransactionType: String, Codable {
    case incoming
    case outgoing

    init(transactionType: NWCTransactionType) {
        self = switch transactionType {
        case .incoming: .incoming
        case .outgoing: .outgoing
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .incoming: "received"
        case .outgoing: "sent"
        }
    }

    var arrow: String {
        switch self {
        case .incoming: "arrowshape.down.circle"
        case .outgoing: "arrowshape.up.circle"
        }
    }

    var color: Color {
        switch self {
        case .incoming: .green
        case .outgoing: .red
        }
    }

    var plusOrMinus: String {
        switch self {
        case .incoming: "+"
        case .outgoing: "-"
        }
    }
}

typealias Transaction = AvocadoughSchema.Transaction

extension AvocadoughSchema {
    @Model
    class Transaction {
        var transactionType: AvocadoughTransactionType?
        var invoice: String?
        var transactionDescription: String?
        var descriptionHash: String?
        var preimage: String?
        @Attribute(.unique) var paymentHash: String
        /// Amount in millisatoshis
        var amount: UInt64
        /// Fees paid in millisatoshis
        var feesPaid: UInt64
        var createdAt: UInt64?
        var expiresAt: UInt64?
        var settledAt: UInt64?

        init(
            transactionType: AvocadoughTransactionType? = nil,
            invoice: String? = nil,
            transactionDescription: String? = nil,
            descriptionHash: String? = nil,
            preimage: String? = nil,
            paymentHash: String,
            amount: UInt64,
            feesPaid: UInt64,
            createdAt: UInt64? = nil,
            expiresAt: UInt64? = nil,
            settledAt: UInt64? = nil
        ) {
            self.transactionType = transactionType
            self.invoice = invoice
            self.transactionDescription = transactionDescription
            self.descriptionHash = descriptionHash
            self.preimage = preimage
            self.paymentHash = paymentHash
            self.amount = amount
            self.feesPaid = feesPaid
            self.createdAt = createdAt
            self.expiresAt = expiresAt
            self.settledAt = settledAt
        }

        /// Initialize from NostrKit's NWCTransaction
        init(nwcTransaction: NWCTransaction) {
            self.transactionType = AvocadoughTransactionType(transactionType: nwcTransaction.type)
            self.invoice = nwcTransaction.invoice
            self.transactionDescription = nwcTransaction.description
            self.descriptionHash = nwcTransaction.descriptionHash
            self.preimage = nwcTransaction.preimage
            self.paymentHash = nwcTransaction.paymentHash

            // Convert Int64 amounts to UInt64 (NostrKit uses signed integers)
            self.amount = UInt64(max(0, nwcTransaction.amount))
            self.feesPaid = UInt64(max(0, nwcTransaction.feesPaid ?? 0))

            // Convert TimeInterval (seconds since epoch as Double) to UInt64
            self.createdAt = UInt64(nwcTransaction.createdAt)
            self.expiresAt = nwcTransaction.expiresAt.map { UInt64($0) }
            self.settledAt = nwcTransaction.settledAt.map { UInt64($0) }
        }
    }
}
