//
//  AuthManager.swift
//  Avocadough
//

import Foundation
import AuthenticationServices
import CoreATProtocol
import os
import Synchronization

/// Manages the AT Protocol OAuth session.
///
/// Signing in gives Avocadough an authenticated session against the user's PDS, which
/// `PaymentEndpointPublisher` needs to write the `xyz.avocadough.payment.endpoint` record
/// that makes an @handle payable. Paying a handle needs no session: that lookup is public.
@MainActor
@Observable
final class AuthManager {

    // MARK: - State

    private(set) var isLoggedIn = false
    private(set) var currentDID: String?
    private(set) var currentHandle: String?

    /// The signed-in account's PDS, where its public records are read from.
    private(set) var currentPDSEndpoint: String?

    private(set) var isAuthenticating = false

    /// `true` while a launch is still finding out whether the stored session can be
    /// used. Until this settles the account is neither signed in nor signed out, and
    /// starting a new sign-in would discard the stored one.
    private(set) var isRestoringSession = false

    /// What the sign-in screen has to tell the user: why the last attempt failed, or
    /// that the session ran out.
    private(set) var authError: String?

    /// Scopes that were asked for at sign-in and that the account host left out of its
    /// grant. A host that does not know a scope may drop it and still sign the user in;
    /// every write that needs the scope is then refused.
    private(set) var ungrantedScopes: [String] = []

    /// Whether the session may write the payment endpoint record.
    var canPublishPaymentEndpoint: Bool {
        isLoggedIn && ungrantedScopes.isEmpty
    }

    // MARK: - Dependencies

    private let storage: AuthStorage

    /// Why the sign-in page step of the attempt in progress failed. `ATProtoOAuth`
    /// reports every failure of the flow as the same error with the cause flattened
    /// into text, so the cause is kept here.
    @ObservationIgnored
    private var webAuthenticationFailure: AuthError?

