//
//  DiagnosticsReport.swift
//  Avocadough
//

import Foundation

/// The shareable, plain-text form of the diagnostics log: build and device context on
/// top, then every event oldest first with its detail indented beneath it.
struct DiagnosticsReport {
    struct Context: Sendable {
        let appVersion: String
        let build: String
        let environment: String
        let deviceModel: String
        let systemVersion: String
    }

    let context: Context
    let events: [DiagnosticEvent]
    let exportedAt: Date

    init(context: Context, events: [DiagnosticEvent], exportedAt: Date = .now) {
        self.context = context
        self.events = events
        self.exportedAt = exportedAt
    }

    var text: String {
        var lines = [
            "Avocadough diagnostics",
            "Version \(context.appVersion) (\(context.build)) · \(context.environment)",
            "\(context.deviceModel) · iOS \(context.systemVersion)",
            "Exported \(exportedAt.formatted(Self.exportedAtStyle))",
            "\(events.count) events, oldest first",
            "",
        ]

        for event in events {
            lines.append("\(event.date.formatted(Self.eventTimeStyle))  [\(event.category.rawValue)]  \(event.summary)")
            if let detail = event.detail {
                let detailLines = detail.split(separator: "\n", omittingEmptySubsequences: false)
                lines.append(contentsOf: detailLines.map { "    \($0)" })
            }
        }

        return lines.joined(separator: "\n")
    }

    private static var exportedAtStyle: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .standard)
    }

    private static var eventTimeStyle: Date.FormatStyle {
        Date.FormatStyle(date: .numeric, time: .standard).secondFraction(.fractional(3))
    }
}
