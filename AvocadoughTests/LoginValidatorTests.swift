//
//  LoginValidatorTests.swift
//  AvocadoughTests
//

import Testing
@testable import Avocadough

@Suite("LoginValidator")
struct LoginValidatorTests {

    // MARK: - DID

    @Test("Accepts a valid did:plc")
    func acceptsDIDPlc() throws {
        try LoginValidator.validateDID("did:plc:z72i7hdynmk6r22z27h6tvur")
    }

    @Test("Accepts a valid did:web")
    func acceptsDIDWeb() throws {
        try LoginValidator.validateDID("did:web:example.com")
    }

    @Test("Rejects a DID with no method-specific identifier")
    func rejectsEmptyMSID() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validateDID("did:plc:")
        }
    }

    @Test("Rejects an uppercase DID method")
    func rejectsUppercaseMethod() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validateDID("did:PLC:z72i7hdynmk6r22z27h6tvur")
        }
    }

    @Test("Rejects a non-DID string")
    func rejectsNonDID() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validateDID("alice.bsky.social")
        }
    }

    @Test("Rejects a DID longer than the spec maximum")
    func rejectsOverlongDID() {
        let overlong = "did:plc:" + String(repeating: "a", count: 2048)
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validateDID(overlong)
        }
    }

    // MARK: - Handle

    @Test("Accepts a standard Bluesky handle")
    func acceptsBskyHandle() throws {
        try LoginValidator.validateHandle("alice.bsky.social")
    }

    @Test("Accepts a custom-domain handle")
    func acceptsCustomDomainHandle() throws {
        try LoginValidator.validateHandle("thomas.sparrowtek.com")
    }

    @Test("Rejects a single-label handle")
    func rejectsSingleLabel() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validateHandle("alice")
        }
    }

    @Test("Rejects a handle with an empty segment")
    func rejectsEmptySegment() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validateHandle("alice..social")
        }
    }

    @Test("Rejects a handle segment starting with a hyphen")
    func rejectsLeadingHyphen() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validateHandle("-alice.bsky.social")
        }
    }

    @Test("Rejects an all-numeric top-level segment")
    func rejectsNumericTLD() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validateHandle("alice.123")
        }
    }

    // MARK: - PDS Endpoint

    @Test("Accepts an https PDS endpoint")
    func acceptsHTTPSEndpoint() throws {
        try LoginValidator.validatePDSEndpoint("https://bsky.social")
    }

    @Test("Rejects an http PDS endpoint")
    func rejectsHTTPEndpoint() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validatePDSEndpoint("http://bsky.social")
        }
    }

    @Test("Rejects an https URL with no host")
    func rejectsHostlessEndpoint() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validatePDSEndpoint("https://")
        }
    }

    @Test("Rejects a non-URL string")
    func rejectsNonURL() {
        #expect(throws: LoginValidationError.self) {
            try LoginValidator.validatePDSEndpoint("not a url")
        }
    }
}
