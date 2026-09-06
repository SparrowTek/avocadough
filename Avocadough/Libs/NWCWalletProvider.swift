//
//  NWCWalletProvider.swift
//  Avocadough
//

import Foundation
import NostrKit
import CoreNostr
import Vault

/// NWC (Nostr Wallet Connect) implementation of WalletProvider
@Observable
@MainActor
final class NWCWalletProvider: WalletProvider {
    // MARK: - Properties

    let walletType: WalletType = .nwc

    private(set) var isConnected = false
    private(set) var connectionInfo: WalletConnectionInfo?

    private let walletManager = WalletConnectManager()
    private var storedUri: String?
    private var walletPubkey: String?
    private var lightningAddress: String?

    // MARK: - Connection

    func connect(connectionString: String) async throws {
        guard let uri = NWCConnectionURI(from: connectionString) else {
            throw WalletProviderError.invalidCredentials
        }

        // Save the secret to keychain
        do {
            try await Vault.shared.save(uri.secret, configuration: .nwcSecret)
        } catch {
            throw WalletProviderError.connectionFailed("Failed to save credentials")
        }

        storedUri = connectionString
        walletPubkey = uri.walletPubkey
        lightningAddress = uri.lud16

        do {
            try await walletManager.connect(uri: connectionString)
            isConnected = true

            // Update connection info
            connectionInfo = WalletConnectionInfo(
                id: uri.walletPubkey,
                type: .nwc,
                name: "Lightning Wallet",
                lightningAddress: uri.lud16,
                isConnected: true
            )
        } catch {
            throw WalletProviderError.connectionFailed(error.localizedDescription)
        }
    }

    /// Drops the live connection and the copies NostrKit keeps in its own keychain
    /// service, each of which carries the client secret.
    func disconnect() async {
        isConnected = false
        storedUri = nil
        connectionInfo = nil

        for connection in walletManager.connections {
            await walletManager.removeConnection(connection)
        }
        await walletManager.disconnect()
    }

    // MARK: - Balance

    func getBalance() async throws -> WalletBalance {
        guard isConnected else {
            throw WalletProviderError.notConnected
        }

        do {
            let balance = try await walletManager.getBalance()
            return WalletBalance(millisatoshis: UInt64(max(0, balance)))
        } catch {
            throw WalletProviderError.underlying(error)
        }
    }

    // MARK: - Payments

    func payInvoice(_ invoice: String) async throws -> PaymentResult {
        guard isConnected else {
            throw WalletProviderError.notConnected
        }

        do {
            let result = try await walletManager.payInvoice(invoice)
            return PaymentResult(
                preimage: result.preimage,
                feesPaid: UInt64(max(0, result.feesPaid ?? 0))
            )
        } catch {
            throw WalletProviderError.paymentFailed(error.localizedDescription)
        }
    }

    func createInvoice(amount: UInt64, description: String?, expiry: UInt64?) async throws -> InvoiceResponse {
        guard isConnected else {
            throw WalletProviderError.notConnected
        }

        do {
            let invoice = try await walletManager.makeInvoice(
                amount: Int64(amount),
                description: description,
                expiry: expiry.map { Int($0) }
            )

            // Look up the invoice to get the payment hash
            let lookupResult = try await walletManager.lookupInvoice(invoice: invoice)

            return InvoiceResponse(
                invoice: invoice,
                paymentHash: lookupResult.paymentHash,
                amount: amount,
                description: description,
                expiresAt: expiry.map { Date().addingTimeInterval(TimeInterval($0)) }
            )
        } catch {
            throw WalletProviderError.invoiceCreationFailed(error.localizedDescription)
        }
    }

    // MARK: - Transactions

    func listTransactions(limit: Int?, offset: Int?) async throws -> [WalletTransaction] {
        guard isConnected else {
            throw WalletProviderError.notConnected
        }

        do {
            let transactions = try await walletManager.listTransactions(
                from: nil,
                until: nil,
                limit: limit,
                offset: offset
            )

            return transactions.compactMap(mapTransaction)
        } catch {
            throw WalletProviderError.transactionFetchFailed(error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Maps an ``NWCTransaction`` into the provider-layer ``WalletTransaction``.
    /// Returns nil when the transaction can't be represented (missing payment hash or unknown type).
    private func mapTransaction(_ nwcTransaction: NWCTransaction) -> WalletTransaction? {
        guard let paymentHash = nwcTransaction.paymentHash else { return nil }

        let transactionType: WalletTransaction.TransactionType
        switch nwcTransaction.type {
        case .incoming: transactionType = .incoming
        case .outgoing: transactionType = .outgoing
        case .unknown: return nil
        }

        return WalletTransaction(
            id: paymentHash,
            type: transactionType,
            amount: UInt64(max(0, nwcTransaction.amount)),
            feesPaid: UInt64(max(0, nwcTransaction.feesPaid ?? 0)),
            description: nwcTransaction.description,
            invoice: nwcTransaction.invoice,
            preimage: nwcTransaction.preimage,
            paymentHash: paymentHash,
            createdAt: Date(timeIntervalSince1970: nwcTransaction.createdAt),
            settledAt: nwcTransaction.settledAt.map { Date(timeIntervalSince1970: $0) }
        )
    }

    // MARK: - Reconnection

    /// Reconnect using stored credentials
    func reconnect(pubKey: String, relay: String, lud16: String?) async throws {
        guard let secret = try? await Vault.shared.read(configuration: .nwcSecret) else {
            throw WalletProviderError.invalidCredentials
        }

        let uri = buildUri(pubKey: pubKey, relay: relay, secret: secret, lud16: lud16)
        try await connect(connectionString: uri)
    }

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
