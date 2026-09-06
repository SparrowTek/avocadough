//
//  SendStateInputTests.swift
//  AvocadoughTests
//

import Testing
@testable import Avocadough

@MainActor
struct SendStateInputTests {
    /// Valid under LDK, but issued in 2024 and long expired.
    private let expiredInvoice = "lnbc20u1pn2hnhmpp5hf964hhc77lf4vjpltdnuma0fdl2pp2afagzueg8h2gv8x2ju5tqdpzw3jhxarfdenjqnzyfvsxjm3qgfhk7um50gcqzzsxqyz5vqsp5a8ayrhgzyhgce6y49m9z5ypvngslkkajjfz8dx3qeg94gtl6dg9q9qxpqysgq53s3ddmvy0x2lq3jm06lh9eul0w8mtmgpct09g68uuketgw2xvsyfwmm6qjj9t7hrtu8ul859c93ggaz69quj9ltpszt4022cca6znsq9v2lmp"

    private func makeState() -> SendState {
        SendState(parentState: WalletState(parentState: AppState()))
    }

    @Test("A wrapped invoice reaches LDK instead of the address flow")
    func wrappedInvoiceIsRecognised() {
        let state = makeState()
        state.continueWithInput("LIGHTNING:" + expiredInvoice.uppercased())

        // LDK parsed it (an address would have been pushed blindly); it was then
        // rejected for being expired rather than misrouted.
        #expect(state.path.isEmpty)
        #expect(state.errorMessage == "That Lightning invoice has expired. Ask for a new one and try again.")
    }

    @Test("A malformed invoice is reported instead of treated as an address")
    func malformedInvoice() {
        let state = makeState()
        state.continueWithInput("lnbc1notaninvoice")

        #expect(state.path.isEmpty)
        #expect(state.errorMessage == "That Lightning invoice couldn't be read. Ask for a new one and try again.")
    }

    @Test("An on-chain-only URI is rejected")
    func onChainOnly() {
        let state = makeState()
        state.continueWithInput("bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq?amount=0.001")

        #expect(state.path.isEmpty)
        #expect(state.errorMessage != nil)
    }

    @Test("Empty input is rejected")
    func emptyInput() {
        let state = makeState()
        state.continueWithInput("   ")

        #expect(state.path.isEmpty)
        #expect(state.errorMessage != nil)
    }

    @Test("A Lightning address goes to the invoice lookup flow")
    func lightningAddress() {
        let state = makeState()
        state.continueWithInput("lightning:alice@getalby.com")

        #expect(state.path == [.getLightningAddressDetails("alice@getalby.com")])
        #expect(state.errorMessage == nil)
    }

    @Test("A scanned recipient replaces the scanner on the stack")
    func scannedRecipientReplacesScanner() {
        let state = makeState()
        state.path = [.scanQR]
        state.foundQRCode("alice@getalby.com")

        #expect(state.path == [.getLightningAddressDetails("alice@getalby.com")])
    }

    @Test("A failed scan pops the scanner so the error is visible")
    func failedScanPopsScanner() {
        let state = makeState()
        state.path = [.scanQR]
        state.foundQRCode("bitcoin:bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq")

        #expect(state.path.isEmpty)
        #expect(state.errorMessage != nil)
    }

    @Test("Starting from a URI resets any earlier navigation")
    func startResetsPath() {
        let state = makeState()
        state.path = [.getLightningAddressDetails("bob@getalby.com")]
        state.start(with: "lightning:alice@getalby.com")

        #expect(state.path == [.getLightningAddressDetails("alice@getalby.com")])
    }
}
