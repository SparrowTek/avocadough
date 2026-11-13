//
//  AuthManagerTests.swift
//  AvocadoughTests
//

import CoreATProtocol
import CryptoKit
import Foundation
import Testing
@testable import Avocadough

/// The session's life on the device, none of which needs a network: restoring reads the
/// Keychain and nothing else, and the one refresh attempted here is of a token that is
/// still good, which is answered without asking an authorization server.
///
/// Restoring configures CoreATProtocol's process-wide session, so these run one at a time.
@MainActor
@Suite("Auth manager", .serialized)
struct AuthManagerTests {
    private let serviceName = "com.sparrowtek.avocadough.tests.\(UUID().uuidString)"
    private let installMarker = FileManager.default.temporaryDirectory
        .appending(path: "AuthManagerTests-\(UUID().uuidString)/installed")

    private static let sessionExpiredMessage = "Your session expired. Please sign in again."

    /// Hands `body` a manager over a Keychain service of its own, then signs it out and
    /// removes what it stored.
    ///
    /// - Parameter firstLaunch: Whether the install has never launched before, which is
    ///   when a session found in the Keychain is discarded.
    private func withManager(
        firstLaunch: Bool = false,
        _ body: (AuthManager, AuthStorage) async throws -> Void
    ) async throws {
        let markerDirectory = installMarker.deletingLastPathComponent()
        if !firstLaunch {
            try FileManager.default.createDirectory(at: markerDirectory, withIntermediateDirectories: true)
            try Data().write(to: installMarker)
        }

        let storage = AuthStorage(serviceName: serviceName, installMarker: installMarker)
        let manager = AuthManager(storage: storage)

        let outcome: Result<Void, any Error>
        do {
            outcome = .success(try await body(manager, storage))
        } catch {
            outcome = .failure(error)
        }

        await manager.logout()
        try? FileManager.default.removeItem(at: markerDirectory)
        try outcome.get()
    }

    /// Stores a session whose access token is, unless told otherwise, valid for another
    /// hour.
    private func storeSession(
        in storage: AuthStorage,
        scopes: String,
        accessTokenExpiry: Date = Date(timeIntervalSinceNow: 3600)
    ) async throws {
        let login = Login(
            accessToken: Token(value: "access", expiry: accessTokenExpiry),
            refreshToken: Token(value: "refresh"),
            scopes: scopes,
            issuingServer: "https://bsky.social"
        )
        try await storage.storeLogin(login)
        try await storage.storePrivateKey(Data(P256.Signing.PrivateKey().pemRepresentation.utf8))
        try await storage.storeSessionMetadata(
            did: "did:plc:alice",
            handle: "alice.test",
            pdsEndpoint: "https://pds.test"
        )
    }

    // MARK: - Nothing to restore

    @Test("With nothing stored, nobody is signed in and nothing is said")
    func nothingStored() async throws {
        try await withManager { manager, _ in
            await manager.restoreSession()

            #expect(!manager.isLoggedIn)
            #expect(!manager.isRestoringSession)
            #expect(manager.currentDID == nil)
            #expect(manager.authError == nil)
            #expect(!manager.canPublishPaymentEndpoint)
        }
    }

    @Test("A session left by an earlier install is discarded without a word")
    func sessionFromEarlierInstall() async throws {
        try await withManager(firstLaunch: true) { manager, storage in
            try await storeSession(in: storage, scopes: "atproto repo:xyz.avocadough.payment.endpoint")

            await manager.restoreSession()

            #expect(!manager.isLoggedIn)
            #expect(manager.authError == nil)
            #expect(try await storage.storedSession() == .none)
        }
    }

    @Test("A session with missing parts is cleared, and the user is told to sign in again")
    func incompleteSession() async throws {
        try await withManager { manager, storage in
            try await storage.storeSessionMetadata(did: "did:plc:alice", handle: "alice.test", pdsEndpoint: "https://pds.test")

            await manager.restoreSession()

            #expect(!manager.isLoggedIn)
            #expect(manager.authError == Self.sessionExpiredMessage)
            #expect(try await storage.storedSession() == .none)
        }
    }

    // MARK: - Restoring

