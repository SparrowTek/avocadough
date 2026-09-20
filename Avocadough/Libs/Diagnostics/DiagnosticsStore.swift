//
//  DiagnosticsStore.swift
//  Avocadough
//

import Foundation

/// The on-disk copy of the diagnostics log: one JSON object per line, rewritten
/// atomically so an interrupted write can't damage earlier entries.
///
/// The file stays small by construction (see `DiagnosticsLog.defaultCapacity`), so
/// reading and writing it synchronously on the main actor costs well under a frame.
struct DiagnosticsStore: Sendable {
    let fileURL: URL

    init(directory: URL) {
        fileURL = directory.appending(path: "diagnostics.jsonl")
    }

    /// Where the app keeps its log between launches.
    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Diagnostics")
    }

    /// Every event on disk, oldest first. A line that fails to decode is skipped rather
    /// than costing the whole log.
    func load() -> [DiagnosticEvent] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        return data
            .split(separator: UInt8(ascii: "\n"))
            .compactMap { try? decoder.decode(DiagnosticEvent.self, from: $0) }
    }

    /// Replaces the file with `events`.
    func save(_ events: [DiagnosticEvent]) throws {
        let encoder = JSONEncoder()
        var lines = Data()
        for event in events {
            let line = try encoder.encode(event)
            lines.append(line)
            lines.append(UInt8(ascii: "\n"))
        }

        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try lines.write(to: fileURL, options: .atomic)
    }

    /// Removes the file. A file that was never written is already clear.
    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
