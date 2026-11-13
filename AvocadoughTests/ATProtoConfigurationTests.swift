//
//  ATProtoConfigurationTests.swift
//  AvocadoughTests
//

import Foundation
import Testing
@testable import Avocadough

/// The sign-in configuration lives in three places that have to agree: the app's
/// constants, its entitlements, and the client metadata hosted on avocadough.xyz. A
/// mismatch between any two does not fail to build; it fails to sign in.
@Suite("AT Protocol configuration")
struct ATProtoConfigurationTests {
    /// `<avocadough>/iOS`, seen from `<avocadough>/iOS/AvocadoughTests/` where this
    /// file lives.
    private static let projectDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// The entitlements the app is signed with.
    static let entitlementsURL = projectDirectory
        .appending(path: "Avocadough/System/Avocadough.entitlements")

    /// The client metadata in the website's repository, which sits next to this one.
    static let metadataURL = projectDirectory
        .deletingLastPathComponent()
        .appending(path: "web/oauth/client-metadata.json")

    private typealias ATProto = Build.Constants.ATProto

    // MARK: - Scopes

    @Test("The app asks for atproto and the payment endpoint collection, and nothing else")
    func requestedScopes() {
        #expect(ATProto.scopes.joined(separator: " ") == "atproto repo:xyz.avocadough.payment.endpoint")
    }

    @Test("No scope is broader than one collection")
    func scopesStayNarrow() {
        let repoScopes = ATProto.scopes.dropFirst()

        #expect(ATProto.scopes.first == "atproto")
        #expect(repoScopes.allSatisfy { $0.hasPrefix("repo:xyz.avocadough.") })
        // The PAR body is split on "&", so an "?action=" form would be cut short
        // without anyone noticing.
        #expect(!ATProto.scopes.contains { $0.contains("?") || $0.contains("*") || $0.contains(" ") })
    }

    // MARK: - Auth service

    @Test("Token requests go to Avocadough's path on the shared auth service")
    func authProxyBaseURL() throws {
        let url = try #require(URL(string: ATProto.authProxyBaseURL))

        #expect(url.scheme == "https")
        #expect(url.host() == "auth.sparrowtek.com")
        #expect(url.path() == "/avocadough")
        // CoreATProtocol appends "/oauth/par" and "/oauth/token" to this as text.
        #expect(!ATProto.authProxyBaseURL.hasSuffix("/"))
    }

    // MARK: - Redirect

    @Test("The redirect comes back over https to the host that serves the client metadata")
    func redirectURI() throws {
        let redirect = try #require(URL(string: ATProto.redirectURI))
        let metadata = try #require(URL(string: ATProto.clientMetadataURL))

        #expect(redirect.scheme == "https")
        #expect(redirect.host() == metadata.host())
        #expect(redirect.path() == "/oauth/callback")
    }

    @Test(
        "The redirect host is one of the app's associated domains",
        .enabled(if: FileManager.default.fileExists(atPath: ATProtoConfigurationTests.entitlementsURL.path()))
    )
    func redirectHostIsAssociated() throws {
        let host = try #require(URL(string: ATProto.redirectURI)?.host())
        let entitlements = try PropertyListSerialization.propertyList(from: Data(contentsOf: Self.entitlementsURL), format: nil)
        let domains = try #require((entitlements as? [String: Any])?["com.apple.developer.associated-domains"] as? [String])

        // `ASWebAuthenticationSession` only hands an https callback to an app that is
        // associated with its host.
        #expect(domains.contains("applinks:\(host)"))
        #expect(domains.contains("webcredentials:\(host)"))
    }

    // MARK: - Hosted client metadata

    @Test(
        "The hosted client metadata matches the app",
        .enabled(if: FileManager.default.fileExists(atPath: ATProtoConfigurationTests.metadataURL.path()))
    )
    func clientMetadata() throws {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.metadataURL))
        let metadata = try #require(object as? [String: Any])

        #expect(metadata["client_id"] as? String == ATProto.clientMetadataURL)
        #expect(metadata["scope"] as? String == ATProto.scopes.joined(separator: " "))
        #expect((metadata["redirect_uris"] as? [String])?.contains(ATProto.redirectURI) == true)

        // A confidential client whose key is served by the auth service at the same
        // path the app sends its token requests to.
        #expect(metadata["token_endpoint_auth_method"] as? String == "private_key_jwt")
        #expect(metadata["jwks_uri"] as? String == "\(ATProto.authProxyBaseURL)/.well-known/jwks.json")
        #expect(metadata["dpop_bound_access_tokens"] as? Bool == true)
    }
}
