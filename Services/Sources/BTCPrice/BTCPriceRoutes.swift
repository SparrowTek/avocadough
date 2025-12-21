//
//  BTCPriceRoutes.swift
//  Services
//
//  Created by Thomas Rademaker on 12/6/25.
//

import Compute

enum BlockBTCPriceError: Error {
    case badURL
}

@MainActor
struct BTCPriceRoutes {
    static func register(_ router: Router) {
        router.get("/getBTCPrice", getCurrentPrice)
    }
    
    static func getCurrentPrice(req: IncomingRequest, res: OutgoingResponse) async throws {
        guard let url = URL(string: "https://pricing.bitcoin.block.xyz/current-price") else { throw BlockBTCPriceError.badURL }
        var fetchRequest = FetchRequest(url)
        fetchRequest.cachePolicy = .ttl((60 * 5), staleWhileRevalidate: 30)
        
        let btcPrice: BTCPrice = try await fetch(fetchRequest).decode(decoder: .btcPriceDecoder)
        try await res.status(.ok).send(btcPrice)
    }
}
