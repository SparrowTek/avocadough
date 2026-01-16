//
//  BTCPrice.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 4/11/25.
//

struct BTCPrice: Codable, Sendable {
    let amount: String
    let lastUpdatedAtInUtcEpochSeconds: String
    let currency: String
    let version: String
    let base: String

    var priceAsDouble: Double? {
        Double(amount)
    }
}
