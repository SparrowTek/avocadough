//
//  WalletManager.swift
//  Avocadough
//

import SwiftUI

/// Manages multiple wallet providers and provides a unified interface for wallet operations
@Observable
@MainActor
final class WalletManager {
    // MARK: - Properties

    /// All registered wallet providers
    private(set) var providers: [WalletType: any WalletProvider] = [:]

    /// Currently active wallet type
    private(set) var activeWalletType: WalletType?

    /// Whether any wallet is connected
    var hasConnectedWallet: Bool {
        providers.values.contains { $0.isConnected }
    }

    /// The currently active wallet provider
    var activeProvider: (any WalletProvider)? {
        guard let type = activeWalletType else { return nil }
        return providers[type]
    }

    /// All connected wallets
    var connectedWallets: [WalletConnectionInfo] {
        providers.values.compactMap { $0.connectionInfo }
    }

    /// Total balance across all connected wallets (in millisatoshis)
    private(set) var aggregatedBalance: UInt64 = 0

    // MARK: - Initialization

    init() {
        // Register default providers
        registerProvider(NWCWalletProvider())
    }

    // MARK: - Provider Management

    /// Register a wallet provider
    func registerProvider(_ provider: any WalletProvider) {
        providers[provider.walletType] = provider
    }

    /// Get a specific provider
    func provider(for type: WalletType) -> (any WalletProvider)? {
        providers[type]
    }

    /// Set the active wallet
    func setActiveWallet(_ type: WalletType) {
        guard providers[type]?.isConnected == true else { return }
        activeWalletType = type
    }

    // MARK: - Connection

    /// Connect a wallet using a connection string
    /// - Parameters:
    ///   - type: The wallet type
    ///   - connectionString: The connection string (NWC URI, Cashu mint URL, etc.)
    func connect(type: WalletType, connectionString: String) async throws {
        guard let provider = providers[type] else {
            throw WalletProviderError.unsupportedOperation
        }

        try await provider.connect(connectionString: connectionString)

        // Set as active if it's the first connected wallet
        if activeWalletType == nil {
            activeWalletType = type
        }
    }

    /// Disconnect a specific wallet
    func disconnect(type: WalletType) {
        providers[type]?.disconnect()

        // Switch active wallet if needed
        if activeWalletType == type {
            activeWalletType = connectedWallets.first?.type
        }
    }

    /// Disconnect all wallets
    func disconnectAll() {
        providers.values.forEach { $0.disconnect() }
        activeWalletType = nil
    }

    // MARK: - Balance Operations

    /// Get balance for active wallet
    func getBalance() async throws -> WalletBalance {
        guard let provider = activeProvider else {
            throw WalletProviderError.notConnected
        }
        return try await provider.getBalance()
    }

    /// Refresh aggregated balance across all wallets
    func refreshAggregatedBalance() async {
        var total: UInt64 = 0

        for provider in providers.values where provider.isConnected {
            if let balance = try? await provider.getBalance() {
                total += balance.millisatoshis
            }
        }

        aggregatedBalance = total
    }

    // MARK: - Payment Operations

    /// Pay an invoice using the active wallet
    func payInvoice(_ invoice: String) async throws -> PaymentResult {
        guard let provider = activeProvider else {
            throw WalletProviderError.notConnected
        }
        return try await provider.payInvoice(invoice)
    }

    /// Create an invoice using the active wallet
    func createInvoice(amount: UInt64, description: String?, expiry: UInt64?) async throws -> InvoiceResponse {
        guard let provider = activeProvider else {
            throw WalletProviderError.notConnected
        }
        return try await provider.createInvoice(amount: amount, description: description, expiry: expiry)
    }

    // MARK: - Transaction Operations

    /// List transactions for the active wallet
    func listTransactions(limit: Int?, offset: Int?) async throws -> [WalletTransaction] {
        guard let provider = activeProvider else {
            throw WalletProviderError.notConnected
        }
        return try await provider.listTransactions(limit: limit, offset: offset)
    }
}

// MARK: - Environment Integration

@MainActor
private struct WalletManagerKey: @preconcurrency EnvironmentKey {
    static let defaultValue = WalletManager()
}

extension EnvironmentValues {
    var walletManager: WalletManager {
        get { self[WalletManagerKey.self] }
        set { self[WalletManagerKey.self] = newValue }
    }
}
