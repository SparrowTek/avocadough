//
//  NWC.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/27/24.
//

import SwiftUI
import NostrKit
import CoreNostr
import Vault

enum NWCError: Error {
    case noSecret
    case failedToSaveSecret
    case notConnected
    case failedToParse
    case nostrKit(Error)
}

/// Custom response type to maintain API compatibility with existing code.
/// NostrKit's makeInvoice returns only the invoice string, but callers expect
/// both invoice and paymentHash.
struct MakeInvoiceResponse: Sendable, Hashable {
    let invoice: String
    let paymentHash: String
}

@Observable
@MainActor
class NWC {
    private let walletManager = WalletConnectManager()
    private var storedUri: String?
    var hasConnected = false
    
    func logout() {
        hasConnected = false
        storedUri = nil
    }

    /// Parse NWC URI and save secret to keychain
    /// - Parameter code: The nostr+walletconnect:// URI string
    /// - Returns: NWCConnection with pubKey, relay, and optional lud16
    func parseWalletCode(_ code: String) throws(NWCError) -> NWCConnection {
        guard let uri = NWCConnectionURI(from: code) else {
            throw .failedToParse
        }

        // Save the secret to keychain
        try saveSecret(uri.secret)

        // Store the full URI for later connection
        storedUri = code

        // Return first relay (NWC typically uses single relay)
        let relay = uri.relays.first ?? ""

        return NWCConnection(
            pubKey: uri.walletPubkey,
            relay: relay,
            lud16: uri.lud16
        )
    }

    /// Initialize and connect the NWC client
    /// - Parameters:
    ///   - pubKey: The wallet's public key (hex string)
    ///   - relay: The relay URL
    ///   - lud16: Optional lightning address
    func initializeNWCClient(pubKey: String, relay: String, lud16: String?) async throws(NWCError) {
        // Prevent multiple connections
        guard !hasConnected else { return }
        guard let secret else { throw .noSecret }

        // Reconstruct URI from components if we don't have it stored
        let uri = storedUri ?? buildUri(pubKey: pubKey, relay: relay, secret: secret, lud16: lud16)

        do {
            try await walletManager.connect(uri: uri)
            hasConnected = true
        } catch {
            throw .nostrKit(error)
        }
    }

    /// Get wallet information
    /// - Returns: WalletInfo containing alias, network, methods, etc.
    func getInfo() async throws(NWCError) -> WalletConnectManager.WalletInfo {
        do {
            return try await walletManager.getInfo()
        } catch {
            throw .nostrKit(error)
        }
    }

    /// Get wallet balance in millisatoshis
    /// - Returns: Balance as UInt64 (converted from NostrKit's Int64)
    func getBalance() async throws(NWCError) -> UInt64 {
        do {
            let balance = try await walletManager.getBalance()
            return UInt64(max(0, balance))
        } catch {
            throw .nostrKit(error)
        }
    }

    /// Pay a BOLT11 invoice
    /// - Parameter invoice: The BOLT11 invoice string
    /// - Returns: PaymentResult with preimage and fees
    @discardableResult
    func payInvoice(_ invoice: String) async throws(NWCError) -> WalletConnectManager.PaymentResult {
        do {
            return try await walletManager.payInvoice(invoice)
        } catch {
            throw .nostrKit(error)
        }
    }

    /// Create a new invoice
    /// - Parameters:
    ///   - amount: Amount in millisatoshis
    ///   - description: Optional invoice description
    ///   - descriptionHash: Optional description hash (not supported by NostrKit - ignored)
    ///   - expiry: Optional expiry in seconds
    /// - Returns: MakeInvoiceResponse with invoice and payment hash
    func makeInvoice(
        amount: UInt64,
        description: String?,
        descriptionHash: String?,
        expiry: UInt64?
    ) async throws(NWCError) -> MakeInvoiceResponse {
        do {
            let invoice = try await walletManager.makeInvoice(
                amount: Int64(amount),
                description: description,
                expiry: expiry.map { Int($0) }
            )

            // Look up the invoice to get the payment hash
            let lookupResult = try await walletManager.lookupInvoice(invoice: invoice)

            return MakeInvoiceResponse(
                invoice: invoice,
                paymentHash: lookupResult.paymentHash
            )
        } catch {
            throw .nostrKit(error)
        }
    }

    /// List transactions
    /// - Parameters:
    ///   - from: Start date
    ///   - until: End date
    ///   - limit: Maximum number of transactions
    ///   - offset: Pagination offset (not supported by NostrKit - ignored)
    ///   - unpaid: Filter by unpaid status (not supported by NostrKit - ignored)
    ///   - transactionType: Filter by type (not supported by NostrKit - ignored)
    /// - Returns: Array of NWCTransaction
    func listTransactions(
        from: Date?,
        until: Date?,
        limit: UInt64?,
        offset: UInt64?,
        unpaid: Bool?,
        transactionType: NWCTransactionType?
    ) async throws(NWCError) -> [NWCTransaction] {
        do {
            return try await walletManager.listTransactions(
                from: from,
                until: until,
                limit: limit.map { Int($0) }
            )
        } catch {
            throw .nostrKit(error)
        }
    }

    // MARK: - Secret Management

    private var secret: String? {
        try? Vault.getPrivateKey(keychainConfiguration: .nwcSecret)
    }

    private func saveSecret(_ secret: String) throws(NWCError) {
        do {
            try Vault.savePrivateKey(secret, keychainConfiguration: .nwcSecret)
        } catch {
            throw .failedToSaveSecret
        }
    }

    // MARK: - Helpers

    private func buildUri(pubKey: String, relay: String, secret: String, lud16: String?) -> String {
        var components = URLComponents()
        components.scheme = "nostr+walletconnect"
        components.host = pubKey

        var queryItems = [
            URLQueryItem(name: "relay", value: relay),
            URLQueryItem(name: "secret", value: secret)
        ]

        if let lud16 {
            queryItems.append(URLQueryItem(name: "lud16", value: lud16))
        }

        components.queryItems = queryItems
        return components.string ?? "nostr+walletconnect://\(pubKey)?relay=\(relay)&secret=\(secret)"
    }
}

// MARK: - Environment Integration

@MainActor
private struct NWCKey: @preconcurrency EnvironmentKey {
    static let defaultValue = NWC()
}

extension EnvironmentValues {
    var nwc: NWC {
        get { self[NWCKey.self] }
        set { self[NWCKey.self] = newValue }
    }
}
