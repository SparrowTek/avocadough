//
//  ReceivePresenter.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 2/11/24.
//

import SwiftUI
import SwiftData
import CoreImage.CIFilterBuiltins

struct ReceivePresenter: View {
    @Environment(ReceiveState.self) private var state

    var body: some View {
        @Bindable var state = state

        NavigationStack(path: $state.path) {
            ReceiveView()
                .navigationDestination(for: ReceiveState.NavigationLink.self) {
                    switch $0 {
                    case .createInvoice:
                        CreateInvoiceView()
                            .interactiveDismissDisabled()
                    case .displayInvoice(let invoice):
                        DisplayInvoiceView(invoice: invoice)
                    case .paymentReceived(let amount):
                        PaymentReceivedView(
                            amount: amount,
                            btcPrice: state.btcPrice
                        ) {
                            state.doneTapped()
                        }
                        .navigationBarBackButtonHidden()
                    }
                }
                .alert($state.errorMessage)
        }
    }
}

fileprivate struct ReceiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ReceiveState.self) private var state
    @State private var lightningAddressCopied = false
    @State private var copyTrigger = false
    @Query private var nwcConnections: [NWCConnection]

    private var lud16: String? {
        isCanvas ? "sparrowtek@getalby.com" : nwcConnection?.lud16
    }

    private var nwcConnection: NWCConnection? {
        nwcConnections.first
    }

    var body: some View {
        if let lud16 {
            VStack(spacing: DesignTokens.Spacing.lg) {
                Spacer()

                // QR Code with enhanced styling
                qrCodeSection(lud16: lud16)

                // Lightning Address with copy button
                addressSection(lud16: lud16)

                Spacer()

                // Create Invoice option
                invoiceOption

                Spacer()
            }
            .fullScreenColorView()
            .navigationTitle("Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: { dismiss() })
                }
            }
            .sensoryFeedback(AppHaptics.copy, trigger: copyTrigger)
        } else {
            CreateInvoiceView()
        }
    }

    // MARK: - Subviews

    private func qrCodeSection(lud16: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            // QR Code container
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                    .fill(Color.white)
                    .frame(width: 240, height: 240)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)

                QRCodeImage(code: lud16)
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
            }

            Text("Scan to send sats")
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(Color.ds.textSecondary)
        }
    }

    private func addressSection(lud16: String) -> some View {
        Button(action: { copyLightningAddress(lud16) }) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(DesignTokens.Colors.Accent.primary)

                Text(lud16)
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(Color.ds.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                ZStack {
                    Image(systemName: "doc.on.doc")
                        .foregroundStyle(Color.ds.textSecondary)
                        .opacity(lightningAddressCopied ? 0 : 1)

                    Image(systemName: "checkmark")
                        .foregroundStyle(DesignTokens.Colors.Semantic.connected)
                        .opacity(lightningAddressCopied ? 1 : 0)
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }

    private var invoiceOption: some View {
        Button(action: createLightningInvoice) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(DesignTokens.Colors.Accent.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Create Invoice")
                        .font(DesignTokens.Typography.headline)
                        .foregroundStyle(Color.ds.textPrimary)

                    Text("Request a specific amount")
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(Color.ds.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.ds.textTertiary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(DesignTokens.Colors.Background.secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }

    // MARK: - Actions

    private func createLightningInvoice() {
        state.path.append(.createInvoice)
    }

    private func copyLightningAddress(_ address: String) {
        UIPasteboard.general.string = address
        lightningAddressCopied = true
        copyTrigger.toggle()

        // TODO: probably don't want an unstructered task closure here
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            lightningAddressCopied = false
        }
    }
}

#Preview {
    @Previewable @State var state = AppState()
    
    ReceivePresenter()
        .environment(state.walletState.receiveState)
}
