//
//  ScanQRCodeView.swift
//  Avocadough
//
//  Created by Thomas Rademaker on 4/7/24.
//

import SwiftUI
@preconcurrency import AVFoundation

struct ScanQRCodeView: View {
    @Environment(ScanQRCodeState.self) private var state
    @Environment(\.diagnostics) private var diagnostics
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScannerView()
            .fullScreenColorView()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: onAppear)
            .onDisappear(perform: onDisappear)
            .onChange(of: state.errorMessage, exitView)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done", action: { dismiss() })
                }
            }
    }
    
    private func exitView() {
        state.exitView()
    }
    
    private func onAppear() {
        diagnostics.record(.scan, "Scanner opened")
    }
    
    private func onDisappear() {
        diagnostics.record(.scan, "Scanner closed")
        state.postQRCodeScanComplete()
    }
}

fileprivate struct ScannerView: View {
    @Environment(ScanQRCodeState.self) private var state
    @Environment(\.diagnostics) private var diagnostics
    private let scanInterval: Double = 1.0
    @State private var lastQrCode: String = ""
    @State private var didLogRepeat = false
    
    var body: some View {
        ZStack {
            QrCodeScannerView()
                .found(r: onFoundQrCode)
                .interval(delay: scanInterval)
                .onChange(of: lastQrCode) { foundCode() }
            
            Image(systemName: "square.dashed")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .foregroundStyle(Color.white)
                .padding(32)
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
    
    /// Hands a decoded code on once. The camera keeps decoding the same code for as long
    /// as it stays in frame and `onChange` only fires on a change, so repeats are dropped
    /// here and noted a single time so the log shows the scanner was still seeing it.
    private func onFoundQrCode(_ code: String) {
        guard code != lastQrCode else {
            if !didLogRepeat {
                didLogRepeat = true
                diagnostics.record(.scan, "Camera decoded the same code again; repeats are ignored")
            }
            return
        }

        didLogRepeat = false
        diagnostics.record(.scan, "Camera decoded a QR code (\(code.count) characters)", detail: code)
        lastQrCode = code
    }
    
    private func foundCode() {
        state.foundQRCode(lastQrCode)
    }
}

fileprivate struct QrCodeScannerView: UIViewRepresentable {
    
    var supportedBarcodeTypes: [AVMetadataObject.ObjectType] = [.qr]
    typealias UIViewType = CameraPreview

    private var scanInterval: Double = 1.0
    private var onResult: (String) -> Void = { _ in }
    private var mockData: String?

    /// Owns the capture objects for as long as the camera view is on screen.
    ///
    /// SwiftUI rebuilds this struct every time `ScannerView.body` runs, which happens
    /// right after the scanner is pushed, and `AVCaptureMetadataOutput` only holds its
    /// delegate weakly. Capture objects stored on the struct are freed by that first
    /// rebuild, leaving a live preview that never reports a code.
    @MainActor
    final class Coordinator {
        let session = AVCaptureSession()
        let delegate = QrCodeCameraDelegate()
        let metadataOutput = AVCaptureMetadataOutput()
        var diagnostics: DiagnosticsLog?

        /// Whether the camera was still able to report codes, for the diagnostics log.
        var status: String {
            let running = session.isRunning ? "yes" : "no"
            let wired = metadataOutput.metadataObjectsDelegate == nil ? "no" : "yes"
            return "session running: \(running) · delegate wired: \(wired) · detections: \(delegate.detectionCount)"
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func interval(delay: Double) -> QrCodeScannerView {
        var view = self
        view.scanInterval = delay
        return view
    }

    func found(r: @escaping (String) -> Void) -> QrCodeScannerView {
        var view = self
        view.onResult = r
        return view
    }

    func simulator(mockBarCode: String)-> QrCodeScannerView{
        var view = self
        view.mockData = mockBarCode
        return view
    }

    /// Hands the delegate the newest callback, so it never calls into a stale copy of
    /// the view that created it.
    private func configure(_ delegate: QrCodeCameraDelegate) {
        delegate.scanInterval = scanInterval
        delegate.onResult = onResult
        delegate.mockData = mockData
    }

    func setupCamera(_ uiView: CameraPreview, coordinator: Coordinator, diagnostics: DiagnosticsLog) {
        let session = coordinator.session
        let metadataOutput = coordinator.metadataOutput

        guard let backCamera = AVCaptureDevice.default(for: AVMediaType.video),
              let input = try? AVCaptureDeviceInput(device: backCamera) else {
            diagnostics.record(.scan, "Camera unavailable: no video device could be opened")
            return
        }
        session.sessionPreset = .photo

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            diagnostics.record(.scan, "The camera input couldn't be added to the capture session")
        }
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            
            metadataOutput.metadataObjectTypes = supportedBarcodeTypes
            metadataOutput.setMetadataObjectsDelegate(coordinator.delegate, queue: DispatchQueue.main)
            diagnostics.record(
                .scan,
                "Camera session configured for QR detection",
                detail: "\(backCamera.localizedName) · minimum focus distance: \(backCamera.minimumFocusDistance) mm"
            )
        } else {
            diagnostics.record(.scan, "The metadata output couldn't be added, so no QR code can be detected")
        }
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        
        uiView.backgroundColor = UIColor.gray
        previewLayer.videoGravity = .resizeAspectFill
        uiView.layer.addSublayer(previewLayer)
        uiView.previewLayer = previewLayer
        
        Task.detached {
            session.startRunning()
        }
    }

    func makeUIView(context: UIViewRepresentableContext<QrCodeScannerView>) -> QrCodeScannerView.UIViewType {
        let coordinator = context.coordinator
        coordinator.diagnostics = context.environment.diagnostics
        configure(coordinator.delegate)

        let cameraView = CameraPreview(session: coordinator.session)
        setupCamera(cameraView, coordinator: coordinator, diagnostics: context.environment.diagnostics)

        #if targetEnvironment(simulator)
                cameraView.createSimulatorView(delegate: coordinator.delegate)
        #endif

        return cameraView
    }

    static func dismantleUIView(_ uiView: CameraPreview, coordinator: Coordinator) {
        coordinator.diagnostics?.record(.scan, "Camera stopped", detail: coordinator.status)
        coordinator.session.stopRunning()
    }

    func updateUIView(_ uiView: CameraPreview, context: UIViewRepresentableContext<QrCodeScannerView>) {
        configure(context.coordinator.delegate)
        uiView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        uiView.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }
    
}

class CameraPreview: UIView {
    
    private var label:UILabel?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    var session = AVCaptureSession()
    weak var delegate: QrCodeCameraDelegate?
    
    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        self.session = session
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func createSimulatorView(delegate: QrCodeCameraDelegate){
        self.delegate = delegate
        self.backgroundColor = UIColor.black
        label = UILabel(frame: self.bounds)
        label?.numberOfLines = 4
        label?.text = "Click here to simulate scan"
        label?.textColor = UIColor.white
        label?.textAlignment = .center
        if let label = label {
            addSubview(label)
        }
        let gesture = UITapGestureRecognizer(target: self, action: #selector(onClick))
        self.addGestureRecognizer(gesture)
    }
    
    @objc func onClick(){
        delegate?.onSimulateScanning()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
#if targetEnvironment(simulator)
        label?.frame = self.bounds
#else
        previewLayer?.frame = self.bounds
#endif
    }
}

class QrCodeCameraDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
    
    var scanInterval: Double = 1.0
    var lastTime = Date(timeIntervalSince1970: 0)
    
    var onResult: (String) -> Void = { _  in }
    var mockData: String?

    /// How many times the camera reported a code, readable or not.
    private(set) var detectionCount = 0

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            detectionCount += 1
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            foundBarcode(stringValue)
        }
    }
    
    @objc func onSimulateScanning(){
        foundBarcode(mockData ?? "Simulated QR-code result.")
    }
    
    func foundBarcode(_ stringValue: String) {
        let now = Date()
        if now.timeIntervalSince(lastTime) >= scanInterval {
            lastTime = now
            self.onResult(stringValue)
        }
    }
}

#Preview {
    ScanQRCodeView()
        .environment(ScanQRCodeState(parentState: SendState(parentState: .init(parentState: .init()))))
}
