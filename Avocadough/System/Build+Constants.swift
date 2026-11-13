//
//  Build+Constants.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/10/23.
//

import Foundation
import AvocadoughKit

extension Build {
    struct Constants {
        struct UserDefault {
            static let colorScheme = "com.sparrowtek.avocadough.userDefaults.colorScheme"
            static let lightThemeColor = "com.sparrowtek.avocadough.userDefaults.lightThemeColor"
            static let darkThemeColor = "com.sparrowtek.avocadough.userDefaults.darkThemeColor"
        }
        
        struct Theme {
            static let light = "com.sparrowtek.avocadough.theme.light"
            static let dark = "com.sparrowtek.avocadough.theme.dark"
        }

        /// AT Protocol sign-in. The client metadata is hosted on avocadough.xyz and has to
        /// agree with these values; `ATProtoConfigurationTests` compares the two.
        struct ATProto {
            static let clientMetadataURL = "https://avocadough.xyz/oauth/client-metadata.json"
            static let redirectURI = "https://avocadough.xyz/oauth/callback"

            /// Avocadough's path on the shared SparrowTek auth service, which signs token
            /// requests with Avocadough's client key. No trailing slash: CoreATProtocol
            /// appends `/oauth/par` and `/oauth/token`.
            static let authProxyBaseURL = "https://auth.sparrowtek.com/avocadough"

            /// The one collection Avocadough writes in the signed-in user's repository.
            static let paymentEndpointCollection = PaymentEndpointRecord.collection

            /// The OAuth scopes requested at sign-in: the identity scope every AT Protocol
            /// client needs, plus permission to write the payment endpoint record and
            /// nothing else in the account.
            static let scopes = ["atproto", "repo:\(paymentEndpointCollection)"]
        }
    }
}
