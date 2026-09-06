//
//  Bolt11Invoice.swift
//  Avocadough
//

import Foundation
import LightningDevKit

extension Bolt11Invoice {
    /// The invoice amount in whole satoshis, or `nil` for an amountless invoice.
    var amountSats: UInt64? {
        amountMilliSatoshis().map { $0 / 1000 }
    }

    /// A short, recognisable label for the payee: the leading and trailing characters of
    /// the node ID recovered from the invoice signature, e.g. `03a1b2c3…d4e5f6a7`.
    var payeeLabel: String {
        let nodeID = recoverPayeePubKey().map { String(format: "%02x", $0) }.joined()
        guard nodeID.count > 16 else { return nodeID }
        return "\(nodeID.prefix(8))…\(nodeID.suffix(8))"
    }
}
