//
//  LightningInputTests.swift
//  AvocadoughTests
//

import Testing
@testable import Avocadough

struct LightningInputTests {
    /// A structurally valid mainnet invoice. Its signature checks out under LDK, which is
    /// irrelevant here — `LightningInput` only looks at the wrapping and the prefix.
    private let invoice = "lnbc20u1pn2hnhmpp5hf964hhc77lf4vjpltdnuma0fdl2pp2afagzueg8h2gv8x2ju5tqdpzw3jhxarfdenjqnzyfvsxjm3qgfhk7um50gcqzzsxqyz5vqsp5a8ayrhgzyhgce6y49m9z5ypvngslkkajjfz8dx3qeg94gtl6dg9q9qxpqysgq53s3ddmvy0x2lq3jm06lh9eul0w8mtmgpct09g68uuketgw2xvsyfwmm6qjj9t7hrtu8ul859c93ggaz69quj9ltpszt4022cca6znsq9v2lmp"

    // MARK: - Bare invoices

    @Test("A bare invoice passes through unchanged")
    func bareInvoice() {
        #expect(LightningInput(invoice) == .bolt11(invoice))
    }

    @Test("An upper-cased invoice is lower-cased")
    func upperCasedInvoice() {
        #expect(LightningInput(invoice.uppercased()) == .bolt11(invoice))
    }

    @Test("Non-mainnet invoices are still invoices", arguments: ["lntb", "lntbs", "lnbcrt"])
    func otherNetworks(prefix: String) {
        let testInvoice = prefix + "20u1" + String(repeating: "q", count: 100)
        #expect(LightningInput(testInvoice.uppercased()) == .bolt11(testInvoice))
    }

    // MARK: - URI wrapping

    @Test("A lightning: scheme is stripped regardless of case", arguments: ["lightning:", "LIGHTNING:", "Lightning:", "lightning://"])
    func lightningScheme(prefix: String) {
        #expect(LightningInput(prefix + invoice.uppercased()) == .bolt11(invoice))
    }

    @Test("A BIP 21 URI yields its lightning query item")
    func bip21WithLightning() {
        let withAddress = "bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.00002&lightning=\(invoice)&label=Square%20Coffee"
        #expect(LightningInput(withAddress) == .bolt11(invoice))

        let lightningOnly = "bitcoin:?lightning=\(invoice)"
        #expect(LightningInput(lightningOnly) == .bolt11(invoice))

        let upperCased = "BITCOIN:?LIGHTNING=\(invoice.uppercased())"
        #expect(LightningInput(upperCased) == .bolt11(invoice))
    }

    @Test("A percent-encoded lightning item is decoded")
    func bip21PercentEncoded() {
        #expect(LightningInput("bitcoin:?lightning=lightning%3A\(invoice)") == .bolt11(invoice))
    }

    @Test("A BIP 21 URI without a lightning item is on-chain only")
    func bip21OnChainOnly() {
        let address = "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq"
        #expect(LightningInput("bitcoin:\(address)?amount=0.001") == .onChainOnly(address))
        #expect(LightningInput("bitcoin:\(address)") == .onChainOnly(address))
        #expect(LightningInput("BITCOIN://\(address)") == .onChainOnly(address))
    }

    @Test("A BIP 21 lightning item that isn't an invoice is treated as a recipient")
    func bip21WithLNURL() {
        #expect(LightningInput("bitcoin:?lightning=LNURL1DP68GURN8GHJ7MRWW4EXCTNXD9SHG6NPVCHXXMMD9AKXUATJDSKHQCTE") == .recipient("LNURL1DP68GURN8GHJ7MRWW4EXCTNXD9SHG6NPVCHXXMMD9AKXUATJDSKHQCTE"))
    }

    // MARK: - Recipients

    @Test("Lightning addresses and LNURLs pass through as recipients", arguments: [
        "alice@getalby.com",
        "lightning:alice@getalby.com",
        "LNURL1DP68GURN8GHJ7MRWW4EXCTNXD9SHG6NPVCHXXMMD9AKXUATJDSKHQCTE",
        "lnbc@example.com",
    ])
    func recipients(input: String) {
        let expected = input.hasPrefix("lightning:") ? String(input.dropFirst("lightning:".count)) : input
        #expect(LightningInput(input) == .recipient(expected))
    }

    // MARK: - Whitespace and empties

    @Test("Surrounding whitespace is trimmed")
    func whitespace() {
        #expect(LightningInput("  \(invoice)\n") == .bolt11(invoice))
        #expect(LightningInput("\tlightning: \(invoice) ") == .bolt11(invoice))
        #expect(LightningInput(" alice@getalby.com ") == .recipient("alice@getalby.com"))
    }

    @Test("Nothing payable yields nil", arguments: ["", "   ", "\n", "lightning:", "lightning://", "bitcoin:", "bitcoin:?lightning=", "bitcoin:?amount=1"])
    func empties(input: String) {
        #expect(LightningInput(input) == nil)
    }
}
