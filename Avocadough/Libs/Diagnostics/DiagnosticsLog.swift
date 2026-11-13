//
//  DiagnosticsLog.swift
//  Avocadough
//

import Foundation
import OSLog
import SwiftUI

/// A short, persistent trail of what the app did with a scan, a payment URI, or a
/// payment, so a checkout that "did nothing" can be read back from Settings → Diagnostics
/// and shared straight from the phone.
///
/// Every event is also mirrored to the unified log under the app's bundle identifier, so
/// Console.app or Xcode's device console can follow along live while the phone is plugged
/// in. Summaries are public there; details, which can hold invoices, stay private outside
/// debug builds.
@Observable
@MainActor
final class DiagnosticsLog {
    /// Room for many checkout attempts while keeping the file to a few hundred kilobytes
    /// at most, since one attempt produces a couple of dozen events.
    static let defaultCapacity = 500

    static let shared = DiagnosticsLog(store: DiagnosticsStore(directory: DiagnosticsStore.defaultDirectory))

    /// Oldest first, including what earlier launches recorded.
    private(set) var events: [DiagnosticEvent]

    private let store: DiagnosticsStore
    private let capacity: Int
    private let loggers: [DiagnosticEvent.Category: Logger]

    /// Restores the trail from `store` straight away, so nothing recorded during this
    /// launch can be written back over the history from earlier ones.
    init(store: DiagnosticsStore, capacity: Int = DiagnosticsLog.defaultCapacity) {
        self.store = store
        self.capacity = capacity
        events = Array(store.load().suffix(capacity))

        let subsystem = Bundle.main.bundleIdentifier ?? "com.sparrowtek.avocadough"
        loggers = Dictionary(uniqueKeysWithValues: DiagnosticEvent.Category.allCases.map {
            ($0, Logger(subsystem: subsystem, category: $0.rawValue))
        })
    }

    /// Adds an event, mirrors it to the unified log, and persists the trail.
    func record(_ category: DiagnosticEvent.Category, _ summary: String, detail: String? = nil) {
        let event = DiagnosticEvent(category: category, summary: summary, detail: detail)
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }

        mirror(event)
        persist()
    }

    func clear() {
        events = []
        do {
            try store.clear()
        } catch {
            loggers[.app]?.error("Couldn't clear the diagnostics file: \(String(describing: error), privacy: .public)")
        }
    }

    /// The payload from the most recent camera decode, for pasting into a test or a bug
    /// report. Only decodes carry a detail in the `scan` category.
    var lastScannedPayload: String? {
        events.last { $0.category == .scan && $0.detail != nil }?.detail
    }

    private func mirror(_ event: DiagnosticEvent) {
        guard let logger = loggers[event.category] else { return }
        let detail = event.detail ?? ""
        #if DEBUG
        logger.notice("\(event.summary, privacy: .public) \(detail, privacy: .public)")
        #else
        logger.notice("\(event.summary, privacy: .public) \(detail, privacy: .private)")
        #endif
    }

    private func persist() {
        do {
            try store.save(events)
        } catch {
            loggers[.app]?.error("Couldn't write the diagnostics file: \(String(describing: error), privacy: .public)")
        }
    }
}

// MARK: - Environment Integration

@MainActor
private struct DiagnosticsLogKey: @preconcurrency EnvironmentKey {
    static let defaultValue = DiagnosticsLog.shared
}

extension EnvironmentValues {
    var diagnostics: DiagnosticsLog {
        get { self[DiagnosticsLogKey.self] }
        set { self[DiagnosticsLogKey.self] = newValue }
    }
}
