//
//  WalletPairingTests.swift
//  AvocadoughTests
//

import Foundation
import Security
import Testing
import Vault
@testable import Avocadough

/// A pairing code can only be issued by the wallet, so the app must never drop one
/// because of a failure that could clear up by itself.
@Suite("Wallet pairing")
struct WalletPairingTests {
    @Test("A keychain without the secret means there is no pairing")
    func missingSecret() {
        let failure = NWCError(readingSecret: VaultError.itemNotFound)

        guard case .noSecret = failure else {
            Issue.record("Expected .noSecret, got \(failure)")
            return
        }
        #expect(failure.invalidatesPairing)
    }

    @Test(
        "A keychain that can't be read says nothing about the pairing",
        arguments: [errSecInteractionNotAllowed, errSecAuthFailed, errSecNotAvailable]
    )
    func unreadableKeychain(status: OSStatus) {
        let failure = NWCError(readingSecret: VaultError.keychainFailure(status: status))

        guard case .secretUnavailable = failure else {
            Issue.record("Expected .secretUnavailable, got \(failure)")
            return
        }
        #expect(!failure.invalidatesPairing)
    }

    @Test("An unexpected error reading the secret keeps the pairing")
    func unexpectedReadError() {
        #expect(!NWCError(readingSecret: VaultError.unexpectedData).invalidatesPairing)
        #expect(!NWCError(readingSecret: CancellationError()).invalidatesPairing)
    }

    @Test("An unreachable relay keeps the pairing")
    func unreachableRelay() {
        let failure = NWCError.nostrKit(URLError(.notConnectedToInternet))

        #expect(!failure.invalidatesPairing)
    }

    @Test("Only a missing secret is a reason to drop the pairing")
    func onlyMissingSecretInvalidates() {
        #expect(NWCError.noSecret.invalidatesPairing)
        #expect(!NWCError.secretUnavailable.invalidatesPairing)
        #expect(!NWCError.failedToSaveSecret.invalidatesPairing)
        #expect(!NWCError.notConnected.invalidatesPairing)
        #expect(!NWCError.failedToParse.invalidatesPairing)
    }
}