    // Logger is Sendable and stateless, so the token refresh handler can log from
    // whichever actor it runs on.
    nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.sparrowtek.avocadough",
        category: "auth"
    )

    private static let sessionExpiredMessage = String(localized: "Your session expired. Please sign in again.")

    /// An access token with less than this left to live is refreshed before it is used,
    /// so it cannot run out between the check and the request it is for.
    private static let accessTokenMargin: TimeInterval = 60

    init(storage: AuthStorage = AuthStorage()) {
        self.storage = storage
    }

    // MARK: - Configuration

    /// Avocadough as an OAuth client: a confidential client whose token requests are
    /// signed by the shared auth service, which is why they can never go to the
    /// authorization server directly.
    nonisolated static let oauthConfig = ATProtoOAuthConfig(
        clientMetadataURL: Build.Constants.ATProto.clientMetadataURL,
        redirectURI: Build.Constants.ATProto.redirectURI,
        scopes: Build.Constants.ATProto.scopes,
        authProxyBaseURL: Build.Constants.ATProto.authProxyBaseURL,
        clientAuthMethod: .privateKeyJWT
    )

    // MARK: - Session restoration

    /// Brings back the session a previous launch left in the Keychain, if there is one.
    ///
    /// Nothing here touches the network. The session is only needed to write the payment
    /// endpoint record, so its tokens are brought up to date when that is about to
    /// happen (``refreshSessionIfNeeded()``), not every time the wallet is opened.
    func restoreSession() async {
        guard !isLoggedIn, !isAuthenticating, !isRestoringSession else { return }

        isRestoringSession = true
        defer { isRestoringSession = false }

        let stored: StoredSession
        do {
            if try await storage.discardSessionFromEarlierInstall() { return }

            switch try await storage.storedSession() {
            case .none:
                return
            case .incomplete:
                Self.logger.warning("The stored session is incomplete and cannot be restored")
                await endSession(because: Self.sessionExpiredMessage)
                return
            case .complete(let session):
                stored = session
            }
        } catch {
            // A Keychain that cannot be read says nothing about the session in it.
            // Leave it alone: wiping here would sign out a user whose session is fine.
            Self.logger.error("Session not restored, the Keychain could not be read: \(error.localizedDescription, privacy: .public)")
            return
        }

        await configureDPoPKey(pem: stored.privateKeyPEM)
        await configureTokenRefreshHandler()
        await configureCoreATProtocol(
            pdsEndpoint: stored.pdsEndpoint,
            accessToken: stored.login.accessToken.value,
            refreshToken: stored.login.refreshToken?.value
        )

        beginSession(did: stored.did, handle: stored.handle, pdsEndpoint: stored.pdsEndpoint, grantedScopes: stored.login.scopes)
        Self.logger.info("Session restored for \(stored.handle)")
    }

    /// Brings the session's tokens up to date before a request that needs them.
    ///
    /// Call this before writing to the user's repository. Access tokens are short-lived
    /// and the app may have been open far longer, and a request that starts out with an
    /// expired token can fail outright instead of being retried. When the authorization
    /// server no longer accepts the session, it ends here and `authError` says why, so
    /// check `isLoggedIn` afterwards.
    func refreshSessionIfNeeded() async {
        guard isLoggedIn, let did = currentDID else { return }

        switch await refreshOAuthTokens(did: did) {
        case .refreshed(let login):
            await updateTokens(access: login.accessToken.value, refresh: login.refreshToken?.value)

        case .notNeeded, .transientFailure:
            // notNeeded: the stored access token is still good.
            // transientFailure: the authorization server could not be reached (offline,
            // say). The request that follows fails for the same reason and says so.
            break

        case .unrecoverable:
            // The authorization server rejected the refresh token: revoked, or unused
            // for too long. No retry recovers from that, and staying "signed in" would
            // leave every request failing.
            await endSession(because: Self.sessionExpiredMessage)
        }
    }

    // MARK: - Login

    /// Signs in with a handle or a DID. The outcome is in `isLoggedIn` and `authError`.
    func login(identifier: String) async {
        // A sign-in starts by clearing what is stored, which must not happen to a
        // session that is in use or in the middle of being restored.
        guard !isAuthenticating, !isRestoringSession, !isLoggedIn else { return }

        isAuthenticating = true
        authError = nil
        webAuthenticationFailure = nil

        defer { isAuthenticating = false }

        do {
            // Clear what an earlier, failed attempt may have left behind.
            try? await storage.clearAll()

            let oauth = await ATProtoOAuth(config: Self.oauthConfig, storage: storage.atProtoAuthStorage)

            let result = try await oauth.authenticate(
                identifier: identifier,
                userAuthenticator: { [weak self] authorizationURL, _ in
                    guard let self else { throw AuthError.cancelled }
                    return try await authorize(at: authorizationURL)
                }
            )

            try LoginValidator.validateDID(result.did)
            try LoginValidator.validateHandle(result.handle)
            try LoginValidator.validatePDSEndpoint(result.pdsEndpoint)

            try await storage.storeSessionMetadata(
                did: result.did,
                handle: result.handle,
                pdsEndpoint: result.pdsEndpoint
            )

            let privateKeyPEM = await oauth.privateKeyPEM
            try await storage.storePrivateKey(Data(privateKeyPEM.utf8))

            await configureCoreATProtocol(
                pdsEndpoint: result.pdsEndpoint,
                accessToken: result.accessToken,
                refreshToken: result.refreshToken
            )
            await configureDPoPKey(pem: privateKeyPEM)
            await configureTokenRefreshHandler()

            let grantedScopes = try? await storage.retrieveLogin()?.scopes
            beginSession(did: result.did, handle: result.handle, pdsEndpoint: result.pdsEndpoint, grantedScopes: grantedScopes)

            Self.logger.info("Login succeeded for \(result.handle)")
        } catch {
            Self.logger.error("Login failed: \(String(describing: error))")
            try? await storage.clearAll()
            // `authenticate` configures the session before it returns, so a failure
            // after that point has to take it down again.
            await configureCoreATProtocol(pdsEndpoint: nil, accessToken: nil, refreshToken: nil)
            authError = Self.signInMessage(for: error, webAuthenticationFailure: webAuthenticationFailure)
        }
    }

    /// What the sign-in screen says after a failed attempt, or `nil` when it should say
    /// nothing: closing the sign-in page is a decision, not an error.
    nonisolated static func signInMessage(for error: any Error, webAuthenticationFailure: AuthError?) -> String? {
        switch webAuthenticationFailure {
        case .cancelled:
            nil
        case .some(let failure):
            failure.errorDescription
        case .none:
            if case .authenticationFailed(let detail) = error as? ATProtoOAuthError,
               detail.hasPrefix("Identity resolution failed") {
                // `ATProtoOAuth` reports a handle it could not resolve with the
                // resolver's error spelled out, and the resolver's errors have no
                // description: "IdentityError error 3".
                String(localized: "Avocadough could not find that account. Check the handle and your connection, then try again.")
            } else {
                error.localizedDescription
            }
        }
    }

    /// The scopes that were asked for but are missing from `granted`, the
    /// space-separated scope string of a token response.
    nonisolated static func ungrantedScopes(
        in granted: String,
        requested: [String] = Build.Constants.ATProto.scopes
    ) -> [String] {
        let grantedScopes = Set(granted.split(separator: " ").map(String.init))
        return requested.filter { !grantedScopes.contains($0) }
    }

    /// Shows the account host's sign-in page and returns the URL it redirects back to.
    /// A failure is remembered before it is thrown; see ``webAuthenticationFailure``.
    private func authorize(at url: URL) async throws -> URL {
        do {
            let callbackURL = try await WebAuthSession.authenticate(
                url: url,
                redirectURI: Build.Constants.ATProto.redirectURI
            )
            if let failure = AuthorizationCallback.failure(in: callbackURL) {
                throw failure
            }
            return callbackURL
        } catch let failure as AuthError {
            webAuthenticationFailure = failure
            throw failure
        }
    }

    /// Drops the message for the sign-in screen once the screen has shown it.
    func clearAuthError() {
        authError = nil
    }

    // MARK: - Logout

    /// Signs out and forgets the session. The payment endpoint record stays published:
    /// it is the user's public record, and removing it is their call.
    func logout() async {
        await endSession(because: nil)
        Self.logger.info("Logged out")
    }

    // MARK: - Session lifecycle

    private func beginSession(did: String, handle: String, pdsEndpoint: String, grantedScopes: String?) {
        currentDID = did
        currentHandle = handle
        currentPDSEndpoint = pdsEndpoint
        // A grant that cannot be read is taken at its word; a write that the host then
        // refuses says so itself.
        ungrantedScopes = grantedScopes.map { Self.ungrantedScopes(in: $0) } ?? []
        isLoggedIn = true

        if !ungrantedScopes.isEmpty {
            Self.logger.warning("Requested scopes missing from the grant: \(self.ungrantedScopes.joined(separator: " "), privacy: .public)")
        }
    }

    /// Takes the session down everywhere it lives: the networking layer, the Keychain,
    /// and this object's state. `message` is what the sign-in screen shows afterwards.
    private func endSession(because message: String?) async {
        await setTokenRefreshHandler(nil)
        try? await setDPoPPrivateKey(pem: nil)

        do {
            try await storage.clearAll()
        } catch {
            Self.logger.error("The stored session could not be cleared: \(error.localizedDescription, privacy: .public)")
        }

        await configureCoreATProtocol(pdsEndpoint: nil, accessToken: nil, refreshToken: nil)

        currentDID = nil
        currentHandle = nil
        currentPDSEndpoint = nil
        ungrantedScopes = []
        isLoggedIn = false
        authError = message
    }

    // MARK: - Token refresh

    /// How an attempt to refresh the tokens turned out, so callers can tell "use the new
    /// tokens", "keep using the stored ones", "try again later" and "the user has to
    /// sign in again" apart.
    private enum RefreshOutcome {
        case refreshed(Login)
        case notNeeded
        case transientFailure
        case unrecoverable
    }

    /// Sets up the automatic token refresh used by CoreATProtocol's networking layer.
    /// When a request gets a 401 or 403, the handler refreshes the tokens and the request
    /// is tried again. When the authorization server says the refresh token is no good,
    /// the session is ended, so the app signs out instead of looping on dead tokens.
    private func configureTokenRefreshHandler() async {
        await setTokenRefreshHandler { [weak self, storage] in
            let oauth = await ATProtoOAuth(config: Self.oauthConfig, storage: storage.atProtoAuthStorage)

            do {
                guard let login = try await oauth.refreshLoginIfNeeded(accountIdentifier: nil, force: true) else {
                    return false
                }
                await updateTokens(access: login.accessToken.value, refresh: login.refreshToken?.value)
                return true
            } catch {
                if AuthManager.isUnrecoverableRefreshError(error) {
                    Self.logger.warning("Auto-refresh rejected as unrecoverable: \(error.localizedDescription), signing out")
                    await self?.sessionWasRejected()
                } else {
                    Self.logger.error("Auto-refresh failed (transient): \(error.localizedDescription)")
                }
                return false
            }
        }
    }

    /// Refreshes the tokens if the access token has expired or is about to.
    private func refreshOAuthTokens(did: String) async -> RefreshOutcome {
        let oauth = await ATProtoOAuth(config: Self.oauthConfig, storage: storage.atProtoAuthStorage)

        do {
            let expiry = try await storage.retrieveLogin()?.accessToken.expiry
            let expiresSoon = expiry.map { $0.timeIntervalSinceNow < Self.accessTokenMargin } ?? false

            guard let refreshed = try await oauth.refreshLoginIfNeeded(accountIdentifier: did, force: expiresSoon) else {
                return .notNeeded
            }
            return .refreshed(refreshed)
        } catch {
            if Self.isUnrecoverableRefreshError(error) {
                Self.logger.warning("Token refresh unrecoverable: \(error.localizedDescription)")
                return .unrecoverable
            }
            Self.logger.error("Token refresh transient failure: \(error.localizedDescription)")
            return .transientFailure
        }
    }

    /// Reports whether a refresh error means the refresh token itself is no longer
    /// accepted, as opposed to a failure that may pass, like the authorization server
    /// being briefly unreachable.
    ///
    /// `tokenRequestFailed` carries the OAuth `error` code in its detail string. The
    /// RFC 6749 codes matched here say the credentials themselves are dead: trying again
    /// later won't help, the user has to sign in again.
    nonisolated static func isUnrecoverableRefreshError(_ error: any Error) -> Bool {
        guard let oauthError = error as? ATProtoOAuthError else { return false }
        switch oauthError {
        case .refreshTokenUnavailable,
             .refreshKeyUnavailable,
             .refreshIssuerUnavailable:
            return true
        case .tokenRequestFailed(let detail):
            let lower = detail.lowercased()
            return lower.contains("invalid_grant")
                || lower.contains("invalid_token")
                || lower.contains("invalid_client")
                || lower.contains("unauthorized_client")
        default:
            return false
        }
    }

    /// The authorization server permanently rejected the refresh token while the app was
    /// running. Leaving `isLoggedIn` true with dead credentials would strand the UI in a
    /// state where every action fails, so the session ends here.
    private func sessionWasRejected() async {
        guard isLoggedIn else { return }
        await endSession(because: Self.sessionExpiredMessage)
    }

    /// Configures the DPoP key that authenticated requests are signed with.
    private func configureDPoPKey(pem: String) async {
        do {
            try await setDPoPPrivateKey(pem: pem)
        } catch {
            Self.logger.error("DPoP key setup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func configureCoreATProtocol(
        pdsEndpoint: String?,
        accessToken: String?,
        refreshToken: String?
    ) async {
        await CoreATProtocol.setup(
            hostURL: pdsEndpoint,
            accessJWT: accessToken,
            refreshJWT: refreshToken
        )
    }
}

// MARK: - Web Auth Session Helper

private enum WebAuthSession {

    /// Presents `url` and waits for the redirect to `redirectURI`.
    /// Every failure is an ``AuthError``.
    @MainActor
    static func authenticate(url: URL, redirectURI: String) async throws -> URL {
        guard let redirect = URLComponents(string: redirectURI),
              let host = redirect.host,
              let window = WindowProvider.keyWindow else {
            throw AuthError.presentationFailed
        }

        let contextProvider = WebAuthContextProvider(anchor: window)

        return try await withCheckedThrowingContinuation { continuation in
            let resumption = SingleResumption(continuation)

            let session = ASWebAuthenticationSession(
                url: url,
                callback: .https(host: host, path: redirect.path)
            ) { callbackURL, error in
                // The session only holds its context provider weakly; the completion
                // handler lives exactly as long as the session does, so it keeps the
                // provider alive.
                withExtendedLifetime(contextProvider) {
                    if let callbackURL {
                        resumption.resume(with: .success(callbackURL))
                    } else if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin {
                        resumption.resume(with: .failure(AuthError.cancelled))
                    } else {
                        resumption.resume(with: .failure(AuthError.presentationFailed))
                    }
                }
            }

            session.presentationContextProvider = contextProvider
            session.prefersEphemeralWebBrowserSession = false

            // A session that fails to start never calls its completion handler, which
            // would leave sign-in waiting forever.
            if !session.start() {
                resumption.resume(with: .failure(AuthError.presentationFailed))
            }
        }
    }
}

/// Resumes a continuation the first time it is asked to and ignores every request
/// after that.
private final class SingleResumption<Value: Sendable>: Sendable {
    private let continuation: Mutex<CheckedContinuation<Value, any Error>?>

    init(_ continuation: CheckedContinuation<Value, any Error>) {
        self.continuation = Mutex(continuation)
    }

    func resume(with result: Result<Value, any Error>) {
        let pending = continuation.withLock { continuation in
            defer { continuation = nil }
            return continuation
        }
        pending?.resume(with: result)
    }
}

// MARK: - Window Provider

private enum WindowProvider {

    @MainActor
    static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

// MARK: - ASWebAuthenticationSession Context

private final class WebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding, @unchecked Sendable {
    private let anchor: ASPresentationAnchor

    init(anchor: ASPresentationAnchor) {
        self.anchor = anchor
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        anchor
    }
}
