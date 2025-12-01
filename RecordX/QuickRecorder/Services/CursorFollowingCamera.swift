//
//  CursorFollowingCamera.swift
//  RecordX
//
//  Webcam overlay that follows the cursor during recording
//

import SwiftUI
import AppKit
import AVFoundation

// MARK: - Cursor Following Camera Service

class CursorFollowingCameraService: ObservableObject {
    static let shared = CursorFollowingCameraService()

    @Published var isEnabled = false
    @Published var cameraSize: CGFloat = 150
    @Published var cameraShape: CameraShape = .circle
    @Published var cameraPosition: CameraPosition = .followCursor
    @Published var cursorOffset: CGPoint = CGPoint(x: 50, y: -50)
    @Published var borderColor: NSColor = .white
    @Published var borderWidth: CGFloat = 3
    @Published var shadowEnabled: Bool = true
    @Published var smoothFollow: Bool = true
    @Published var followSpeed: CGFloat = 0.15

    private var cameraWindow: NSWindow?
    private var displayLink: CVDisplayLink?
    private var currentPosition: CGPoint = .zero
    private var targetPosition: CGPoint = .zero

    // Webcam capture session
    private(set) var webcamSession: AVCaptureSession?
    private var webcamDevice: AVCaptureDevice?
    private var trackingTimer: Timer?

    enum CameraShape: String, CaseIterable {
        case circle = "Circle"
        case roundedSquare = "Rounded Square"
        case square = "Square"
    }

    enum CameraPosition: String, CaseIterable {
        case followCursor = "Follow Cursor"
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"
    }

    private init() {
        setupWebcamSession()
    }

    private func setupWebcamSession() {
        webcamSession = AVCaptureSession()
        webcamSession?.sessionPreset = .medium

        // Find default webcam
        if let device = AVCaptureDevice.default(for: .video) {
            webcamDevice = device
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if webcamSession?.canAddInput(input) == true {
                    webcamSession?.addInput(input)
                }
            } catch {
                print("Failed to setup webcam: \(error)")
            }
        }
    }

    /// Get available webcam devices
    func getAvailableWebcams() -> [AVCaptureDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        return discoverySession.devices
    }

    /// Select a specific webcam
    func selectWebcam(_ device: AVCaptureDevice) {
        guard let session = webcamSession else { return }

        session.beginConfiguration()

        // Remove existing inputs
        for input in session.inputs {
            session.removeInput(input)
        }

        // Add new input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
                webcamDevice = device
            }
        } catch {
            print("Failed to select webcam: \(error)")
        }

        session.commitConfiguration()
    }

    func startCamera() {
        guard webcamSession != nil else {
            print("No webcam session available")
            return
        }

        isEnabled = true

        // Start webcam capture session
        DispatchQueue.global(qos: .userInitiated).async {
            self.webcamSession?.startRunning()
        }

        DispatchQueue.main.async {
            self.createCameraWindow()
            self.startTracking()
        }
    }

    func stopCamera() {
        isEnabled = false
        stopTracking()

        // Stop webcam capture session
        DispatchQueue.global(qos: .userInitiated).async {
            self.webcamSession?.stopRunning()
        }

        DispatchQueue.main.async {
            self.cameraWindow?.close()
            self.cameraWindow = nil
        }
    }

    private func createCameraWindow() {
        let size = NSSize(width: cameraSize, height: cameraSize)

        cameraWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        guard let window = cameraWindow else { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.hasShadow = shadowEnabled

        let contentView = NSHostingView(rootView: CursorFollowingCameraView(service: self))
        window.contentView = contentView

        // Initial position
        if let screen = NSScreen.main {
            let mouseLocation = NSEvent.mouseLocation
            updateWindowPosition(mouseLocation: mouseLocation, screen: screen, animated: false)
        }

        window.orderFront(nil)
    }

    private func startTracking() {
        // Use a timer for smooth cursor following
        Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isEnabled else {
                timer.invalidate()
                return
            }

            let mouseLocation = NSEvent.mouseLocation
            if let screen = NSScreen.main {
                self.updateWindowPosition(mouseLocation: mouseLocation, screen: screen, animated: self.smoothFollow)
            }
        }
    }

    private func stopTracking() {
        displayLink = nil
    }

    private func updateWindowPosition(mouseLocation: CGPoint, screen: NSScreen, animated: Bool) {
        guard let window = cameraWindow else { return }

        var newPosition: CGPoint

        switch cameraPosition {
        case .followCursor:
            newPosition = CGPoint(
                x: mouseLocation.x + cursorOffset.x,
                y: mouseLocation.y + cursorOffset.y
            )
        case .topLeft:
            newPosition = CGPoint(x: screen.frame.minX + 20, y: screen.frame.maxY - cameraSize - 40)
        case .topRight:
            newPosition = CGPoint(x: screen.frame.maxX - cameraSize - 20, y: screen.frame.maxY - cameraSize - 40)
        case .bottomLeft:
            newPosition = CGPoint(x: screen.frame.minX + 20, y: screen.frame.minY + 20)
        case .bottomRight:
            newPosition = CGPoint(x: screen.frame.maxX - cameraSize - 20, y: screen.frame.minY + 20)
        }

        // Keep window on screen
        newPosition.x = max(screen.frame.minX, min(newPosition.x, screen.frame.maxX - cameraSize))
        newPosition.y = max(screen.frame.minY, min(newPosition.y, screen.frame.maxY - cameraSize))

        if animated && smoothFollow {
            // Smooth interpolation
            currentPosition.x += (newPosition.x - currentPosition.x) * followSpeed
            currentPosition.y += (newPosition.y - currentPosition.y) * followSpeed
            window.setFrameOrigin(currentPosition)
        } else {
            currentPosition = newPosition
            window.setFrameOrigin(newPosition)
        }
    }

    func updateSize(_ newSize: CGFloat) {
        cameraSize = newSize
        cameraWindow?.setContentSize(NSSize(width: newSize, height: newSize))
    }
}

