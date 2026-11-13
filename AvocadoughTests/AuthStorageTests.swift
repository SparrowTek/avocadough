//
//  AuthStorageTests.swift
//  AvocadoughTests
//

import CoreATProtocol
import Foundation
import Testing
import Vault
@testable import Avocadough

/// Runs against the real Keychain, under a service of its own per test.
@Suite("Auth storage")
struct AuthStorageTests {
    private let serviceName = "com.sparrowtek.avocadough.tests.\(UUID().uuidString)"
    private let installMarker = FileManager.default.temporaryDirectory
        .appending(path: "AuthStorageTests-\(UUID().uuidString)/installed")

    private let login = Login(
        accessToken: Token(value: "access", expiry: Date(timeIntervalSince1970: 2_000_000_000)),
        refreshToken: Token(value: "refresh"),
        scopes: "atproto",
        issuingServer: "https://bsky.social"
    )

    /// Hands `body` a storage of its own and removes everything it stored afterwards.
    private func withStorage(_ body: (AuthStorage) async throws -> Void) async throws {
        let storage = AuthStorage(serviceName: serviceName, installMarker: installMarker)

        let outcome: Result<Void, any Error>
        do {
            outcome = .success(try await body(storage))
        } catch {
            outcome = .failure(error)
        }

        try? await storage.clearAll()
        try? FileManager.default.removeItem(at: installMarker.deletingLastPathComponent())
        try outcome.get()
    }

    /// The Keychain item `AuthStorage` files `account` under. The layout is a contract
    /// with installed builds: renaming an account signs everyone out.
    private func configuration(for account: String) -> KeychainConfiguration {
        KeychainConfiguration(
            serviceName: serviceName,
            accessGroup: nil,
            accountName: "\(serviceName).\(account)",
            accessibility: .afterFirstUnlockThisDeviceOnly
        )
    }

    private func storeCompleteSession(in storage: AuthStorage) async throws {
        try await storage.storeLogin(login)
        try await storage.storePrivateKey(Data("pem".utf8))
        try await storage.storeSessionMetadata(did: "did:plc:alice", handle: "alice.test", pdsEndpoint: "https://pds.test")
    }

    // MARK: - Stored session

    @Test("An empty Keychain holds no session")
    func emptyKeychain() async throws {
        try await withStorage { storage in
            let state = try await storage.storedSession()
            #expect(state == .none)
        }
    }

