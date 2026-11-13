//
//  ATProtoLiveTests.swift
//  AvocadoughTests
//

import AvocadoughKit
import CoreATProtocol
import Foundation
import Synchronization
import Testing
@testable import Avocadough

/// Checks the deployed half of the AT Protocol features against the real network: the
/// client metadata on avocadough.xyz, the shared auth service, an authorization server,
/// and the identity lookups behind paying a handle.
///
/// Off by default, since it needs the network and talks to production services. Run it
/// after changing the hosted client metadata, the auth service, or the app's constants:
///
///     TEST_RUNNER_AVOCADOUGH_LIVE_TESTS=1 xcodebuild test … \
///         -only-testing:AvocadoughTests/ATProtoLiveTests
///
/// `TEST_RUNNER_AVOCADOUGH_LIVE_HANDLE` picks the account that is looked up and whose
/// host is asked to start a sign-in. Any existing handle will do: nothing is written, and
/// the sign-in stops before anyone signs in.
@Suite(
    "AT Protocol, live",
    .enabled(if: ProcessInfo.processInfo.environment["AVOCADOUGH_LIVE_TESTS"] == "1")
)
struct ATProtoLiveTests {
    private static var handle: String {
        ProcessInfo.processInfo.environment["AVOCADOUGH_LIVE_HANDLE"] ?? "bsky.app"
    }

    // MARK: - Sign-in

    /// Stops the flow at the point where the app would show the sign-in page.
    private struct StoppedAtSignInPage: Error {}

    /// Keeps the flow's key and tokens in memory, so nothing touches the Keychain.
    private actor MemoryStore {
        var login: Login?
        var privateKey: Data?

        func store(_ login: Login) { self.login = login }
        func store(_ privateKey: Data) { self.privateKey = privateKey }
    }

    @Test("A sign-in gets as far as the account host's sign-in page")
    func reachesTheSignInPage() async throws {
        let store = MemoryStore()
        let storage = ATProtoAuthStorage(
            retrieveLogin: { await store.login },
            storeLogin: { await store.store($0) },
            retrievePrivateKey: { await store.privateKey },
            storePrivateKey: { await store.store($0) }
        )
        let oauth = await ATProtoOAuth(config: AuthManager.oauthConfig, storage: storage)
        let signInPage = Mutex<URL?>(nil)

        // Reaching the authenticator means the pushed authorization request went through:
        // the auth service signed it with Avocadough's key, and the authorization server
        // found that key at the `jwks_uri` in the hosted client metadata, accepted the
        // requested scopes and the redirect URI, and issued a request URI.
        let failure = await #expect(throws: (any Error).self) {
            _ = try await oauth.authenticate(identifier: Self.handle) { authorizationURL, _ in
                signInPage.withLock { $0 = authorizationURL }
                throw StoppedAtSignInPage()
            }
        }

        let url = try #require(
            signInPage.withLock { $0 },
            "The flow failed before the sign-in page: \(String(describing: failure))"
        )
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        #expect(url.scheme == "https")
        #expect(query.first { $0.name == "client_id" }?.value == Build.Constants.ATProto.clientMetadataURL)
        #expect(query.first { $0.name == "request_uri" }?.value?.isEmpty == false)
    }

    // MARK: - Paying a handle

    @Test("A handle is looked up all the way to its account host")
    func lookUpAHandle() async throws {
        do {
            let target = try await PaymentTargetResolver().resolve(.atIdentifier(Self.handle))

            // The identity publishes a payment endpoint; it has to name who it is for.
            let did = try #require(target.identity?.did)
            #expect(did.hasPrefix("did:"))
            #expect(!target.methods.isEmpty)
        } catch let error as PaymentResolutionError {
            // The handle resolved and its host answered: it just has no payment endpoint
            // this wallet can use. Every earlier step of the lookup worked.
            let message = IdentityFailure.lookupMessage(for: error, identifier: "@\(Self.handle)")
            #expect(message.hasPrefix("@\(Self.handle) has"))
        }
    }
}
