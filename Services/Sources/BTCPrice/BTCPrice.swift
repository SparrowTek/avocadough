//
//  BTCPrice.swift
//  Services
//
//  Created by Thomas Rademaker on 12/6/25.
//

struct BTCPrice: Codable, Sendable {
    let amount: String
    let lastUpdatedAtInUtcEpochSeconds: String
    let currency: String
    let version: String
    let base: String
}
