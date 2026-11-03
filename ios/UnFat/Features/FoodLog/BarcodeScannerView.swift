import AVFoundation
import SwiftUI
import UIKit
import Vision
import VisionKit

/// Whether the camera can be used for scanning.
enum CameraAccess: Equatable, Sendable {
    case checking
    case authorized
    /// Permission refused or restricted; Settings can change it.
    case denied
    /// No camera (simulator, restricted device).
    case unavailable
}

/// Camera scanner for EAN-13, EAN-8, UPC-E and Code 128. Uses VisionKit's `DataScannerViewController`
/// when the device supports it, an `AVCaptureSession` metadata scanner otherwise. Without a usable
/// camera it explains why and offers manual entry; "Barkodu elle gir" is always reachable.
/// `onBarcode` is called once with a validated barcode (8-14 digits), after a success haptic.
struct BarcodeScannerView: View {
    let onBarcode: (String) -> Void
    /// Skips the permission check; used by the DEBUG routes (the simulator has no camera).
    var forcedAccess: CameraAccess?

    @Environment(\.openURL) private var openURL
    @State private var access: CameraAccess = .checking
    @State private var showsManualEntry = false
    @State private var manualText = ""
    @State private var didDeliver = false

    var body: some View {
        content
            .background(Palette.groupedBackground)
            .navigationTitle("Barkod tara")
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(Haptics.barcodeScanned, trigger: didDeliver) { _, newValue in newValue }
            .task { await resolveAccess() }
    }

    @ViewBuilder
    private var content: some View {
        switch access {
        case .checking:
            Color.clear
        case .authorized:
            cameraContent
        case .denied, .unavailable:
            unavailableContent
        }
    }

    // MARK: - Camera

    private var cameraContent: some View {
        ZStack(alignment: .bottom) {
            camera
                .ignoresSafeArea(edges: .bottom)
            VStack(spacing: Spacing.sm) {
                if showsManualEntry {
                    ManualBarcodeEntry(text: $manualText, onSubmit: deliverManual)
                } else {
                    Text("Barkodu kameraya hizala.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.label)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                        .background(.regularMaterial, in: .capsule)
                    Button("Barkodu elle gir") {
                        showsManualEntry = true
                    }
                    .buttonStyle(.bordered)
                    .tint(Palette.accent)
                }
            }
            .padding(Spacing.md)
        }
    }

    @ViewBuilder
    private var camera: some View {
        if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            DataScannerRepresentable(onCode: deliver)
        } else {
            CaptureScannerRepresentable(onCode: deliver)
        }
    }

    // MARK: - No camera

    private var unavailableTitle: LocalizedStringKey {
        access == .denied ? "Kamera erişimi kapalı" : "Kamera kullanılamıyor"
    }

    private var unavailableMessage: LocalizedStringKey {
        access == .denied
            ? "Barkodu okumak için kameraya izin ver. İstersen barkodu elle de girebilirsin."
            : "Bu cihazda kamera yok. Barkodu elle girebilirsin."
    }

    private var unavailableContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ContentUnavailableView {
                    Label(unavailableTitle, systemImage: "camera")
                } description: {
                    Text(unavailableMessage)
                } actions: {
                    if access == .denied {
                        Button("Ayarları aç", action: openSettings)
                            .buttonStyle(.borderedProminent)
                            .tint(Palette.accent)
                    }
                }
                ManualBarcodeEntry(text: $manualText, onSubmit: deliverManual)
                    .padding(.horizontal, Spacing.sideMargin)
            }
            .padding(.top, Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Actions

    private func resolveAccess() async {
        if let forcedAccess {
            access = forcedAccess
            return
        }
        guard AVCaptureDevice.default(for: .video) != nil else {
            access = .unavailable
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            access = .authorized
        case .notDetermined:
            access = await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        default:
            access = .denied
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private func deliverManual() {
        guard let code = BarcodeValidator.normalized(manualText) else { return }
        deliver(code)
    }

    /// First valid code wins; later detections are ignored.
    private func deliver(_ code: String) {
        guard !didDeliver else { return }
        didDeliver = true
        onBarcode(code)
    }
}

/// Number field plus "Ara" for typing a barcode by hand.
struct ManualBarcodeEntry: View {
    @Binding var text: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            TextField("Barkod numarası", text: $text)
                .keyboardType(.numberPad)
                .monospacedDigit()
                .focused($isFocused)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: Radius.container, style: .continuous)
                        .fill(Palette.secondaryGroupedBackground)
                )
            Button("Ara", action: onSubmit)
                .buttonStyle(.borderedProminent)
                .tint(Palette.accent)
                .controlSize(.large)
                .disabled(BarcodeValidator.normalized(text) == nil)
        }
    }
}

