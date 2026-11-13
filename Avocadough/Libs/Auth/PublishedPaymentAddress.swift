//
//  PublishedPaymentAddress.swift
//  Avocadough
//

import Foundation

/// What is known about the Lightning address published at the signed-in handle, the
/// address anyone resolving `@handle` is told to pay.
enum PublishedPaymentAddress: Equatable, Sendable {
    /// Not looked up yet.
    case unknown
    case loading
    /// The handle resolves to this Lightning address.
    case published(String)
    /// The account has no payment endpoint record, or the record carries no Lightning
    /// address.
    case notPublished
    /// The record could not be read, so nothing is known either way.
    case unavailable

    /// Something the user can do about the published address.
    enum Action: Hashable, Sendable {
        /// Publish the wallet's address where none is published.
        case publish(String)
        /// Replace a published address that is not the wallet's.
        case update(to: String)
        case unpublish
        /// Look the record up again.
        case retry
    }

    /// The actions on offer, given the Lightning address of the connected wallet and
    /// whether the session is allowed to write the record at all.
    ///
    /// A published address can always be taken down by a session that may write. It can
    /// only be put up or replaced when the wallet has an address of its own to offer.
    func actions(walletAddress: String?, canPublish: Bool) -> [Action] {
        switch self {
        case .unknown, .loading:
            []
        case .unavailable:
            [.retry]
        case .notPublished:
            if canPublish, let walletAddress { [.publish(walletAddress)] } else { [] }
        case .published(let current):
            if !canPublish {
                []
            } else if let walletAddress, !Self.isSameAddress(current, walletAddress) {
                [.update(to: walletAddress), .unpublish]
            } else {
                [.unpublish]
            }
        }
    }

    /// Whether the handle points at the connected wallet.
    func matches(walletAddress: String?) -> Bool {
        guard case .published(let current) = self, let walletAddress else { return false }
        return Self.isSameAddress(current, walletAddress)
    }

    /// Lightning addresses are compared without regard to case: LUD-16 restricts the
    /// user part to lower case and host names are case-insensitive.
    private static func isSameAddress(_ lhs: String, _ rhs: String) -> Bool {
        lhs.caseInsensitiveCompare(rhs) == .orderedSame
    }
}

/// The handle or DID a person typed to sign in with, cleaned up for identity resolution.
enum SignInIdentifier {

    /// Trims white space, drops a leading `@`, and lower-cases handles, which are
    /// case-insensitive. A DID is left as typed, since its identifier can be
    /// case-sensitive. Returns `nil` when nothing is left.
    static func normalized(_ input: String) -> String? {
        var identifier = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if identifier.hasPrefix("@") {
            identifier = identifier.dropFirst().trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !identifier.isEmpty else { return nil }

        return identifier.hasPrefix("did:") ? identifier : identifier.lowercased()
    }
}
