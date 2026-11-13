//
//  DiagnosticEvent.swift
//  Avocadough
//

import Foundation

/// One step of a scan or payment attempt, kept so a checkout that went nowhere can be
/// explained after the fact.
struct DiagnosticEvent: Codable, Identifiable, Hashable, Sendable {
    enum Category: String, Codable, CaseIterable, Sendable {
        /// The camera and QR scanner.
        case scan
        /// Classifying and routing typed, pasted, scanned, or handed-over input.
        case send
        /// Talking to the wallet: connecting, paying, looking payments up.
        case wallet
        /// `lightning:` and `bitcoin:` URLs another app handed over.
        case url
        /// Launch and other lifecycle context.
        case app
    }

    let id: UUID
    let date: Date
    let category: Category
    /// What happened, in one line. Never carries payment data, so it can be shown anywhere.
    let summary: String
    /// The material behind the summary: a scanned payload, a decoded invoice, an error.
    /// May contain invoices, amounts, and payment hashes.
    let detail: String?

    init(category: Category, summary: String, detail: String? = nil, date: Date = .now, id: UUID = UUID()) {
        self.id = id
        self.date = date
        self.category = category
        self.summary = summary
        self.detail = detail
    }
}
