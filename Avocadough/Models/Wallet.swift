//
//  Wallet.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 2/22/25.
//

@preconcurrency import SwiftData
import NostrKit
import CoreNostr

enum WalletMethod: String, Codable {
    case payInvoice = "pay_invoice"
    case payKeysend = "pay_keysend"
    case multiPayInvoice = "multi_pay_invoice"
    case multiPayKeysend = "multi_pay_keysend"
    case getInfo = "get_info"
    case getBalance = "get_balance"
    case makeInvoice = "make_invoice"
    case lookupInvoice = "lookup_invoice"
    case listTransactions = "list_transactions"
    case signMessage = "sign_message"
    case getBudget = "get_budget"

    /// Initialize from NostrKit's NWCMethod
    init?(nwcMethod: NWCMethod) {
        switch nwcMethod {
        case .payInvoice: self = .payInvoice
        case .payKeysend: self = .payKeysend
        case .multiPayInvoice: self = .multiPayInvoice
        case .multiPayKeysend: self = .multiPayKeysend
        case .getInfo: self = .getInfo
        case .getBalance: self = .getBalance
        case .makeInvoice: self = .makeInvoice
        case .lookupInvoice: self = .lookupInvoice
        case .listTransactions: self = .listTransactions
        }
    }
}

typealias Wallet = AvocadoughSchema.Wallet

extension AvocadoughSchema {
    @Model
    class Wallet {
        /// Current wallet balance in millisatoshis
        var balance: UInt64

        /// The alias of the lightning node
        var alias: String

        /// Most Recent Block Hash
        var blockHash: String

        /// Current block height
        var blockHeight: UInt32

        /// The color of the current node in hex code format
        var color: String

        /// Available methods for this connection
        var methods: [WalletMethod]

        /// Active network
        var network: String

        /// Lightning Node's public key
        @Attribute(.unique) var pubkey: String

        init(
            balance: UInt64,
            alias: String,
            blockHash: String,
            blockHeight: UInt32,
            color: String,
            methods: [WalletMethod],
            network: String,
            pubkey: String
        ) {
            self.balance = balance
            self.alias = alias
            self.blockHash = blockHash
            self.blockHeight = blockHeight
            self.color = color
            self.methods = methods
            self.network = network
            self.pubkey = pubkey
        }

        /// Initialize from NostrKit's WalletInfo
        init(info: WalletConnectManager.WalletInfo, balance: UInt64) {
            self.balance = balance
            self.alias = info.alias ?? "Unknown"
            self.blockHash = info.blockHash ?? ""
            self.blockHeight = UInt32(info.blockHeight ?? 0)
            self.color = info.color ?? "#000000"
            self.methods = info.methods.compactMap { WalletMethod(nwcMethod: $0) }
            self.network = info.network ?? "mainnet"
            self.pubkey = info.pubkey ?? ""
        }
    }
}
