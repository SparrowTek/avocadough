//
//  WalletConfig.swift
//  Avocadough
//

@preconcurrency import SwiftData
import Foundation

typealias WalletConfig = AvocadoughSchema.WalletConfig

extension AvocadoughSchema {
    /// Stores wallet configuration for multi-wallet support
    @Model
    class WalletConfig {
        /// Unique identifier for this wallet configuration
        @Attribute(.unique) var id: String

        /// The type of wallet (nwc, cashu)
        var walletTypeRaw: String

        /// Display name for this wallet
        var name: String

        /// Whether this is the currently active wallet
        var isActive: Bool

        /// Creation date
        var createdAt: Date

        /// Last used date
        var lastUsedAt: Date?

        /// Order for display (lower = first)
        var sortOrder: Int

        // NWC-specific fields
        var nwcPubKey: String?
        var nwcRelay: String?
        var nwcLightningAddress: String?

        // Cashu-specific fields (for future use)
        var cashuMintUrl: String?

        var walletType: WalletType {
            get { WalletType(rawValue: walletTypeRaw) ?? .nwc }
            set { walletTypeRaw = newValue.rawValue }
        }

        init(
            id: String = UUID().uuidString,
            walletType: WalletType,
            name: String,
            isActive: Bool = false,
            sortOrder: Int = 0
        ) {
            self.id = id
            self.walletTypeRaw = walletType.rawValue
            self.name = name
            self.isActive = isActive
            self.createdAt = Date()
            self.sortOrder = sortOrder
        }

        /// Create from NWC connection
        static func fromNWC(
            pubKey: String,
            relay: String,
            lightningAddress: String?,
            name: String = "Lightning Wallet"
        ) -> WalletConfig {
            let config = WalletConfig(walletType: .nwc, name: name)
            config.nwcPubKey = pubKey
            config.nwcRelay = relay
            config.nwcLightningAddress = lightningAddress
            return config
        }

        /// Create from Cashu mint (future use)
        static func fromCashu(
            mintUrl: String,
            name: String = "Cashu Wallet"
        ) -> WalletConfig {
            let config = WalletConfig(walletType: .cashu, name: name)
            config.cashuMintUrl = mintUrl
            return config
        }
    }
}
