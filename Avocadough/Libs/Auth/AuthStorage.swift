//
//  AuthStorage.swift
//  Avocadough
//

import Foundation
import Vault
import CoreATProtocol

/// A session as it sits in the Keychain between launches.
struct StoredSession: Equatable, Sendable {
    let did: String
    let handle: String
    let pdsEndpoint: String
    let login: Login
    /// PEM of the DPoP key the tokens are bound to.
    let privateKeyPEM: String
}

/// What the Keychain holds when a launch looks for a session.
enum StoredSessionState: Equatable, Sendable {
    /// Nobody is signed in.
    case none
    /// An account is on record, but part of what its session needs is gone.
    /// Nothing can bring the session back; the user has to sign in again.
    case incomplete
    case complete(StoredSession)
}

/// Persists the AT Protocol session in the Keychain through Vault and provides the
/// `ATProtoAuthStorage` closures `ATProtoOAuth` reads and writes it with.
///
/// The items live under a Keychain service of their own, so `clearAll()` signs the
/// identity out without touching the wallet's NWC secret, which is filed under
/// `KeychainConfiguration.serviceName`.
struct AuthStorage: Sendable {

    /// The Keychain service the session is filed under.
    static let serviceName = "com.sparrowtek.avocadough.atproto"

    private enum Account: String {
        case login
        case privateKey
        case did
        case handle
        case pdsEndpoint
        case authProxySessionKeyID
    }

    /// Where the app keeps the file that marks an install as having launched before.
    static var installMarker: URL {
        URL.applicationSupportDirectory.appending(path: "Identity/installed")
    }

    private let serviceName: String
    private let vault: Vault
    private let installMarker: URL

    /// - Parameter installMarker: A file that exists once this install has launched. See
    ///   ``discardSessionFromEarlierInstall()``.
    init(
        serviceName: String = AuthStorage.serviceName,
        vault: Vault = .shared,
        installMarker: URL = AuthStorage.installMarker
    ) {
        self.serviceName = serviceName
        self.vault = vault
        self.installMarker = installMarker
    }

    /// Readable once the device has been unlocked after a restart, so a token refresh
    /// still works when the app is woken with the screen locked, and never included in
    /// a backup or moved to another device.
    private func configuration(for account: Account) -> KeychainConfiguration {
        KeychainConfiguration(
            serviceName: serviceName,
            accessGroup: nil,
            accountName: "\(serviceName).\(account.rawValue)",
            accessibility: .afterFirstUnlockThisDeviceOnly
        )
    }

    // MARK: - Raw storage

    private func store(_ value: String, at account: Account) async throws {
        try await vault.save(value, configuration: configuration(for: account))
    }

    /// Returns the stored value, or `nil` when nothing is stored for `account`.
    /// Throws when the Keychain could not answer, which says nothing about whether a
    /// value exists.
    private func retrieve(_ account: Account) async throws -> String? {
        do {
            return try await vault.read(configuration: configuration(for: account))
        } catch VaultError.itemNotFound {
            return nil
        }
    }

    // MARK: - Login persistence

    func storeLogin(_ login: Login) async throws {
        let data = try JSONEncoder().encode(login)
        try await store(String(decoding: data, as: UTF8.self), at: .login)
    }

    func retrieveLogin() async throws -> Login? {
        guard let json = try await retrieve(.login) else { return nil }
        return try JSONDecoder().decode(Login.self, from: Data(json.utf8))
    }

    // MARK: - Private key persistence

    func storePrivateKey(_ keyData: Data) async throws {
        // The key arrives as PEM text. Anything else is refused instead of being stored
        // as a value nothing could read back.
        guard let pem = String(data: keyData, encoding: .utf8) else {
            throw VaultError.encodingFailed
        }
        try await store(pem, at: .privateKey)
    }

    func retrievePrivateKey() async throws -> Data? {
        try await retrieve(.privateKey).map { Data($0.utf8) }
    }

    // MARK: - Session metadata

