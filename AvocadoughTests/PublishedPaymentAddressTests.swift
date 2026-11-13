//
//  PublishedPaymentAddressTests.swift
//  AvocadoughTests
//

import Testing
@testable import Avocadough

@Suite("Published payment address")
struct PublishedPaymentAddressTests {
    private let wallet = "thomas@getalby.com"

    // MARK: - Actions

    @Test("Nothing is on offer until the record has been looked up")
    func noActionsWhileUnknown() {
        #expect(PublishedPaymentAddress.unknown.actions(walletAddress: wallet, canPublish: true).isEmpty)
        #expect(PublishedPaymentAddress.loading.actions(walletAddress: wallet, canPublish: true).isEmpty)
    }

    @Test("An unpublished handle can publish the wallet's address")
    func publishWhenNothingIsPublished() {
        let actions = PublishedPaymentAddress.notPublished.actions(walletAddress: wallet, canPublish: true)
        #expect(actions == [.publish(wallet)])
    }

    @Test("A wallet without a Lightning address has nothing to publish")
    func nothingToPublish() {
        #expect(PublishedPaymentAddress.notPublished.actions(walletAddress: nil, canPublish: true).isEmpty)
    }

    @Test("A handle that points at the wallet can only be unpublished")
    func unpublishWhenUpToDate() {
        let actions = PublishedPaymentAddress.published(wallet).actions(walletAddress: wallet, canPublish: true)
        #expect(actions == [.unpublish])
    }

    @Test("A handle that points somewhere else can be updated or unpublished")
    func updateWhenStale() {
        let actions = PublishedPaymentAddress.published("old@example.com").actions(walletAddress: wallet, canPublish: true)
        #expect(actions == [.update(to: wallet), .unpublish])
    }

    @Test("A published address can be taken down even when the wallet has none of its own")
    func unpublishWithoutWalletAddress() {
        let actions = PublishedPaymentAddress.published("old@example.com").actions(walletAddress: nil, canPublish: true)
        #expect(actions == [.unpublish])
    }

    @Test("A record that could not be read offers another try, never a blind overwrite")
    func retryWhenUnavailable() {
        #expect(PublishedPaymentAddress.unavailable.actions(walletAddress: wallet, canPublish: true) == [.retry])
        #expect(PublishedPaymentAddress.unavailable.actions(walletAddress: nil, canPublish: false) == [.retry])
    }

    @Test("A session without permission to write the record offers no changes")
    func noChangesWithoutPermission() {
        #expect(PublishedPaymentAddress.notPublished.actions(walletAddress: wallet, canPublish: false).isEmpty)
        #expect(PublishedPaymentAddress.published(wallet).actions(walletAddress: wallet, canPublish: false).isEmpty)
        #expect(PublishedPaymentAddress.published("old@example.com").actions(walletAddress: wallet, canPublish: false).isEmpty)
    }

    // MARK: - Matching the wallet

    @Test("Lightning addresses are compared without regard to case")
    func caseInsensitiveMatch() {
        let published = PublishedPaymentAddress.published("Thomas@GetAlby.com")

        #expect(published.matches(walletAddress: wallet))
        #expect(published.actions(walletAddress: wallet, canPublish: true) == [.unpublish])
    }

    @Test("Only a published address can match the wallet")
    func onlyPublishedMatches() {
        #expect(!PublishedPaymentAddress.notPublished.matches(walletAddress: wallet))
        #expect(!PublishedPaymentAddress.unavailable.matches(walletAddress: wallet))
        #expect(!PublishedPaymentAddress.published(wallet).matches(walletAddress: nil))
        #expect(!PublishedPaymentAddress.published("old@example.com").matches(walletAddress: wallet))
    }
}

@Suite("Sign-in identifier")
struct SignInIdentifierTests {

    @Test(
        "Handles are trimmed, stripped of a leading @ and lower-cased",
        arguments: [
            ("alice.bsky.social", "alice.bsky.social"),
            ("@alice.bsky.social", "alice.bsky.social"),
            ("  @Alice.Bsky.Social\n", "alice.bsky.social"),
            ("THOMAS.SPARROWTEK.COM", "thomas.sparrowtek.com"),
        ]
    )
    func handles(input: String, expected: String) {
        #expect(SignInIdentifier.normalized(input) == expected)
    }

    @Test("A DID is kept exactly as typed")
    func didIsKept() {
        #expect(SignInIdentifier.normalized(" did:plc:ewvi7nxzyoun6zhxrhs64oiz ") == "did:plc:ewvi7nxzyoun6zhxrhs64oiz")
        #expect(SignInIdentifier.normalized("did:web:Example.com") == "did:web:Example.com")
    }

    @Test("Nothing typed is nothing to sign in with", arguments: ["", "   ", "@", " @ \n"])
    func empty(input: String) {
        #expect(SignInIdentifier.normalized(input) == nil)
    }
}
