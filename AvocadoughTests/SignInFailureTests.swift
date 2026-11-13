//
//  SignInFailureTests.swift
//  AvocadoughTests
//

import CoreATProtocol
import Foundation
import Testing
@testable import Avocadough

@Suite("Sign-in failures")
struct SignInFailureTests {

    // MARK: - The redirect back from the account host

    @Test("A redirect with an authorization code is not a failure")
    func codeIsNotAFailure() throws {
        let url = try #require(URL(string: "https://avocadough.xyz/oauth/callback?code=abc&state=xyz&iss=https%3A%2F%2Fbsky.social"))
        #expect(AuthorizationCallback.failure(in: url) == nil)
    }

    @Test("access_denied means the user declined")
    func accessDenied() throws {
        let url = try #require(URL(string: "https://avocadough.xyz/oauth/callback?error=access_denied&error_description=The+user+rejected+the+request&state=xyz&iss=https%3A%2F%2Fbsky.social"))
        #expect(AuthorizationCallback.failure(in: url) == .accessDenied)
    }

    @Test("Any other error carries the host's description")
    func otherErrorWithDescription() throws {
        let url = try #require(URL(string: "https://avocadough.xyz/oauth/callback?error=invalid_scope&error_description=Scope+%22repo%3Axyz.avocadough.payment.endpoint%22+is+not+supported&state=xyz"))
        #expect(AuthorizationCallback.failure(in: url) == .rejectedByHost("Scope \"repo:xyz.avocadough.payment.endpoint\" is not supported"))
    }

    @Test("Without a description the error code stands in for it")
    func otherErrorWithoutDescription() throws {
        let bare = try #require(URL(string: "https://avocadough.xyz/oauth/callback?error=server_error&state=xyz"))
        let empty = try #require(URL(string: "https://avocadough.xyz/oauth/callback?error=server_error&error_description=&state=xyz"))

        #expect(AuthorizationCallback.failure(in: bare) == .rejectedByHost("server_error"))
        #expect(AuthorizationCallback.failure(in: empty) == .rejectedByHost("server_error"))
    }

    // MARK: - What the sign-in screen says

    /// `ATProtoOAuth` wraps whatever stopped the flow in this.
    private struct FlowError: LocalizedError {
        var errorDescription: String? { "Authentication failed: OAuth flow failed: something" }
    }

    @Test("Closing the sign-in page shows no message")
    func cancelIsSilent() {
        #expect(AuthManager.signInMessage(for: FlowError(), webAuthenticationFailure: .cancelled) == nil)
    }

    @Test("Declining on the host's page says so, without the flow's own wording")
    func declineIsNamed() {
        #expect(AuthManager.signInMessage(for: FlowError(), webAuthenticationFailure: .accessDenied) == "You declined access")
    }

    @Test("A sign-in page that could not be shown says so")
    func presentationFailureIsNamed() {
        let message = AuthManager.signInMessage(for: FlowError(), webAuthenticationFailure: .presentationFailed)
        #expect(message == AuthError.presentationFailed.errorDescription)
        #expect(message?.isEmpty == false)
    }

    @Test("A host that turns the sign-in down is quoted")
    func hostRejectionIsQuoted() {
        let message = AuthManager.signInMessage(for: FlowError(), webAuthenticationFailure: .rejectedByHost("Scope is not supported"))
        #expect(message == "Your account host did not complete the sign-in: Scope is not supported")
    }

    @Test("A failure outside the sign-in page keeps its own description")
    func otherFailuresKeepTheirDescription() {
        #expect(AuthManager.signInMessage(for: FlowError(), webAuthenticationFailure: nil) == "Authentication failed: OAuth flow failed: something")
    }

    @Test("A handle that cannot be resolved is explained without the resolver's error code")
    func unresolvedHandle() {
        let error = ATProtoOAuthError.authenticationFailed("Identity resolution failed: The operation couldn’t be completed. (CoreATProtocol.IdentityError error 3.)")
        let message = AuthManager.signInMessage(for: error, webAuthenticationFailure: nil)

        #expect(message == "Avocadough could not find that account. Check the handle and your connection, then try again.")
    }

    @Test("Other failures of the flow are passed on as they are")
    func otherFlowFailure() {
        let error = ATProtoOAuthError.authenticationFailed("Failed to load client metadata from https://avocadough.xyz/oauth/client-metadata.json: offline")
        let message = AuthManager.signInMessage(for: error, webAuthenticationFailure: nil)

        #expect(message == error.localizedDescription)
    }

    // MARK: - Refresh failures

    @Test(
        "A refresh the authorization server rejects for good ends the session",
        arguments: [
            ATProtoOAuthError.refreshTokenUnavailable,
            .refreshKeyUnavailable,
            .refreshIssuerUnavailable,
            .tokenRequestFailed("invalid_grant: Refresh token expired"),
            .tokenRequestFailed("invalid_client: Client assertion signed with an unknown key"),
            .tokenRequestFailed("INVALID_TOKEN: nope"),
            .tokenRequestFailed("unauthorized_client: "),
        ]
    )
    func unrecoverableRefresh(error: ATProtoOAuthError) {
        #expect(AuthManager.isUnrecoverableRefreshError(error))
    }

    @Test(
        "A refresh that may work later keeps the session",
        arguments: [
            ATProtoOAuthError.tokenRequestFailed("server_error: try again"),
            .tokenRequestFailed("temporarily_unavailable: "),
            .invalidTokenResponse,
            .authenticationFailed("Authorization server issuer is not valid for resolved PDS."),
        ]
    )
    func transientRefresh(error: ATProtoOAuthError) {
        #expect(!AuthManager.isUnrecoverableRefreshError(error))
    }

    @Test("A network failure during a refresh keeps the session")
    func offlineRefresh() {
        #expect(!AuthManager.isUnrecoverableRefreshError(URLError(.notConnectedToInternet)))
    }

    // MARK: - Granted scopes

    @Test("Every requested scope granted leaves nothing missing, whatever the order")
    func allScopesGranted() {
        let granted = Build.Constants.ATProto.scopes.reversed().joined(separator: " ")
        #expect(AuthManager.ungrantedScopes(in: granted).isEmpty)
    }

    @Test("A scope the host dropped is named")
    func droppedScope() {
        #expect(AuthManager.ungrantedScopes(in: "atproto") == ["repo:xyz.avocadough.payment.endpoint"])
    }

    @Test("Scopes the host granted on top of the request are not a problem")
    func extraScopes() {
        let granted = "atproto transition:generic repo:xyz.avocadough.payment.endpoint"
        #expect(AuthManager.ungrantedScopes(in: granted).isEmpty)
    }
}