    func storeSessionMetadata(did: String, handle: String, pdsEndpoint: String) async throws {
        try await store(did, at: .did)
        try await store(handle, at: .handle)
        try await store(pdsEndpoint, at: .pdsEndpoint)
    }

    // MARK: - Stored session

    /// Reads everything a launch needs to bring the session back.
    ///
    /// Throws when the Keychain could not be read or a value could not be decoded.
    /// Neither says the session is gone (the Keychain is unreadable until the device has
    /// been unlocked once after a restart, for one), so callers must leave the stored
    /// session alone when this throws.
    func storedSession() async throws -> StoredSessionState {
        guard let did = try await retrieve(.did) else { return .none }

        guard let handle = try await retrieve(.handle),
              let pdsEndpoint = try await retrieve(.pdsEndpoint),
              let login = try await retrieveLogin(),
              let privateKeyPEM = try await retrieve(.privateKey) else {
            return .incomplete
        }

        return .complete(StoredSession(
            did: did,
            handle: handle,
            pdsEndpoint: pdsEndpoint,
            login: login,
            privateKeyPEM: privateKeyPEM
        ))
    }

    // MARK: - Auth proxy key ID persistence

    /// The auth service answers a sign-in with the ID of the client key it signed with,
    /// and every later refresh of that session has to name the same key. The tokens are
    /// stored next to the ID so an ID left over from another session is never sent.
    private struct AuthProxySessionKeyRecord: Codable {
        let refreshToken: String?
        let accessToken: String
        let keyID: String
    }

    func storeAuthProxyKeyID(_ keyID: String, for login: Login) async throws {
        let record = AuthProxySessionKeyRecord(
            refreshToken: login.refreshToken?.value,
            accessToken: login.accessToken.value,
            keyID: keyID
        )
        let data = try JSONEncoder().encode(record)
        try await store(String(decoding: data, as: UTF8.self), at: .authProxySessionKeyID)
    }

    func retrieveAuthProxyKeyID(for login: Login) async throws -> String? {
        guard let json = try await retrieve(.authProxySessionKeyID) else { return nil }
        let record = try JSONDecoder().decode(AuthProxySessionKeyRecord.self, from: Data(json.utf8))

        if let refreshToken = login.refreshToken?.value {
            return record.refreshToken == refreshToken ? record.keyID : nil
        }

        return record.accessToken == login.accessToken.value ? record.keyID : nil
    }

    func clearAuthProxyKeyID() async throws {
        try await vault.delete(configuration: configuration(for: .authProxySessionKeyID))
    }

    // MARK: - Clear all

    /// Deletes every item of the session. Wallet secrets are filed under another
    /// service and are untouched.
    func clearAll() async throws {
        try await vault.deleteAll(configuration: configuration(for: .login))
    }

    /// Discards a session left behind by an earlier install of the app.
    ///
    /// The Keychain outlives the app: delete Avocadough, install it again, and the old
    /// session is still there. The first launch of an install therefore clears it, and
    /// leaves a marker file behind (the app's files do not outlive it) so later launches
    /// keep theirs.
    ///
    /// - Returns: `true` on the first launch of this install.
    func discardSessionFromEarlierInstall() async throws -> Bool {
        let fileManager = FileManager.default
        guard !fileManager.fileExists(atPath: installMarker.path()) else { return false }

        try await clearAll()
        try fileManager.createDirectory(at: installMarker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: installMarker)
        return true
    }

    // MARK: - CoreATProtocol integration

    /// The storage `ATProtoOAuth` expects.
    var atProtoAuthStorage: ATProtoAuthStorage {
        ATProtoAuthStorage(
            retrieveLogin: { try await retrieveLogin() },
            storeLogin: { try await storeLogin($0) },
            retrievePrivateKey: { try await retrievePrivateKey() },
            storePrivateKey: { try await storePrivateKey($0) },
            retrieveAuthProxyKeyID: { try await retrieveAuthProxyKeyID(for: $0) },
            storeAuthProxyKeyID: { try await storeAuthProxyKeyID($1, for: $0) },
            clearAuthProxyKeyID: { _ in try await clearAuthProxyKeyID() }
        )
    }
}
