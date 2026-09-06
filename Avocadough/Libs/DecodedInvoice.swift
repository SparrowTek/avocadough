//
//  DecodedInvoice.swift
//  Avocadough
//

import Foundation
import LightningDevKit

/// The parts of a BOLT11 invoice the send flow needs, decoded once with LDK so the rest
/// of the app passes plain values around instead of LDK handles.
struct DecodedInvoice: Hashable, Sendable {
    /// The invoice as LDK re-serializes it: lower case and ready for `pay_invoice`.
    let bolt11: String
    /// The amount in whole satoshis, or `nil` for an amountless invoice.
    let amountSats: UInt64?
    /// The payment hash as lower-case hex, the key wallets use to look a payment up.
    let paymentHash: String
    /// A short label for the payee: the leading and trailing characters of the node ID
    /// recovered from the invoice signature, e.g. `03a1b2c3…d4e5f6a7`.
    let payeeLabel: String
    /// Whether the invoice's expiry has already passed.
    let isExpired: Bool

    /// Parses `invoice`, or returns `nil` when LDK rejects it.
    init?(_ invoice: String) {
        guard let parsed = Bolt11Invoice.fromStr(s: invoice).getValue(),
              let hash = parsed.paymentHash() else { return nil }

        bolt11 = parsed.toStr()
        amountSats = parsed.amountMilliSatoshis().map { $0 / 1000 }
        paymentHash = Self.hex(hash)
        payeeLabel = Self.abbreviated(Self.hex(parsed.recoverPayeePubKey()))
        isExpired = parsed.isExpired()
    }

    private static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func abbreviated(_ nodeID: String) -> String {
        guard nodeID.count > 16 else { return nodeID }
        return "\(nodeID.prefix(8))…\(nodeID.suffix(8))"
    }
}
