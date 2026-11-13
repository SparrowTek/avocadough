//
//  LightningInput.swift
//  Avocadough
//

import Foundation

/// Free-form payment input — typed, pasted, scanned, or handed over by a URL — reduced to
/// the bare payload the send flow understands.
///
/// Terminals and wallets wrap invoices in several ways: a `lightning:` URI scheme (often
/// upper-cased so the QR code can use its compact alphanumeric mode), a BIP 21 `bitcoin:`
/// URI carrying the invoice in its `lightning` query item, or stray whitespace from the
/// clipboard. LDK's BOLT11 parser accepts none of those, so they are peeled off here
/// before anything else looks at the string.
enum LightningInput: Equatable, Sendable {
    /// A BOLT11 invoice, lower-cased. Only the prefix has been checked — hand it to LDK
    /// for real validation.
    case bolt11(String)
    /// A Lightning address, LNURL, or anything else the invoice-lookup flow resolves.
    case recipient(String)
    /// A BIP 21 URI that carries only an on-chain address, which this wallet cannot pay.
    case onChainOnly(String)

    /// Classifies `raw`, or returns `nil` when nothing payable is left after unwrapping.
    init?(_ raw: String) {
        var payload = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let uri = BitcoinURI(payload) {
            guard let lightning = uri.lightning else {
                guard !uri.address.isEmpty else { return nil }
                self = .onChainOnly(uri.address)
                return
            }
            payload = lightning
        }

        if let unwrapped = Self.stripping(scheme: "lightning", from: payload) {
            payload = unwrapped
        }

        payload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { return nil }

        let lowercased = payload.lowercased()
        let isInvoice = Self.bolt11Prefixes.contains(where: lowercased.hasPrefix) && !lowercased.contains("@")
        self = isInvoice ? .bolt11(lowercased) : .recipient(payload)
    }

    /// BOLT11 human-readable-part prefixes: mainnet (`lnbc`), testnet (`lntb`),
    /// signet (`lntbs`), and regtest (`lnbcrt`). The last two share the first two's prefixes.
    private static let bolt11Prefixes = ["lnbc", "lntb"]

    /// Drops a case-insensitive `scheme:` (or `scheme://`) prefix, or returns `nil` when
    /// `text` doesn't start with it.
    fileprivate static func stripping(scheme: String, from text: String) -> String? {
        let prefix = scheme + ":"
        guard text.count >= prefix.count, text.prefix(prefix.count).lowercased() == prefix else {
            return nil
        }

        var remainder = text.dropFirst(prefix.count)
        if remainder.hasPrefix("//") {
            remainder = remainder.dropFirst(2)
        }
        return String(remainder)
    }
}

// MARK: - BIP 21

/// The parts of a BIP 21 `bitcoin:` URI this app cares about.
private struct BitcoinURI {
    /// The on-chain address, possibly empty for a Lightning-only URI (`bitcoin:?lightning=…`).
    let address: String
    /// The value of the `lightning` query item, percent-decoded, when present.
    let lightning: String?

    init?(_ text: String) {
        guard let remainder = LightningInput.stripping(scheme: "bitcoin", from: text) else { return nil }

        let parts = remainder.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        address = parts.first.map(String.init) ?? ""

        let query = parts.count > 1 ? parts[1] : ""
        lightning = query
            .split(separator: "&")
            .lazy
            .compactMap { item -> String? in
                let pair = item.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                guard pair.count == 2, pair[0].lowercased() == "lightning" else { return nil }
                let value = String(pair[1])
                return value.removingPercentEncoding ?? value
            }
            .first(where: { !$0.isEmpty })
    }
}
