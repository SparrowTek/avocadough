//
//  LoginValidator.swift
//  Avocadough
//

import Foundation

enum LoginValidationError: LocalizedError, Equatable {
    case invalidDID(String)
    case invalidHandle(String)
    case invalidPDSEndpoint(String)

    var errorDescription: String? {
        switch self {
        case .invalidDID(let value):
            String(localized: "The server returned an invalid account identifier: \(value)")
        case .invalidHandle(let value):
            String(localized: "The server returned an invalid handle: \(value)")
        case .invalidPDSEndpoint(let value):
            String(localized: "The server returned an invalid PDS endpoint: \(value)")
        }
    }
}

/// Pure syntactic validators for AT Protocol login response fields.
///
/// These exist to reject malformed values from a compromised or buggy server
/// before they get persisted to the keychain or used to configure the
/// CoreATProtocol session. They do not do network resolution.
enum LoginValidator {

    /// AT Protocol DID grammar: `did:<method>:<msid>`. Source:
    /// https://atproto.com/specs/did
    private static let didPattern = #"^did:[a-z]+:[a-zA-Z0-9._:%-]*[a-zA-Z0-9._]$"#
    private static let didMaxLength = 2048

    /// AT Protocol handle grammar: hostname-like, ≥ 2 segments, last segment
    /// must start with a letter. Source:
    /// https://atproto.com/specs/handle
    private static let handlePattern = #"^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"#
    private static let handleMaxLength = 253

    static func validateDID(_ did: String) throws(LoginValidationError) {
        guard did.count <= didMaxLength,
              did.range(of: didPattern, options: .regularExpression) != nil
        else {
            throw .invalidDID(did)
        }
    }

    static func validateHandle(_ handle: String) throws(LoginValidationError) {
        guard handle.count <= handleMaxLength,
              handle.range(of: handlePattern, options: .regularExpression) != nil
        else {
            throw .invalidHandle(handle)
        }
    }

    /// PDS endpoint must be a syntactically valid HTTPS URL with a host. HTTP
    /// is rejected to prevent downgrade attacks against tokens in transit.
    static func validatePDSEndpoint(_ endpoint: String) throws(LoginValidationError) {
        guard let url = URL(string: endpoint),
              url.scheme?.lowercased() == "https",
              let host = url.host(),
              !host.isEmpty
        else {
            throw .invalidPDSEndpoint(endpoint)
        }
    }
}
