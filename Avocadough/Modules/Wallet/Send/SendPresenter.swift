//
//  SendView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 1/10/24.
//

import SwiftUI
@preconcurrency import AVFoundation

struct SendPresenter: View {
    @Environment(SendState.self) private var state

    var body: some View {
        @Bindable var state = state

        NavigationStack(path: $state.path) {
            SendView()
                .navigationDestination(for: SendState.NavigationLink.self) {
                    switch $0 {
                    case .getLightningAddressDetails(let address):
                        SendDetailsView(lightningAddress: address)
                    case .sendInvoice(let bolt11):
                        SendConfirmationView(bolt11: bolt11)
                    case .reviewPayment(let recipient, let amount, let invoicePR):
                        SendReviewView(
                            recipient: recipient,
                            amount: amount,
                            invoicePR: invoicePR,
                            btcPrice: state.btcPrice
                        )
                    case .paymentSuccess(let amount, let recipient):
                        PaymentSuccessView(
                            amount: amount,
                            recipient: recipient,
                            btcPrice: state.btcPrice
                        ) {
                            state.paymentSent()
                        }
                        .navigationBarBackButtonHidden()
                    case .scanQR:
                        ScanQRCodeView()
                            .environment(state.scanQRCodeState)
                    }
                }
        }
    }
}

fileprivate struct SendView: View {
    @Environment(SendState.self) private var state
    @Environment(\.dismiss) private var dismiss
    @State private var lightningInput = ""
    @State private var requestCameraAccessTrigger = PlainTaskTrigger()
    
    var body: some View {
        @Bindable var state = state
        
        VStack {
            HStack {
                TextField("invoice, lightning address, or LNURL", text: $lightningInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                
                Button("go", action: continueWithInput)
                    .buttonStyle(.bordered)
            }
            .padding()
            
            Text("OR:")
                .font(.headline)
            
            Button("scan QR", systemImage: "qrcode.viewfinder", action: scanQR)
                .font(.title)
        }
        .fullScreenColorView()
        .navigationTitle("send BTC")
        .alert($state.errorMessage)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done", action: { dismiss() })
            }
        }
        .task($requestCameraAccessTrigger) { await requestCameraAccess() }
    }
    
    private func continueWithInput() {
        state.continueWithInput(lightningInput)
    }
    
    private func scanQR() {
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        if cameraAuthorizationStatus == .authorized {
            state.path.append(.scanQR)
        } else {
            triggerRequestCameraAccess()
        }
    }
    
    private func triggerRequestCameraAccess() {
        requestCameraAccessTrigger.trigger()
    }
    
    private func requestCameraAccess() async {
        let isPermissionGranted = await AVCaptureDevice.requestAccess(for: .video)
        
        if isPermissionGranted {
            state.path.append(.scanQR)
        }
    }
}

#Preview {
    @Previewable @State var state = AppState()
    
    Text("wallet")
        .sheet(isPresented: .constant(true)) {
            SendPresenter()
                .environment(state)
                .environment(state.walletState.sendState)
        }
}
