//
//  AuthorizationCallback.swift
//  Avocadough
//

import Foundation

/// Why an interactive sign-in stopped before there was a session.
enum AuthError: LocalizedError, Equatable {
    /// The user closed the sign-in page.
    case cancelled
    /// The user said no on the account host's page.
    case accessDenied
    /// The account host sent the user back with an error of its own.
    case rejectedByHost(String)
    /// The sign-in page could not be shown.
    case presentationFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            String(localized: "Sign-in was cancelled")
        case .accessDenied:
            String(localized: "You declined access")
        case .rejectedByHost(let reason):
            String(localized: "Your account host did not complete the sign-in: \(reason)")
        case .presentationFailed:
            String(localized: "Avocadough could not open the sign-in page. Please try again.")
        }
    }
}

/// Reads the answer an authorization server puts on the redirect back to the app.
enum AuthorizationCallback {

    /// The failure `url` reports, or `nil` when it does not carry one.
    ///
    /// An authorization server that will not issue a code redirects with an
    /// `error` parameter instead (RFC 6749 §4.1.2.1). `access_denied` is the
    /// user declining; anything else is the server's own problem, described
    /// by `error_description` when the server sends one.
    static func failure(in url: URL) -> AuthError? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        func value(of name: String) -> String? {
            guard let value = items.first(where: { $0.name == name })?.value, !value.isEmpty else { return nil }
            // Query strings may spell a space as "+", which URLComponents leaves alone.
            return value.replacing("+", with: " ")
        }

        guard let code = value(of: "error") else { return nil }
        guard code != "access_denied" else { return .accessDenied }
        return .rejectedByHost(value(of: "error_description") ?? code)
    }
}
