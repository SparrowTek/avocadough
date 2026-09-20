//
//  DiagnosticsView.swift
//  Avocadough
//

import SwiftUI
import UIKit

/// Settings → Diagnostics: the trail of recent scans, hand-offs, and payments, with a way
/// to share it from the phone.
struct DiagnosticsView: View {
    @Environment(\.diagnostics) private var diagnostics
    @State private var reportURL: URL?
    @State private var presentClearConfirmation = false

    var body: some View {
        List {
            if diagnostics.events.isEmpty {
                ContentUnavailableView(
                    "No diagnostics yet",
                    systemImage: "waveform.path.ecg",
                    description: Text("Scan a QR code or open a lightning: link and every step shows up here.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(diagnostics.events.reversed()) { event in
                        DiagnosticEventRow(event: event)
                    }
                } footer: {
                    Text("Newest first. The shared report includes scanned payloads and invoice text.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .fullScreenColorView()
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let reportURL {
                    ShareLink(item: reportURL, subject: Text("Avocadough diagnostics"))
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Copy last scan", systemImage: "doc.on.doc", action: copyLastScan)
                        .disabled(diagnostics.lastScannedPayload == nil)
                    Button("Clear log", systemImage: "trash", role: .destructive, action: confirmClear)
                        .disabled(diagnostics.events.isEmpty)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Clear the diagnostics log?", isPresented: $presentClearConfirmation, titleVisibility: .visible) {
            Button("Clear", role: .destructive, action: clear)
            Button("Cancel", role: .cancel) {}
        }
        .onAppear(perform: writeReport)
        .onChange(of: diagnostics.events.count, writeReport)
    }

    private func copyLastScan() {
        UIPasteboard.general.string = diagnostics.lastScannedPayload
    }

    private func confirmClear() {
        presentClearConfirmation = true
    }

    private func clear() {
        diagnostics.clear()
    }

    /// Writes the report to a temporary file so the share sheet hands over a text
    /// document, which AirDrop and Mail keep intact where a bare string would not.
    private func writeReport() {
        let report = DiagnosticsReport(context: .current, events: diagnostics.events)
        let url = FileManager.default.temporaryDirectory.appending(path: "avocadough-diagnostics.txt")

        do {
            try report.text.write(to: url, atomically: true, encoding: .utf8)
            reportURL = url
        } catch {
            reportURL = nil
        }
    }
}

// MARK: - Row

private struct DiagnosticEventRow: View {
    let event: DiagnosticEvent

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(event.category.rawValue)
                    .font(DesignTokens.Typography.caption2)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(event.category.tint.opacity(0.15))
                    .foregroundStyle(event.category.tint)
                    .clipShape(Capsule())

                Text(event.date, format: .dateTime.hour().minute().second())
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(Color.ds.textTertiary)
            }

            Text(event.summary)
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(Color.ds.textPrimary)

            if let detail = event.detail {
                Text(detail)
                    .font(DesignTokens.Typography.monospaceSmall)
                    .foregroundStyle(Color.ds.textSecondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
}

private extension DiagnosticEvent.Category {
    var tint: Color {
        switch self {
        case .scan: DesignTokens.Colors.Accent.info
        case .send: DesignTokens.Colors.Accent.primary
        case .wallet: DesignTokens.Colors.Accent.lightning
        case .url: DesignTokens.Colors.Accent.warning
        case .app: Color.ds.textSecondary
        }
    }
}

// MARK: - Report context

private extension DiagnosticsReport.Context {
    /// The running app on this device.
    @MainActor
    static var current: Self {
        Self(
            appVersion: Build.shared.version,
            build: Build.shared.build,
            environment: Build.shared.environment.rawValue,
            deviceModel: deviceModel,
            systemVersion: UIDevice.current.systemVersion
        )
    }

    /// The hardware identifier, such as `iPhone17,3`, which `UIDevice` doesn't expose.
    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

// MARK: - Preview

#Preview("With events") {
    let directory = FileManager.default.temporaryDirectory.appending(path: "diagnostics-preview")
    let log = DiagnosticsLog(store: DiagnosticsStore(directory: directory))
    log.clear()
    log.record(.app, "Launched Avocadough 1.4 (7) · DEVELOPMENT")
    log.record(.scan, "Scanner opened")
    log.record(.scan, "Camera decoded a QR code (312 characters)", detail: "LIGHTNING:LNBC20U1PN2HNHMPP5HF964HHC77LF4VJPLTDNUMA0FDL2PP2AFAGZUEG8H2GV8X2JU5TQDPZW3JHXARFDENJQNZYFVSXJM3QGFHK7UM50GCQZZSXQYZ5VQSP5A8AYRHGZYHGCE6Y49M9Z5YPVNGSLKKAJJFZ8DX3QEG94GTL6DG9Q9QXPQYSGQ53S3DDMVY0X2LQ3JM06LH9EUL0W8MTMGPCT09G68UUKETGW2XVSYFWMM6QJJ9T7HRTU8UL859C93GGAZ69QUJ9LTPSZT4022CCA6ZNSQ9V2LMP")
    log.record(.send, "Decoded a BOLT11 invoice", detail: "2000 sats · expired · payee 030a58b8…722677a3 · payment hash ba4baadef8f7be9ab241fadb3e6faf4b7ea0855d4f502e6507ba90c39952e516")
    log.record(.send, "Rejected input: expired invoice")
    log.record(.send, "Popped the scanner so the error alert can show")

    return NavigationStack {
        DiagnosticsView()
    }
    .environment(\.diagnostics, log)
}

#Preview("Empty") {
    let directory = FileManager.default.temporaryDirectory.appending(path: "diagnostics-preview-empty")
    let log = DiagnosticsLog(store: DiagnosticsStore(directory: directory))
    log.clear()

    return NavigationStack {
        DiagnosticsView()
    }
    .environment(\.diagnostics, log)
}