    @Test("A stored session comes back whole")
    func completeSession() async throws {
        try await withStorage { storage in
            try await storeCompleteSession(in: storage)

            #expect(try await storage.storedSession() == .complete(StoredSession(
                did: "did:plc:alice",
                handle: "alice.test",
                pdsEndpoint: "https://pds.test",
                login: login,
                privateKeyPEM: "pem"
            )))
        }
    }

    @Test("Credentials without an account are no session")
    func credentialsWithoutAccount() async throws {
        try await withStorage { storage in
            try await storage.storeLogin(login)
            try await storage.storePrivateKey(Data("pem".utf8))

            #expect(try await storage.storedSession() == .none)
        }
    }

    @Test("An account whose tokens or key are gone is incomplete")
    func accountWithoutCredentials() async throws {
        try await withStorage { storage in
            try await storage.storeSessionMetadata(did: "did:plc:alice", handle: "alice.test", pdsEndpoint: "https://pds.test")
            #expect(try await storage.storedSession() == .incomplete)

            try await storage.storeLogin(login)
            #expect(try await storage.storedSession() == .incomplete)
        }
    }

    @Test("Tokens that cannot be decoded are an error, and nothing is wiped")
    func undecodableLogin() async throws {
        try await withStorage { storage in
            try await storeCompleteSession(in: storage)
            try await Vault.shared.save("not a login", configuration: configuration(for: "login"))

            await #expect(throws: DecodingError.self) {
                try await storage.storedSession()
            }
            #expect(try await Vault.shared.read(configuration: configuration(for: "did")) == "did:plc:alice")
            #expect(try await Vault.shared.read(configuration: configuration(for: "privateKey")) == "pem")
        }
    }

    @Test("A private key that is not text is refused")
    func unreadablePrivateKey() async throws {
        try await withStorage { storage in
            await #expect(throws: VaultError.encodingFailed) {
                try await storage.storePrivateKey(Data([0xFF, 0xFE, 0xFD]))
            }
            let stored = try await storage.retrievePrivateKey()
            #expect(stored == nil)
        }
    }

    // MARK: - Clearing

    @Test("Clearing the session removes every item of it")
    func clearAllRemovesTheSession() async throws {
        try await withStorage { storage in
            try await storeCompleteSession(in: storage)
            try await storage.storeAuthProxyKeyID("atproto-auth-1", for: login)

            try await storage.clearAll()

            #expect(try await storage.storedSession() == .none)
            #expect(try await storage.retrieveLogin() == nil)
            #expect(try await storage.retrievePrivateKey() == nil)
            #expect(try await storage.retrieveAuthProxyKeyID(for: login) == nil)
        }
    }

    @Test("Clearing the session leaves secrets under other services alone")
    func clearAllIsScopedToItsService() async throws {
        let walletSecret = KeychainConfiguration(
            serviceName: "\(serviceName).wallet",
            accessGroup: nil,
            accountName: "\(serviceName).wallet.nwcSecret"
        )
        try await Vault.shared.save("wallet secret", configuration: walletSecret)

        let outcome: Result<Void, any Error>
        do {
            try await withStorage { storage in
                try await storeCompleteSession(in: storage)
                try await storage.clearAll()

                #expect(try await Vault.shared.read(configuration: walletSecret) == "wallet secret")
            }
            outcome = .success(())
        } catch {
            outcome = .failure(error)
        }

        try await Vault.shared.delete(configuration: walletSecret)
        try outcome.get()
    }

    // MARK: - Auth proxy key ID

    @Test("The key ID comes back for the session it was stored with")
    func keyIDMatchesItsSession() async throws {
        try await withStorage { storage in
            try await storage.storeAuthProxyKeyID("atproto-auth-1", for: login)

            #expect(try await storage.retrieveAuthProxyKeyID(for: login) == "atproto-auth-1")
        }
    }

    @Test("A key ID left by another session is not handed out")
    func keyIDFromAnotherSessionIsWithheld() async throws {
        try await withStorage { storage in
            try await storage.storeAuthProxyKeyID("atproto-auth-1", for: login)

            let other = Login(
                accessToken: Token(value: "other access"),
                refreshToken: Token(value: "other refresh")
            )
            #expect(try await storage.retrieveAuthProxyKeyID(for: other) == nil)
        }
    }

    @Test("Without a refresh token the key ID is matched on the access token")
    func keyIDMatchesOnAccessToken() async throws {
        try await withStorage { storage in
            let accessOnly = Login(accessToken: Token(value: "access"))
            try await storage.storeAuthProxyKeyID("atproto-auth-1", for: accessOnly)

            #expect(try await storage.retrieveAuthProxyKeyID(for: accessOnly) == "atproto-auth-1")
            #expect(try await storage.retrieveAuthProxyKeyID(for: Login(accessToken: Token(value: "another"))) == nil)
        }
    }

    @Test("Clearing a key ID that was never stored is not an error")
    func clearingAnAbsentKeyID() async throws {
        try await withStorage { storage in
            try await storage.clearAuthProxyKeyID()
            #expect(try await storage.retrieveAuthProxyKeyID(for: login) == nil)
        }
    }

    // MARK: - Earlier installs

    @Test("The first launch of an install discards a session left in the Keychain")
    func firstLaunchDiscardsSession() async throws {
        try await withStorage { storage in
            try await storeCompleteSession(in: storage)

            #expect(try await storage.discardSessionFromEarlierInstall())
            #expect(try await storage.storedSession() == .none)
            #expect(try await storage.retrieveLogin() == nil)
        }
    }

    @Test("Later launches keep their session")
    func laterLaunchesKeepSession() async throws {
        try await withStorage { storage in
            #expect(try await storage.discardSessionFromEarlierInstall())

            try await storeCompleteSession(in: storage)

            #expect(try await !storage.discardSessionFromEarlierInstall())
            #expect(try await storage.storedSession() != .none)
        }
    }
}