// MARK: - Cursor Following Camera View

struct CursorFollowingCameraView: View {
    @ObservedObject var service: CursorFollowingCameraService

    var body: some View {
        ZStack {
            // Camera preview with shape
            switch service.cameraShape {
            case .circle:
                CameraPreviewView()
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(service.borderColor), lineWidth: service.borderWidth))
            case .roundedSquare:
                CameraPreviewView()
                    .clipShape(RoundedRectangle(cornerRadius: service.cameraSize * 0.2))
                    .overlay(RoundedRectangle(cornerRadius: service.cameraSize * 0.2).stroke(Color(service.borderColor), lineWidth: service.borderWidth))
            case .square:
                CameraPreviewView()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(service.borderColor), lineWidth: service.borderWidth))
            }
        }
        .frame(width: service.cameraSize, height: service.cameraSize)
        .shadow(color: service.shadowEnabled ? .black.opacity(0.3) : .clear, radius: 10, x: 0, y: 5)
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: NSViewRepresentable {
    func makeNSView(context: Context) -> CameraPreviewNSView {
        CameraPreviewNSView()
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        // Update preview if session changed
        nsView.updateSession()
    }
}

class CameraPreviewNSView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setupPreview()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setupPreview()
    }

    private func setupPreview() {
        // Use the webcam session from CursorFollowingCameraService
        guard let session = CursorFollowingCameraService.shared.webcamSession else {
            print("No webcam session available for preview")
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer?.frame = bounds
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1)) // Mirror for selfie view

        if let layer = previewLayer {
            self.layer?.addSublayer(layer)
        }
    }

    func updateSession() {
        guard let session = CursorFollowingCameraService.shared.webcamSession else { return }

        if previewLayer == nil {
            setupPreview()
        } else if previewLayer?.session !== session {
            previewLayer?.session = session
        }
    }

    override func layout() {
        super.layout()
        previewLayer?.frame = bounds
    }
}

// MARK: - Settings View for Cursor Camera

