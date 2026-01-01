//
//  SetupPresenter.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 12/6/24.
//

import SwiftUI
import SwiftData
@preconcurrency import AVFoundation

struct SetupPresenter: View {
    @Environment(SetupState.self) private var state
    @Environment(\.nwc) private var nwc
    
    var body: some View {
        @Bindable var state = state
        
        NavigationStack {
            SetupView()
                .sheet(item: $state.sheet) {
                    switch $0 {
                    case .scanQR:
                        NavigationStack {
                            ScanQRCodeView()
                                .environment(state.scanQRCodeState)
                        }
                    }
                }
                .alert($state.errorMessage)
        }
    }
}

fileprivate struct SetupView: View {
    @Environment(SetupState.self) private var state
    @Environment(\.nwc) private var nwc
    @Environment(\.modelContext) private var context
    @Query private var nwcCodes: [NWCConnection]
    @State private var requestCameraAccessTrigger = PlainTaskTrigger()
    @State private var evaluateConnectionSecretTrigger = PlainTaskTrigger()
    @Environment(\.colorScheme) private var colorScheme
    
    private var buttonText: Color {
        colorScheme == .light ? .white : .black
    }
    
    private var promoptText: Color {
        colorScheme == .light ? .gray : .white.opacity(0.75)
    }
    
    var body: some View {
        @Bindable var state = state
        
        VStack {
            HStack {
                TextField("", text: $state.connectionSecret, prompt: Text("enter connection secret")
                    .foregroundStyle(promoptText))
                    .textFieldStyle(.roundedBorder)
                Button("enter", action: triggerEvaluateConnectionSecret)
                    .foregroundStyle(buttonText)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Text("or")
                .font(.subheadline)
                .padding()
            
            Button("scan QR", systemImage: "camera.viewfinder", action: tappedScanQR)
                .foregroundStyle(buttonText)
                .buttonStyle(.borderedProminent)
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack {
                    Text("Avocadough")
                        .font(.largeTitle)
                        .bold()
                    
                    Image(systemName: "bolt.fill")
                        .imageScale(.large)
                        .foregroundStyle(Color.yellow)
                    Image(systemName: "bolt.fill")
                        .imageScale(.large)
                        .foregroundStyle(Color.yellow)
                }
                .setForegroundStyle()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: nwc.hasConnected) { configApp() }
        .task(id: state.foundQRCode) { await parseWalletCode() }
        .task($requestCameraAccessTrigger) { await requestCameraAccess() }
        .task($evaluateConnectionSecretTrigger) { await evaluateConnectionSecret() }
        .fullScreenColorView()
    }
    
    private func triggerEvaluateConnectionSecret() {
        evaluateConnectionSecretTrigger.trigger()
    }
    
    private func evaluateConnectionSecret() async {
        guard !state.connectionSecret.isEmpty else { return }
        await parseWalletCode(state.connectionSecret)
    }
    
    private func tappedScanQR() {
        state.foundQRCode = nil
        let cameraAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        if cameraAuthorizationStatus == .authorized {
            state.sheet = .scanQR
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
            state.sheet = .scanQR
        }
    }
    
    private func parseWalletCode() async {
        guard let code = state.foundQRCode else { return }
        await parseWalletCode(code)
    }
    
    private func parseWalletCode(_ code: String) async {
        do {
            let nwcCode = try nwc.parseWalletCode(code)
            context.insert(nwcCode)
            try context.save()
            
            do {
                try await nwc.initializeNWCClient(pubKey: nwcCode.pubKey, relay: nwcCode.relay, lud16: nwcCode.lud16)
            } catch {
                state.errorMessage = "failed to initialize NWC wallet connection"
            }
        } catch {
            state.errorMessage = "failed to initialize NWC wallet connection"
        }
    }
    
    private func configApp() {
        state.walletSuccessfullyConnected()
    }
}

#Preview {
    SetupPresenter()
        .environment(SetupState(parentState: AppState()))
        .environment(ScanQRCodeState(parentState: SetupState(parentState: .init())))
        .environment(\.nwc, NWC())
}
