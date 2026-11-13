//
//  DiagnosticsLogTests.swift
//  AvocadoughTests
//

import Testing
import Foundation
@testable import Avocadough

@MainActor
struct DiagnosticsLogTests {
    private func makeStore() -> DiagnosticsStore {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "DiagnosticsLogTests-\(UUID().uuidString)")
        return DiagnosticsStore(directory: directory)
    }

    @Test("Events are kept oldest first")
    func recordsInOrder() {
        let log = DiagnosticsLog(store: makeStore())
        log.record(.scan, "first")
        log.record(.send, "second", detail: "payload")

        #expect(log.events.map(\.summary) == ["first", "second"])
        #expect(log.events.last?.category == .send)
        #expect(log.events.last?.detail == "payload")
    }

    @Test("The oldest events fall off once the capacity is reached")
    func trimsToCapacity() {
        let log = DiagnosticsLog(store: makeStore(), capacity: 3)
        for index in 1...5 {
            log.record(.app, "\(index)")
        }

        #expect(log.events.map(\.summary) == ["3", "4", "5"])
    }

    @Test("Recorded events survive a relaunch")
    func persistsAcrossInstances() {
        let store = makeStore()
        let first = DiagnosticsLog(store: store)
        first.record(.scan, "decoded", detail: "lnbc1...")
        first.record(.send, "rejected")

        let second = DiagnosticsLog(store: store)

        #expect(second.events.map(\.id) == first.events.map(\.id))
        #expect(second.events.map(\.summary) == ["decoded", "rejected"])
        #expect(second.events.first?.detail == "lnbc1...")
    }

    @Test("A later launch appends to the earlier launch's trail instead of replacing it")
    func laterLaunchAppends() {
        let store = makeStore()
        let earlier = DiagnosticsLog(store: store)
        earlier.record(.app, "earlier launch")

        let later = DiagnosticsLog(store: store)
        later.record(.url, "opened on the later launch")

        #expect(later.events.map(\.summary) == ["earlier launch", "opened on the later launch"])
        #expect(store.load().map(\.summary) == ["earlier launch", "opened on the later launch"])
    }

    @Test("Restoring respects the capacity")
    func restoreTrimsToCapacity() {
        let store = makeStore()
        let earlier = DiagnosticsLog(store: store)
        for index in 1...4 {
            earlier.record(.app, "\(index)")
        }

        let later = DiagnosticsLog(store: store, capacity: 2)

        #expect(later.events.map(\.summary) == ["3", "4"])
    }

    @Test("Clearing empties memory and disk")
    func clearRemovesEverything() {
        let store = makeStore()
        let log = DiagnosticsLog(store: store)
        log.record(.scan, "decoded")
        log.clear()

        #expect(log.events.isEmpty)
        #expect(store.load().isEmpty)
    }

    @Test("A damaged line doesn't take the rest of the log with it")
    func skipsCorruptLines() throws {
        let store = makeStore()
        let log = DiagnosticsLog(store: store)
        log.record(.scan, "kept")

        var data = try Data(contentsOf: store.fileURL)
        data.append(contentsOf: Array("not json\n".utf8))
        try data.write(to: store.fileURL)

        #expect(store.load().map(\.summary) == ["kept"])
    }

    @Test("The last scanned payload is the newest camera decode that carried one")
    func lastScannedPayload() {
        let log = DiagnosticsLog(store: makeStore())
        #expect(log.lastScannedPayload == nil)

        log.record(.scan, "decoded", detail: "first")
        log.record(.scan, "repeat ignored")
        log.record(.send, "classified", detail: "not a scan")

        #expect(log.lastScannedPayload == "first")
    }

    @Test("Events round-trip through JSON")
    func eventRoundTrip() throws {
        let event = DiagnosticEvent(category: .wallet, summary: "paid", detail: "fees 12 msat")
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(DiagnosticEvent.self, from: data)

        #expect(decoded.id == event.id)
        #expect(decoded.category == .wallet)
        #expect(decoded.summary == "paid")
        #expect(decoded.detail == "fees 12 msat")
        #expect(abs(decoded.date.timeIntervalSince(event.date)) < 0.001)
    }

    @Test("The report lists the context and every event with its detail")
    func reportText() {
        let context = DiagnosticsReport.Context(
            appVersion: "1.4",
            build: "7",
            environment: "DEVELOPMENT",
            deviceModel: "iPhone17,3",
            systemVersion: "26.0"
        )
        let events = [
            DiagnosticEvent(category: .scan, summary: "Camera decoded a QR code", detail: "lightning:LNBC1"),
            DiagnosticEvent(category: .send, summary: "Rejected input: expired invoice"),
        ]

        let text = DiagnosticsReport(context: context, events: events).text

        #expect(text.contains("Version 1.4 (7) · DEVELOPMENT"))
        #expect(text.contains("iPhone17,3 · iOS 26.0"))
        #expect(text.contains("2 events, oldest first"))
        #expect(text.contains("[scan]  Camera decoded a QR code"))
        #expect(text.contains("\n    lightning:LNBC1"))
        #expect(text.contains("[send]  Rejected input: expired invoice"))
    }
}