struct CursorCameraSettingsView: View {
    @ObservedObject var service = CursorFollowingCameraService.shared
    @AppStorage("cursorCameraEnabled") private var cursorCameraEnabled = false
    @AppStorage("cursorCameraSize") private var cursorCameraSize: Double = 150
    @AppStorage("cursorCameraShape") private var cursorCameraShape: String = "circle"
    @AppStorage("cursorCameraPosition") private var cursorCameraPosition: String = "followCursor"
    @AppStorage("cursorCameraBorderWidth") private var cursorCameraBorderWidth: Double = 3
    @AppStorage("cursorCameraShadow") private var cursorCameraShadow = true
    @AppStorage("cursorCameraSmoothFollow") private var cursorCameraSmoothFollow = true
    @AppStorage("cursorCameraOffsetX") private var cursorCameraOffsetX: Double = 50
    @AppStorage("cursorCameraOffsetY") private var cursorCameraOffsetY: Double = -50

    @State private var availableWebcams: [AVCaptureDevice] = []
    @State private var selectedWebcamID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Enable Cursor-Following Camera", isOn: $cursorCameraEnabled)
                .onChange(of: cursorCameraEnabled) { enabled in
                    if enabled {
                        service.startCamera()
                    } else {
                        service.stopCamera()
                    }
                }

            if cursorCameraEnabled {
                Divider()

                // Webcam Selection
                HStack {
                    Text("Camera:")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $selectedWebcamID) {
                        ForEach(availableWebcams, id: \.uniqueID) { device in
                            Text(device.localizedName).tag(device.uniqueID)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: selectedWebcamID) { newID in
                        if let device = availableWebcams.first(where: { $0.uniqueID == newID }) {
                            service.selectWebcam(device)
                        }
                    }
                }

                // Size
                HStack {
                    Text("Size:")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $cursorCameraSize, in: 80...300, step: 10)
                        .onChange(of: cursorCameraSize) { size in
                            service.updateSize(size)
                        }
                    Text("\(Int(cursorCameraSize))px")
                        .frame(width: 50)
                        .foregroundColor(.secondary)
                }

                // Shape
                HStack {
                    Text("Shape:")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $cursorCameraShape) {
                        ForEach(CursorFollowingCameraService.CameraShape.allCases, id: \.rawValue) { shape in
                            Text(shape.rawValue).tag(shape.rawValue)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: cursorCameraShape) { shape in
                        service.cameraShape = CursorFollowingCameraService.CameraShape(rawValue: shape) ?? .circle
                    }
                }

                // Position
                HStack {
                    Text("Position:")
                        .frame(width: 80, alignment: .leading)
                    Picker("", selection: $cursorCameraPosition) {
                        ForEach(CursorFollowingCameraService.CameraPosition.allCases, id: \.rawValue) { position in
                            Text(position.rawValue).tag(position.rawValue)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: cursorCameraPosition) { position in
                        service.cameraPosition = CursorFollowingCameraService.CameraPosition(rawValue: position) ?? .followCursor
                    }
                }

                // Offset (only for follow cursor mode)
                if cursorCameraPosition == "followCursor" {
                    HStack {
                        Text("Offset X:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $cursorCameraOffsetX, in: -200...200, step: 10)
                            .onChange(of: cursorCameraOffsetX) { x in
                                service.cursorOffset.x = x
                            }
                        Text("\(Int(cursorCameraOffsetX))")
                            .frame(width: 40)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Offset Y:")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $cursorCameraOffsetY, in: -200...200, step: 10)
                            .onChange(of: cursorCameraOffsetY) { y in
                                service.cursorOffset.y = y
                            }
                        Text("\(Int(cursorCameraOffsetY))")
                            .frame(width: 40)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Smooth Following", isOn: $cursorCameraSmoothFollow)
                        .onChange(of: cursorCameraSmoothFollow) { smooth in
                            service.smoothFollow = smooth
                        }
                }

                // Border
                HStack {
                    Text("Border:")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $cursorCameraBorderWidth, in: 0...10, step: 1)
                        .onChange(of: cursorCameraBorderWidth) { width in
                            service.borderWidth = width
                        }
                    Text("\(Int(cursorCameraBorderWidth))px")
                        .frame(width: 40)
                        .foregroundColor(.secondary)
                }

                Toggle("Shadow", isOn: $cursorCameraShadow)
                    .onChange(of: cursorCameraShadow) { shadow in
                        service.shadowEnabled = shadow
                    }
            }
        }
        .padding()
        .onAppear {
            availableWebcams = service.getAvailableWebcams()
            if let firstDevice = availableWebcams.first {
                selectedWebcamID = firstDevice.uniqueID
            }
        }
    }
}
