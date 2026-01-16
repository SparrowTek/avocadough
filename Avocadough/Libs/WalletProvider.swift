//
//  WalletProvider.swift
//  Avocadough
//

import Foundation

// MARK: - Wallet Type

/// Supported wallet protocol types
enum WalletType: String, Codable, CaseIterable, Sendable {
    case nwc = "nwc"
    case cashu = "cashu"

    var displayName: String {
        switch self {
        case .nwc: return "Lightning (NWC)"
        case .cashu: return "Cashu"
        }
    }

    var icon: String {
        switch self {
        case .nwc: return "bolt.fill"
        case .cashu: return "leaf.fill"
        }
    }

    var description: String {
        switch self {
        case .nwc:
            return "Connect to your Lightning wallet via Nostr Wallet Connect"
        case .cashu:
            return "Privacy-focused ecash tokens with instant payments"
        }
    }
}

// MARK: - Wallet Provider Error

/// Unified error type for wallet operations
enum WalletProviderError: Error, LocalizedError {
    case notConnected
    case connectionFailed(String)
    case invalidCredentials
    case insufficientBalance
    case paymentFailed(String)
    case invoiceCreationFailed(String)
    case transactionFetchFailed(String)
    case unsupportedOperation
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Wallet is not connected"
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        case .invalidCredentials:
            return "Invalid wallet credentials"
        case .insufficientBalance:
            return "Insufficient balance for this payment"
        case .paymentFailed(let reason):
            return "Payment failed: \(reason)"
        case .invoiceCreationFailed(let reason):
            return "Failed to create invoice: \(reason)"
        case .transactionFetchFailed(let reason):
            return "Failed to fetch transactions: \(reason)"
        case .unsupportedOperation:
            return "This operation is not supported by this wallet type"
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - Wallet Connection Info

/// Unified wallet connection information
struct WalletConnectionInfo: Sendable {
    let id: String
    let type: WalletType
    let name: String
    let lightningAddress: String?
    let isConnected: Bool

    init(id: String, type: WalletType, name: String, lightningAddress: String? = nil, isConnected: Bool = false) {
        self.id = id
        self.type = type
        self.name = name
        self.lightningAddress = lightningAddress
        self.isConnected = isConnected
    }
}

// MARK: - Wallet Balance

/// Unified balance representation
struct WalletBalance: Sendable {
    /// Balance in millisatoshis
    let millisatoshis: UInt64

    /// Balance in satoshis
    var satoshis: UInt64 {
        millisatoshis / 1000
    }

    init(millisatoshis: UInt64) {
        self.millisatoshis = millisatoshis
    }

    init(satoshis: UInt64) {
        self.millisatoshis = satoshis * 1000
    }
}

// MARK: - Invoice Response

/// Unified invoice response
struct InvoiceResponse: Sendable {
    let invoice: String
    let paymentHash: String
    let amount: UInt64?
    let description: String?
    let expiresAt: Date?
}

// MARK: - Payment Result

/// Unified payment result
struct PaymentResult: Sendable {
    let preimage: String
    let feesPaid: UInt64
}

// MARK: - Transaction Info

/// Unified transaction representation for the provider layer
struct WalletTransaction: Sendable, Identifiable {
    enum TransactionType: String, Sendable {
        case incoming
        case outgoing
    }

    let id: String
    let type: TransactionType
    let amount: UInt64
    let feesPaid: UInt64
    let description: String?
    let invoice: String?
    let preimage: String?
    let paymentHash: String
    let createdAt: Date?
    let settledAt: Date?
}

// MARK: - Wallet Provider Protocol

/// Protocol defining the interface for wallet providers
/// Implement this protocol to add support for new wallet types (NWC, Cashu, etc.)
@MainActor
protocol WalletProvider: AnyObject, Sendable {
    /// The type of wallet this provider handles
    var walletType: WalletType { get }

    /// Whether the wallet is currently connected
    var isConnected: Bool { get }

    /// Connection info for this wallet
    var connectionInfo: WalletConnectionInfo? { get }

    /// Connect to the wallet
    /// - Parameter connectionString: The connection string (NWC URI, Cashu mint URL, etc.)
    func connect(connectionString: String) async throws

    /// Disconnect from the wallet
    func disconnect()

    /// Get the current balance
    /// - Returns: The wallet balance in millisatoshis
    func getBalance() async throws -> WalletBalance

    /// Pay a Lightning invoice
    /// - Parameter invoice: The BOLT11 invoice string
    /// - Returns: Payment result with preimage
    func payInvoice(_ invoice: String) async throws -> PaymentResult

    /// Create a new invoice
    /// - Parameters:
    ///   - amount: Amount in millisatoshis
    ///   - description: Optional description
    ///   - expiry: Optional expiry in seconds
    /// - Returns: Invoice response with invoice string and payment hash
    func createInvoice(amount: UInt64, description: String?, expiry: UInt64?) async throws -> InvoiceResponse

    /// List transactions
    /// - Parameters:
    ///   - limit: Maximum number of transactions to return
    ///   - offset: Pagination offset
    /// - Returns: Array of transactions
    func listTransactions(limit: Int?, offset: Int?) async throws -> [WalletTransaction]
}

// MARK: - Optional Cashu Operations

/// Extended protocol for Cashu-specific operations
@MainActor
protocol CashuWalletProvider: WalletProvider {
    /// Get available mints
    func getMints() async throws -> [CashuMint]

    /// Add a new mint
    func addMint(url: String) async throws -> CashuMint

    /// Remove a mint
    func removeMint(url: String) async throws

    /// Create a Cashu token for sending
    func createToken(amount: UInt64, mintUrl: String?) async throws -> String

    /// Redeem a Cashu token
    func redeemToken(_ token: String) async throws -> UInt64
}

/// Cashu mint information
struct CashuMint: Sendable, Identifiable {
    let id: String
    let url: String
    let name: String?
    let balance: UInt64
    let isTrusted: Bool
}
