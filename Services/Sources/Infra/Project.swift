//
//  Project.swift
//  Services
//
//  Created by Thomas Rademaker on 12/6/25.
//

import Cloud

@main
struct LightningAddressDetailsProxy: AWSProject {
    func build() async throws -> Outputs {
        
        let lambda = AWS.Function(
            "lightning-address-details",
            targetName: "API",
            url: .enabled(cors: true),
        )
        
        let cdn = AWS.CDN(
            "lightning-address-details-cdn",
            origins: .function(lambda),
            domainName: .init(
                hostname: "lightning-address-details-proxy.avocadough.xyz",
                dns: .cloudflare(zoneName: "avocadough.xyz")
            )
        )
        
        return [
            "lightning-address-details-proxy-function-name": lambda.name,
            "Function-URL": lambda.url,
            "Public-URL": cdn.url,
        ]
    }
}