// MARK: - VisionKit scanner

private struct DataScannerRepresentable: UIViewControllerRepresentable {
    let onCode: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        context.coordinator.onCode = onCode
        if !controller.isScanning && !context.coordinator.finished {
            try? controller.startScanning()
        }
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onCode: @MainActor (String) -> Void
        var finished = false

        init(onCode: @escaping @MainActor (String) -> Void) {
            self.onCode = onCode
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            handle(addedItems, in: dataScanner)
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            handle([item], in: dataScanner)
        }

        private func handle(_ items: [RecognizedItem], in scanner: DataScannerViewController) {
            guard !finished else { return }
            for item in items {
                guard case .barcode(let barcode) = item,
                      let payload = barcode.payloadStringValue,
                      let code = BarcodeValidator.normalized(payload)
                else { continue }
                finished = true
                scanner.stopScanning()
                onCode(code)
                return
            }
        }
    }
}

// MARK: - AVFoundation fallback

/// Owns the capture session. All session work runs on its own serial queue; results hop to the main
/// actor through `onCodes`. `@unchecked Sendable`: mutable state is only touched on `queue`.
private final class CaptureController: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "io.github.yusufuzun03.unfat.barcode-capture")
    private let onCodes: @Sendable ([String]) -> Void
    private var isConfigured = false

    init(onCodes: @escaping @Sendable ([String]) -> Void) {
        self.onCodes = onCodes
    }

    func start() {
        queue.async { [self] in
            if !isConfigured { configure() }
            if isConfigured && !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: queue)
        let wanted: [AVMetadataObject.ObjectType] = [.ean13, .ean8, .upce, .code128]
        output.metadataObjectTypes = wanted.filter { output.availableMetadataObjectTypes.contains($0) }
        isConfigured = true
    }

    // Runs on `queue`.
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        let codes = metadataObjects.compactMap { ($0 as? AVMetadataMachineReadableCodeObject)?.stringValue }
        if !codes.isEmpty { onCodes(codes) }
    }
}

private final class CapturePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        // layerClass guarantees the type.
        layer as! AVCaptureVideoPreviewLayer
    }
}

private struct CaptureScannerRepresentable: UIViewRepresentable {
    let onCode: @MainActor (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIView(context: Context) -> CapturePreviewView {
        let coordinator = context.coordinator
        let controller = CaptureController { [weak coordinator] codes in
            Task { @MainActor in coordinator?.handle(codes) }
        }
        coordinator.controller = controller
        let view = CapturePreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = controller.session
        controller.start()
        return view
    }

    func updateUIView(_ view: CapturePreviewView, context: Context) {
        context.coordinator.onCode = onCode
    }

    static func dismantleUIView(_ view: CapturePreviewView, coordinator: Coordinator) {
        coordinator.controller?.stop()
    }

    @MainActor
    final class Coordinator {
        var onCode: @MainActor (String) -> Void
        var controller: CaptureController?
        private var finished = false
        private var lastCode: String?
        private var streak = 0

        init(onCode: @escaping @MainActor (String) -> Void) {
            self.onCode = onCode
        }

        /// A code counts after two consecutive frames agree, which filters one-frame misreads.
        func handle(_ codes: [String]) {
            guard !finished else { return }
            for raw in codes {
                guard let code = BarcodeValidator.normalized(raw) else { continue }
                if code == lastCode {
                    streak += 1
                } else {
                    lastCode = code
                    streak = 1
                }
                if streak >= 2 {
                    finished = true
                    controller?.stop()
                    onCode(code)
                    return
                }
            }
        }
    }
}
