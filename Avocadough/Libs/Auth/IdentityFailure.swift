//
//  IdentityFailure.swift
//  Avocadough
//

import Foundation
import AvocadoughKit
import CoreATProtocol

/// What the app says when something about an AT Protocol identity fails.
///
/// The errors behind these messages come from three packages, and most of them describe
/// themselves as "The operation couldn't be completed. (IdentityError error 2.)", which
/// tells a person nothing they can act on.
enum IdentityFailure {

    /// The message for a failed lookup of the payment address behind `identifier`, a
    /// handle formatted for display or a DID.
    static func lookupMessage(for error: any Error, identifier: String) -> String {
        switch error {
        case let error as PaymentResolutionError:
            switch error {
            case .noPaymentEndpoint:
                String(localized: "\(identifier) has not set up a payment address yet.")
            case .noUsablePaymentMethods:
                noLightningAddressMessage(identifier: identifier)
            case .unrecognizedInput:
                String(localized: "\(identifier) is not a handle Avocadough can look up.")
            }
        case is IdentityError:
            String(localized: "Avocadough could not find \(identifier). Check the spelling and try again.")
        case is URLError:
            String(localized: "Avocadough could not look up \(identifier). Check your connection and try again.")
        default:
            String(localized: "Avocadough could not look up \(identifier). Please try again.")
        }
    }

    /// The message for an identity that publishes payment methods, none of which is a
    /// Lightning address, the one kind this wallet can pay.
    static func noLightningAddressMessage(identifier: String) -> String {
        String(localized: "\(identifier) has no Lightning address Avocadough can pay yet.")
    }

    /// The message for a failed read of, or change to, the payment address published at
    /// the signed-in handle.
    static func paymentAddressMessage(for error: any Error) -> String {
        if error is URLError {
            String(localized: "Avocadough could not reach your account host. Check your connection and try again.")
        } else {
            String(localized: "Your account host did not accept the change. Try again, or sign out and sign in again.")
        }
    }

    /// What the diagnostics log keeps of a failure: the error as Swift describes it, led
    /// by the name the account host gave it when it answered with one, such as
    /// `InvalidToken`. Neither carries tokens: a failed request is described by its URL
    /// and the size of the answer, not by its headers or body.
    static func diagnosticDetail(for error: any Error) -> String {
        [error.atProtoErrorName, String(describing: error)]
            .compactMap(\.self)
            .joined(separator: " · ")
    }
}
