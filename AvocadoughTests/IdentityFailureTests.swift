//
//  IdentityFailureTests.swift
//  AvocadoughTests
//

import AvocadoughKit
import CoreATProtocol
import Foundation
import NetworkingKit
import Testing
@testable import Avocadough

@Suite("Identity failure messages")
struct IdentityFailureTests {
    private let handle = "@alice.bsky.social"

    // MARK: - Looking a handle up

    @Test("An identity without a payment endpoint is named as such")
    func noPaymentEndpoint() {
        let message = IdentityFailure.lookupMessage(
            for: PaymentResolutionError.noPaymentEndpoint(identifier: handle),
            identifier: handle
        )
        #expect(message == "@alice.bsky.social has not set up a payment address yet.")
    }

    @Test("An identity that publishes only methods this wallet can't pay says so")
    func noUsablePaymentMethods() {
        let message = IdentityFailure.lookupMessage(
            for: PaymentResolutionError.noUsablePaymentMethods(identifier: handle),
            identifier: handle
        )
        #expect(message == "@alice.bsky.social has no Lightning address Avocadough can pay yet.")
        #expect(message == IdentityFailure.noLightningAddressMessage(identifier: handle))
    }

    @Test(
        "A handle that does not resolve is explained without the resolver's error code",
        arguments: [
            IdentityError.resolutionFailed,
            .invalidHandle,
            .handleVerificationFailed,
            .noPDSFound,
        ]
    )
    func unresolvedHandle(error: IdentityError) {
        let message = IdentityFailure.lookupMessage(for: error, identifier: handle)

        #expect(message == "Avocadough could not find @alice.bsky.social. Check the spelling and try again.")
    }

    @Test("A lookup that fails for lack of a connection points at the connection")
    func offlineLookup() {
        let message = IdentityFailure.lookupMessage(for: URLError(.notConnectedToInternet), identifier: handle)

        #expect(message == "Avocadough could not look up @alice.bsky.social. Check your connection and try again.")
    }

    @Test("Any other failure still names who could not be looked up")
    func otherLookupFailure() {
        struct Unexpected: Error {}
        let message = IdentityFailure.lookupMessage(for: Unexpected(), identifier: handle)

        #expect(message == "Avocadough could not look up @alice.bsky.social. Please try again.")
    }

    // MARK: - Diagnostics

    @Test("A failure the account host did not name is logged as Swift describes it")
    func diagnosticDetailWithoutHostError() {
        #expect(IdentityFailure.diagnosticDetail(for: IdentityError.noPDSFound) == "noPDSFound")
    }

    @Test("A request the account host turned down is logged by name and address, without its credentials")
    func diagnosticDetailLeavesCredentialsOut() throws {
        var request = URLRequest(url: try #require(URL(string: "https://pds.test/xrpc/com.atproto.repo.putRecord")))
        request.httpMethod = "POST"
        request.setValue("DPoP secret-access-token", forHTTPHeaderField: "Authorization")
        request.setValue("secret-proof", forHTTPHeaderField: "DPoP")
        request.httpBody = Data(#"{"record":"secret-body"}"#.utf8)
        let answer = Data(#"{"error":"InvalidToken","message":"secret-detail"}"#.utf8)
        let error = NetworkError.statusCode(StatusCode(rawValue: 401), data: answer, request: request)

        let detail = IdentityFailure.diagnosticDetail(for: error)

        // The log can be shared from Settings, so it must never hold what signs a request.
        #expect(detail.hasPrefix("InvalidToken · "))
        #expect(detail.contains("https://pds.test/xrpc/com.atproto.repo.putRecord"))
        #expect(!detail.contains("secret"))
    }

    // MARK: - Changing the published address

    @Test("A change that never reached the account host points at the connection")
    func offlineChange() {
        let message = IdentityFailure.paymentAddressMessage(for: URLError(.timedOut))

        #expect(message == "Avocadough could not reach your account host. Check your connection and try again.")
    }

    @Test("A change the account host turned down suggests signing in again")
    func rejectedChange() {
        struct Rejected: Error {}
        let message = IdentityFailure.paymentAddressMessage(for: Rejected())

        #expect(message == "Your account host did not accept the change. Try again, or sign out and sign in again.")
    }
}