    @Test("A stored session with a valid access token is restored")
    func validSession() async throws {
        try await withManager { manager, storage in
            try await storeSession(in: storage, scopes: "atproto repo:xyz.avocadough.payment.endpoint")

            await manager.restoreSession()

            #expect(manager.isLoggedIn)
            #expect(manager.currentDID == "did:plc:alice")
            #expect(manager.currentHandle == "alice.test")
            #expect(manager.currentPDSEndpoint == "https://pds.test")
            #expect(manager.ungrantedScopes.isEmpty)
            #expect(manager.canPublishPaymentEndpoint)
            #expect(manager.authError == nil)
        }
    }

    @Test("A session whose access token has run out is still restored, without asking anyone")
    func expiredAccessToken() async throws {
        try await withManager { manager, storage in
            try await storeSession(
                in: storage,
                scopes: "atproto repo:xyz.avocadough.payment.endpoint",
                accessTokenExpiry: Date(timeIntervalSinceNow: -3600)
            )

            await manager.restoreSession()

            // The tokens are refreshed when a write is about to need them, not at launch.
            #expect(manager.isLoggedIn)
            #expect(manager.currentDID == "did:plc:alice")
            #expect(manager.authError == nil)
            #expect(try await storage.storedSession() != .none)
        }
    }

    @Test("A session the host granted without the record scope is signed in but can't publish")
    func sessionWithoutRecordScope() async throws {
        try await withManager { manager, storage in
            try await storeSession(in: storage, scopes: "atproto")

            await manager.restoreSession()

            #expect(manager.isLoggedIn)
            #expect(manager.ungrantedScopes == ["repo:xyz.avocadough.payment.endpoint"])
            #expect(!manager.canPublishPaymentEndpoint)
        }
    }

    @Test("Restoring twice changes nothing")
    func restoreIsIdempotent() async throws {
        try await withManager { manager, storage in
            try await storeSession(in: storage, scopes: "atproto repo:xyz.avocadough.payment.endpoint")

            await manager.restoreSession()
            await manager.restoreSession()

            #expect(manager.isLoggedIn)
            #expect(manager.currentHandle == "alice.test")
        }
    }

    // MARK: - Refreshing

    @Test("A token that is still good is left alone")
    func refreshNotNeeded() async throws {
        try await withManager { manager, storage in
            try await storeSession(in: storage, scopes: "atproto repo:xyz.avocadough.payment.endpoint")
            await manager.restoreSession()
            let before = try await storage.retrieveLogin()

            await manager.refreshSessionIfNeeded()

            #expect(manager.isLoggedIn)
            #expect(manager.authError == nil)
            #expect(try await storage.retrieveLogin() == before)
        }
    }

    @Test("With nobody signed in there is nothing to refresh")
    func refreshWhileSignedOut() async throws {
        try await withManager { manager, _ in
            await manager.refreshSessionIfNeeded()

            #expect(!manager.isLoggedIn)
            #expect(manager.authError == nil)
        }
    }

    // MARK: - Signing in and out

    @Test("Signing in is refused while a session is in use, and the session is left alone")
    func loginWhileSignedIn() async throws {
        try await withManager { manager, storage in
            try await storeSession(in: storage, scopes: "atproto repo:xyz.avocadough.payment.endpoint")
            await manager.restoreSession()

            await manager.login(identifier: "bob.test")

            #expect(manager.isLoggedIn)
            #expect(manager.currentDID == "did:plc:alice")
            #expect(try await storage.storedSession() != .none)
        }
    }

    @Test("Signing out forgets the session everywhere")
    func logout() async throws {
        try await withManager { manager, storage in
            try await storeSession(in: storage, scopes: "atproto repo:xyz.avocadough.payment.endpoint")
            await manager.restoreSession()

            await manager.logout()

            #expect(!manager.isLoggedIn)
            #expect(manager.currentDID == nil)
            #expect(manager.currentHandle == nil)
            #expect(manager.currentPDSEndpoint == nil)
            #expect(manager.authError == nil)
            #expect(!manager.canPublishPaymentEndpoint)
            #expect(try await storage.storedSession() == .none)
        }
    }

    @Test("The sign-in screen's message is dropped once it has been shown")
    func clearAuthError() async throws {
        try await withManager { manager, storage in
            try await storage.storeSessionMetadata(did: "did:plc:alice", handle: "alice.test", pdsEndpoint: "https://pds.test")
            await manager.restoreSession()
            #expect(manager.authError == Self.sessionExpiredMessage)

            manager.clearAuthError()

            #expect(manager.authError == nil)
        }
    }
}
