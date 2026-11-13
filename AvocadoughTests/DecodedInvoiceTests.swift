//
//  DecodedInvoiceTests.swift
//  AvocadoughTests
//

import Testing
@testable import Avocadough

struct DecodedInvoiceTests {
    /// A real mainnet invoice for 2,000 sats, issued 2024-08-01 with a one-day expiry.
    private let invoice = "lnbc20u1pn2hnhmpp5hf964hhc77lf4vjpltdnuma0fdl2pp2afagzueg8h2gv8x2ju5tqdpzw3jhxarfdenjqnzyfvsxjm3qgfhk7um50gcqzzsxqyz5vqsp5a8ayrhgzyhgce6y49m9z5ypvngslkkajjfz8dx3qeg94gtl6dg9q9qxpqysgq53s3ddmvy0x2lq3jm06lh9eul0w8mtmgpct09g68uuketgw2xvsyfwmm6qjj9t7hrtu8ul859c93ggaz69quj9ltpszt4022cca6znsq9v2lmp"

    @Test("Decodes the fields the send flow needs")
    func decodesFields() throws {
        let decoded = try #require(DecodedInvoice(invoice))

        #expect(decoded.bolt11 == invoice)
        #expect(decoded.amountSats == 2_000)
        #expect(decoded.paymentHash == "ba4baadef8f7be9ab241fadb3e6faf4b7ea0855d4f502e6507ba90c39952e516")
        #expect(decoded.payeeLabel == "030a58b8…722677a3")
        #expect(decoded.isExpired)
    }

    @Test("An upper-cased invoice re-serializes lower case")
    func upperCasedInput() throws {
        let decoded = try #require(DecodedInvoice(invoice.uppercased()))
        #expect(decoded.bolt11 == invoice)
    }

    @Test("Wrapped or malformed strings are rejected", arguments: [
        "lightning:lnbc20u1pn2hnhmpp5hf964hhc77lf4vjpltdnuma0fdl2pp2afagzueg8h2gv8x2ju5tq",
        "lnbc1notaninvoice",
        "alice@getalby.com",
        "",
    ])
    func rejectsGarbage(input: String) {
        #expect(DecodedInvoice(input) == nil)
    }
}
