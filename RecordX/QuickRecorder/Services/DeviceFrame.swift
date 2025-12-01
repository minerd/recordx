//
//  DeviceFrame.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import AppKit
import CoreGraphics
import AVFoundation
import CoreImage

/// Device frame configuration
struct DeviceFrameConfig {
    /// Type of device frame to use
    var deviceType: DeviceType

    /// Frame color variant
    var colorVariant: DeviceColorVariant

    /// Whether to add shadow to the frame
    var addShadow: Bool = true

    /// Shadow configuration
    var shadowConfig: ShadowConfig = .default

    /// Background behind the device
    var background: FrameBackground = .gradient(start: .systemGray, end: .lightGray)

    /// Padding around the device (percentage of frame size)
    var padding: CGFloat = 0.1

    /// Rotation angle in degrees
    var rotationAngle: CGFloat = 0

    /// 3D perspective transform
    var perspective: PerspectiveConfig?

    static let `default` = DeviceFrameConfig(deviceType: .macbookPro14, colorVariant: .spaceBlack)
}

/// Supported device types
enum DeviceType: String, CaseIterable, Identifiable {
    // Mac
    case macbookPro14 = "MacBook Pro 14\""
    case macbookPro16 = "MacBook Pro 16\""
    case macbookAir13 = "MacBook Air 13\""
    case macbookAir15 = "MacBook Air 15\""
    case iMac24 = "iMac 24\""
    case studioDisplay = "Studio Display"
    case proDisplayXDR = "Pro Display XDR"

    // iPhone
    case iPhone15Pro = "iPhone 15 Pro"
    case iPhone15ProMax = "iPhone 15 Pro Max"
    case iPhone15 = "iPhone 15"
    case iPhone14 = "iPhone 14"
    case iPhoneSE = "iPhone SE"

    // iPad
    case iPadPro13 = "iPad Pro 13\""
    case iPadPro11 = "iPad Pro 11\""
    case iPadAir = "iPad Air"
    case iPadMini = "iPad mini"

    // Other
    case appleWatch = "Apple Watch"
    case appleTVBox = "Apple TV"
    case generic = "Generic"

    var id: String { rawValue }

    var category: DeviceCategory {
        switch self {
        case .macbookPro14, .macbookPro16, .macbookAir13, .macbookAir15:
            return .laptop
        case .iMac24, .studioDisplay, .proDisplayXDR:
            return .desktop
        case .iPhone15Pro, .iPhone15ProMax, .iPhone15, .iPhone14, .iPhoneSE:
            return .phone
        case .iPadPro13, .iPadPro11, .iPadAir, .iPadMini:
            return .tablet
        case .appleWatch:
            return .watch
        case .appleTVBox:
            return .tv
        case .generic:
            return .generic
        }
    }

    /// Screen aspect ratio
    var screenAspectRatio: CGFloat {
        switch self {
        case .macbookPro14, .macbookPro16, .macbookAir13, .macbookAir15:
            return 16.0 / 10.0
        case .iMac24, .studioDisplay:
            return 16.0 / 9.0
        case .proDisplayXDR:
            return 16.0 / 9.0
        case .iPhone15Pro, .iPhone15ProMax, .iPhone15, .iPhone14:
            return 19.5 / 9.0
        case .iPhoneSE:
            return 16.0 / 9.0
        case .iPadPro13, .iPadPro11:
            return 4.0 / 3.0
        case .iPadAir, .iPadMini:
            return 4.0 / 3.0
        case .appleWatch:
            return 1.0
        case .appleTVBox:
            return 16.0 / 9.0
        case .generic:
            return 16.0 / 9.0
        }
    }

    /// Bezel thickness as percentage of screen size
    var bezelThickness: CGFloat {
        switch self.category {
        case .laptop:
            return 0.03
        case .desktop:
            return 0.02
        case .phone:
            return 0.02
        case .tablet:
            return 0.04
        case .watch:
            return 0.08
        case .tv, .generic:
            return 0.01
        }
    }

    /// Corner radius as percentage of screen width
    var cornerRadiusRatio: CGFloat {
        switch self.category {
        case .phone:
            return 0.12
        case .tablet:
            return 0.05
        case .laptop, .desktop:
            return 0.02
        case .watch:
            return 0.25
        case .tv, .generic:
            return 0.01
        }
    }
}

enum DeviceCategory {
    case laptop
    case desktop
    case phone
    case tablet
    case watch
    case tv
    case generic
}

/// Device color variants
enum DeviceColorVariant: String, CaseIterable, Identifiable {
    case spaceBlack = "Space Black"
    case spaceGray = "Space Gray"
    case silver = "Silver"
    case starlight = "Starlight"
    case midnight = "Midnight"
    case gold = "Gold"
    case blue = "Blue"
    case purple = "Purple"
    case pink = "Pink"
    case red = "Red"

    var id: String { rawValue }

    var frameColor: NSColor {
        switch self {
        case .spaceBlack: return NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        case .spaceGray: return NSColor(red: 0.35, green: 0.35, blue: 0.37, alpha: 1.0)
        case .silver: return NSColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1.0)
        case .starlight: return NSColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1.0)
        case .midnight: return NSColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1.0)
        case .gold: return NSColor(red: 0.95, green: 0.88, blue: 0.78, alpha: 1.0)
        case .blue: return NSColor(red: 0.4, green: 0.55, blue: 0.7, alpha: 1.0)
        case .purple: return NSColor(red: 0.6, green: 0.5, blue: 0.65, alpha: 1.0)
        case .pink: return NSColor(red: 0.95, green: 0.75, blue: 0.8, alpha: 1.0)
        case .red: return NSColor(red: 0.85, green: 0.25, blue: 0.25, alpha: 1.0)
        }
    }

    var bezelColor: NSColor {
        switch self {
        case .spaceBlack, .spaceGray, .midnight:
            return .black
        default:
            return NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        }
    }
}

/// Shadow configuration
struct ShadowConfig {
    var color: NSColor = .black
    var opacity: CGFloat = 0.3
    var radius: CGFloat = 30
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 20

    static let `default` = ShadowConfig()
    static let subtle = ShadowConfig(opacity: 0.15, radius: 15, offsetY: 10)
    static let dramatic = ShadowConfig(opacity: 0.5, radius: 50, offsetY: 40)
    static let none = ShadowConfig(opacity: 0, radius: 0, offsetY: 0)
}

/// Background options for device frame
enum FrameBackground {
    case solid(NSColor)
    case gradient(start: NSColor, end: NSColor)
    case image(NSImage)
    case transparent

    func draw(in rect: CGRect, context: CGContext) {
        switch self {
        case .solid(let color):
            context.setFillColor(color.cgColor)
            context.fill(rect)

        case .gradient(let start, let end):
            let colors = [start.cgColor, end.cgColor] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
                context.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: rect.midX, y: rect.minY),
                    end: CGPoint(x: rect.midX, y: rect.maxY),
                    options: []
                )
            }

        case .image(let image):
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: rect)
            }

        case .transparent:
            break
        }
    }
}

/// 3D perspective configuration
struct PerspectiveConfig {
    var rotateX: CGFloat = 0  // Rotation around X axis (degrees)
    var rotateY: CGFloat = 0  // Rotation around Y axis (degrees)
    var rotateZ: CGFloat = 0  // Rotation around Z axis (degrees)
    var perspective: CGFloat = 1000  // Perspective distance

    static let `default` = PerspectiveConfig()
    static let tiltedLeft = PerspectiveConfig(rotateY: -15)
    static let tiltedRight = PerspectiveConfig(rotateY: 15)
    static let floating = PerspectiveConfig(rotateX: 5, rotateY: -5)
}

/// Service for adding device frames to images/videos
class DeviceFrameService {

    static let shared = DeviceFrameService()

    private init() {}

    /// Apply device frame to an image
    func applyFrame(to image: NSImage, config: DeviceFrameConfig) -> NSImage? {
        guard let sourceImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let sourceSize = CGSize(width: sourceImage.width, height: sourceImage.height)
        let frameSize = calculateFrameSize(for: sourceSize, config: config)

        let resultImage = NSImage(size: frameSize)
        resultImage.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            resultImage.unlockFocus()
            return nil
        }

        // Draw background
        config.background.draw(in: CGRect(origin: .zero, size: frameSize), context: context)

        // Calculate device frame rect
        let deviceRect = calculateDeviceRect(in: frameSize, config: config)

        // Apply perspective transform if configured
        if let perspective = config.perspective {
            applyPerspectiveTransform(context: context, rect: deviceRect, config: perspective)
        }

        // Draw shadow if enabled
        if config.addShadow {
            drawShadow(context: context, rect: deviceRect, config: config.shadowConfig)
        }

        // Draw device frame
        drawDeviceFrame(context: context, rect: deviceRect, config: config)

        // Draw screen content
        let screenRect = calculateScreenRect(in: deviceRect, config: config)
        context.saveGState()
        clipToScreenShape(context: context, rect: screenRect, config: config)
        context.draw(sourceImage, in: screenRect)
        context.restoreGState()

        // Draw notch/dynamic island if applicable
        drawNotch(context: context, rect: screenRect, config: config)

        resultImage.unlockFocus()
        return resultImage
    }

    /// Calculate the total frame size including padding
    func calculateFrameSize(for contentSize: CGSize, config: DeviceFrameConfig) -> CGSize {
        let paddingMultiplier = 1.0 + (config.padding * 2)
        let deviceRatio = 1.0 + (config.deviceType.bezelThickness * 2)

        return CGSize(
            width: contentSize.width * deviceRatio * paddingMultiplier,
            height: contentSize.height * deviceRatio * paddingMultiplier
        )
    }

    // MARK: - Private Drawing Methods

    private func calculateDeviceRect(in frameSize: CGSize, config: DeviceFrameConfig) -> CGRect {
        let padding = min(frameSize.width, frameSize.height) * config.padding
        return CGRect(
            x: padding,
            y: padding,
            width: frameSize.width - (padding * 2),
            height: frameSize.height - (padding * 2)
        )
    }

    private func calculateScreenRect(in deviceRect: CGRect, config: DeviceFrameConfig) -> CGRect {
        let bezel = min(deviceRect.width, deviceRect.height) * config.deviceType.bezelThickness
        return deviceRect.insetBy(dx: bezel, dy: bezel)
    }

    private func drawShadow(context: CGContext, rect: CGRect, config: ShadowConfig) {
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: config.offsetX, height: -config.offsetY),
            blur: config.radius,
            color: config.color.withAlphaComponent(config.opacity).cgColor
        )

        context.setFillColor(NSColor.black.cgColor)
        let cornerRadius = min(rect.width, rect.height) * 0.02
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    private func drawDeviceFrame(context: CGContext, rect: CGRect, config: DeviceFrameConfig) {
        let cornerRadius = min(rect.width, rect.height) * config.deviceType.cornerRadiusRatio

        // Draw outer frame
        context.setFillColor(config.colorVariant.frameColor.cgColor)
        let framePath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(framePath)
        context.fillPath()

        // Draw bezel
        let bezel = min(rect.width, rect.height) * config.deviceType.bezelThickness
        let bezelRect = rect.insetBy(dx: bezel * 0.3, dy: bezel * 0.3)
        let innerCornerRadius = cornerRadius * 0.9

        context.setFillColor(config.colorVariant.bezelColor.cgColor)
        let bezelPath = CGPath(roundedRect: bezelRect, cornerWidth: innerCornerRadius, cornerHeight: innerCornerRadius, transform: nil)
        context.addPath(bezelPath)
        context.fillPath()

        // Add camera/sensor for laptops
        if config.deviceType.category == .laptop {
            let cameraSize: CGFloat = 4
            let cameraY = rect.minY + bezel * 0.5
            let cameraX = rect.midX
            context.setFillColor(NSColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0).cgColor)
            context.fillEllipse(in: CGRect(x: cameraX - cameraSize/2, y: cameraY - cameraSize/2, width: cameraSize, height: cameraSize))
        }
    }

    private func clipToScreenShape(context: CGContext, rect: CGRect, config: DeviceFrameConfig) {
        let cornerRadius = min(rect.width, rect.height) * config.deviceType.cornerRadiusRatio * 0.8
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.clip()
    }

    private func drawNotch(context: CGContext, rect: CGRect, config: DeviceFrameConfig) {
        // Draw Dynamic Island for iPhone 14 Pro and later
        if config.deviceType == .iPhone15Pro || config.deviceType == .iPhone15ProMax {
            let islandWidth = rect.width * 0.25
            let islandHeight: CGFloat = 12
            let islandRect = CGRect(
                x: rect.midX - islandWidth / 2,
                y: rect.maxY - islandHeight - 8,
                width: islandWidth,
                height: islandHeight
            )

            context.setFillColor(NSColor.black.cgColor)
            let path = CGPath(roundedRect: islandRect, cornerWidth: islandHeight / 2, cornerHeight: islandHeight / 2, transform: nil)
            context.addPath(path)
            context.fillPath()
        }
    }

    private func applyPerspectiveTransform(context: CGContext, rect: CGRect, config: PerspectiveConfig) {
        // Apply 3D-like transform using CGAffineTransform
        // Note: True 3D would require Core Animation or Metal
        let centerX = rect.midX
        let centerY = rect.midY

        context.translateBy(x: centerX, y: centerY)

        // Apply rotation
        let rotationZ = config.rotateZ * .pi / 180
        context.rotate(by: rotationZ)

        // Simulate perspective with scale
        let scaleX = 1.0 - abs(config.rotateY) / 180 * 0.1
        let scaleY = 1.0 - abs(config.rotateX) / 180 * 0.1
        context.scaleBy(x: scaleX, y: scaleY)

        context.translateBy(x: -centerX, y: -centerY)
    }
}

// MARK: - Video Frame Processor

/// Processes video frames to add device frame
class VideoDeviceFrameProcessor {

    enum ProcessingError: Error {
        case cannotCreateReader
        case cannotCreateWriter
        case cannotAddInput
        case cannotAddOutput
        case noVideoTrack
        case processingFailed(String)
    }

    /// Apply device frame to each frame of a video
    static func processVideo(
        inputURL: URL,
        outputURL: URL,
        config: DeviceFrameConfig,
        progress: ((Double) -> Void)?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try processVideoSync(inputURL: inputURL, outputURL: outputURL, config: config, progress: progress)
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func processVideoSync(
        inputURL: URL,
        outputURL: URL,
        config: DeviceFrameConfig,
        progress: ((Double) -> Void)?
    ) throws {
        let asset = AVAsset(url: inputURL)
        let frameService = DeviceFrameService.shared

        // Get video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw ProcessingError.noVideoTrack
        }

        let duration = asset.duration.seconds
        let naturalSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform

        // Calculate actual size after transform
        let isRotated = transform.a == 0 && transform.d == 0
        let videoSize = isRotated ? CGSize(width: naturalSize.height, height: naturalSize.width) : naturalSize

        // Calculate output size with device frame
        let outputSize = frameService.calculateFrameSize(for: videoSize, config: config)

        // Remove existing output file
        try? FileManager.default.removeItem(at: outputURL)

        // Create asset reader
        guard let reader = try? AVAssetReader(asset: asset) else {
            throw ProcessingError.cannotCreateReader
        }

        let readerSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerSettings)
        readerOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(readerOutput) else {
            throw ProcessingError.cannotAddOutput
        }
        reader.add(readerOutput)

        // Create asset writer
        guard let writer = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw ProcessingError.cannotCreateWriter
        }

        let writerSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 10_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: writerSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(outputSize.width),
            kCVPixelBufferHeightKey as String: Int(outputSize.height)
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard writer.canAdd(writerInput) else {
            throw ProcessingError.cannotAddInput
        }
        writer.add(writerInput)

        // Copy audio track if exists
        var audioWriterInput: AVAssetWriterInput?
        var audioReaderOutput: AVAssetReaderTrackOutput?

        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            if reader.canAdd(audioOutput) {
                reader.add(audioOutput)
                audioReaderOutput = audioOutput
            }

            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            audioInput.expectsMediaDataInRealTime = false
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
                audioWriterInput = audioInput
            }
        }

        // Start reading and writing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        var frameCount = 0
        let estimatedFrameCount = Int(duration * Double(videoTrack.nominalFrameRate))

        // Process video frames
        while reader.status == .reading {
            autoreleasepool {
                if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        // Convert to NSImage
                        if let sourceImage = createNSImage(from: imageBuffer, transform: transform) {
                            // Apply device frame
                            if let framedImage = frameService.applyFrame(to: sourceImage, config: config) {
                                // Convert back to pixel buffer and write
                                if let outputBuffer = createPixelBuffer(from: framedImage, size: outputSize, adaptor: adaptor) {
                                    while !writerInput.isReadyForMoreMediaData {
                                        Thread.sleep(forTimeInterval: 0.01)
                                    }
                                    adaptor.append(outputBuffer, withPresentationTime: presentationTime)
                                }
                            }
                        }
                    }

                    frameCount += 1
                    if frameCount % 10 == 0 {
                        let progressValue = min(1.0, Double(frameCount) / Double(max(1, estimatedFrameCount)))
                        DispatchQueue.main.async {
                            progress?(progressValue * 0.9) // Reserve 10% for audio
                        }
                    }
                }
            }
        }

        // Process audio
        if let audioOutput = audioReaderOutput, let audioInput = audioWriterInput {
            var hasMoreAudio = true
            while hasMoreAudio {
                autoreleasepool {
                    if let audioSample = audioOutput.copyNextSampleBuffer() {
                        while !audioInput.isReadyForMoreMediaData {
                            Thread.sleep(forTimeInterval: 0.01)
                        }
                        audioInput.append(audioSample)
                    } else {
                        hasMoreAudio = false
                    }
                }
            }
        }

        // Finish writing
        writerInput.markAsFinished()
        audioWriterInput?.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        DispatchQueue.main.async {
            progress?(1.0)
        }

        if writer.status != .completed {
            throw ProcessingError.processingFailed(writer.error?.localizedDescription ?? "Unknown error")
        }
    }

    private static func createNSImage(from pixelBuffer: CVPixelBuffer, transform: CGAffineTransform) -> NSImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return nil
        }

        // Apply transform if needed (rotation)
        let isRotated = transform.a == 0 && transform.d == 0
        if isRotated {
            let rotatedSize = CGSize(width: height, height: width)
            let rotatedImage = NSImage(size: rotatedSize)
            rotatedImage.lockFocus()

            let ctx = NSGraphicsContext.current?.cgContext
            ctx?.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)

            if transform.b == 1.0 {
                ctx?.rotate(by: .pi / 2)
            } else {
                ctx?.rotate(by: -.pi / 2)
            }

            ctx?.translateBy(x: -CGFloat(width) / 2, y: -CGFloat(height) / 2)
            ctx?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

            rotatedImage.unlockFocus()
            return rotatedImage
        }

        return NSImage(cgImage: cgImage, size: CGSize(width: width, height: height))
    }

    private static func createPixelBuffer(from image: NSImage, size: CGSize, adaptor: AVAssetWriterInputPixelBufferAdaptor) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { return nil }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)

        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let data = CVPixelBufferGetBaseAddress(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        guard let context = CGContext(
            data: data,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        // Flip for CoreVideo coordinate system
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        // Draw image
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}

// MARK: - Simple Visual Effects Configuration for Export

struct SimpleVisualEffectsConfig {
    var cornerRadius: CGFloat = 12
    var padding: CGFloat = 48
    var shadowEnabled: Bool = true
    var shadowRadius: CGFloat = 30
    var shadowOpacity: Float = 0.4
    var shadowOffset: CGSize = CGSize(width: 0, height: 10)
    var backgroundColor: NSColor = .black
    var gradientEnabled: Bool = true
    var gradientStartColor: NSColor = NSColor(red: 0.2, green: 0.1, blue: 0.3, alpha: 1.0)
    var gradientEndColor: NSColor = NSColor(red: 0.1, green: 0.2, blue: 0.4, alpha: 1.0)

    static let `default` = SimpleVisualEffectsConfig()
}

// MARK: - Video Visual Effects Processor

class VideoVisualEffectsProcessor {

    /// Apply visual effects (corner radius, shadow, padding, background) to video
    static func processVideo(
        inputURL: URL,
        outputURL: URL,
        config: SimpleVisualEffectsConfig,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try processVideoSync(inputURL: inputURL, outputURL: outputURL, config: config, progress: progress)
                DispatchQueue.main.async {
                    completion(.success(outputURL))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    private static func processVideoSync(
        inputURL: URL,
        outputURL: URL,
        config: SimpleVisualEffectsConfig,
        progress: ((Double) -> Void)?
    ) throws {
        let asset = AVAsset(url: inputURL)

        // Get video track
        let videoTracks = asset.tracks(withMediaType: .video)
        guard let videoTrack = videoTracks.first else {
            throw NSError(domain: "VideoVisualEffectsProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "No video track found"])
        }

        let naturalSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform

        // Calculate actual video dimensions (accounting for rotation)
        var videoSize = naturalSize
        if transform.a == 0 && transform.d == 0 {
            videoSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        }

        // Calculate output size with padding
        let totalPadding = config.padding * 2
        let outputSize = CGSize(
            width: videoSize.width + totalPadding,
            height: videoSize.height + totalPadding
        )

        // Setup reader
        let reader = try AVAssetReader(asset: asset)

        let readerSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: readerSettings)
        reader.add(readerOutput)

        // Setup writer
        try? FileManager.default.removeItem(at: outputURL)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 20_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(outputSize.width),
            kCVPixelBufferHeightKey as String: Int(outputSize.height)
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: pixelBufferAttributes)

        writer.add(writerInput)

        // Copy audio track
        var audioWriterInput: AVAssetWriterInput?
        var audioReaderOutput: AVAssetReaderTrackOutput?

        if let audioTrack = asset.tracks(withMediaType: .audio).first {
            let audioOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: nil)
            reader.add(audioOutput)
            audioReaderOutput = audioOutput

            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
            audioInput.expectsMediaDataInRealTime = false
            writer.add(audioInput)
            audioWriterInput = audioInput
        }

        // Start processing
        reader.startReading()
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let duration = asset.duration.seconds
        var frameCount = 0

        // Process video frames
        while reader.status == .reading {
            autoreleasepool {
                if writerInput.isReadyForMoreMediaData,
                   let sampleBuffer = readerOutput.copyNextSampleBuffer() {

                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                    if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                        // Apply visual effects
                        if let processedImage = applyVisualEffects(
                            to: imageBuffer,
                            transform: transform,
                            config: config,
                            outputSize: outputSize,
                            videoSize: videoSize
                        ) {
                            if let processedBuffer = createPixelBuffer(from: processedImage, size: outputSize, adaptor: adaptor) {
                                adaptor.append(processedBuffer, withPresentationTime: presentationTime)
                            }
                        }
                    }

                    frameCount += 1
                    if frameCount % 30 == 0 {
                        let currentProgress = presentationTime.seconds / duration
                        DispatchQueue.main.async {
                            progress?(min(currentProgress, 1.0))
                        }
                    }
                }
            }
        }

        // Process audio
        if let audioOutput = audioReaderOutput, let audioInput = audioWriterInput {
            var hasMoreAudio = true
            while hasMoreAudio && reader.status == .reading {
                autoreleasepool {
                    if audioInput.isReadyForMoreMediaData,
                       let sampleBuffer = audioOutput.copyNextSampleBuffer() {
                        audioInput.append(sampleBuffer)
                    } else {
                        hasMoreAudio = false
                    }
                }
            }
        }

        // Finish
        writerInput.markAsFinished()
        audioWriterInput?.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        if writer.status == .failed {
            throw writer.error ?? NSError(domain: "VideoVisualEffectsProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown error"])
        }
    }

    private static func applyVisualEffects(
        to pixelBuffer: CVPixelBuffer,
        transform: CGAffineTransform,
        config: SimpleVisualEffectsConfig,
        outputSize: CGSize,
        videoSize: CGSize
    ) -> NSImage? {
        // Create NSImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        // Create output image
        let outputImage = NSImage(size: outputSize)
        outputImage.lockFocus()

        guard let ctx = NSGraphicsContext.current?.cgContext else {
            outputImage.unlockFocus()
            return nil
        }

        // Draw background
        if config.gradientEnabled {
            let colors = [config.gradientStartColor.cgColor, config.gradientEndColor.cgColor] as CFArray
            let locations: [CGFloat] = [0.0, 1.0]
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
                ctx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: outputSize.width, y: outputSize.height),
                    options: []
                )
            }
        } else {
            ctx.setFillColor(config.backgroundColor.cgColor)
            ctx.fill(CGRect(origin: .zero, size: outputSize))
        }

        // Calculate video frame position (centered with padding)
        let videoRect = CGRect(
            x: config.padding,
            y: config.padding,
            width: videoSize.width,
            height: videoSize.height
        )

        // Draw shadow if enabled
        if config.shadowEnabled {
            ctx.saveGState()
            ctx.setShadow(
                offset: config.shadowOffset,
                blur: config.shadowRadius,
                color: NSColor.black.withAlphaComponent(CGFloat(config.shadowOpacity)).cgColor
            )

            // Draw shadow shape using CGPath
            let shadowPath = CGPath(roundedRect: videoRect, cornerWidth: config.cornerRadius, cornerHeight: config.cornerRadius, transform: nil)
            ctx.addPath(shadowPath)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillPath()
            ctx.restoreGState()
        }

        // Create clipping path for rounded corners using CGPath
        let clipPath = CGPath(roundedRect: videoRect, cornerWidth: config.cornerRadius, cornerHeight: config.cornerRadius, transform: nil)
        ctx.addPath(clipPath)
        ctx.clip()

        // Handle video rotation
        ctx.saveGState()

        if transform.a == 0 && transform.d == 0 {
            // Video is rotated
            ctx.translateBy(x: config.padding + videoSize.width / 2, y: config.padding + videoSize.height / 2)
            ctx.rotate(by: atan2(transform.b, transform.a))
            ctx.translateBy(x: -CGFloat(height) / 2, y: -CGFloat(width) / 2)
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
        } else {
            // Normal video
            ctx.draw(cgImage, in: videoRect)
        }

        ctx.restoreGState()

        outputImage.unlockFocus()
        return outputImage
    }

    private static func createPixelBuffer(from image: NSImage, size: CGSize, adaptor: AVAssetWriterInputPixelBufferAdaptor) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { return nil }

        var pixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)

        guard let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let data = CVPixelBufferGetBaseAddress(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        guard let context = CGContext(
            data: data,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return nil
        }

        // Flip for CoreVideo coordinate system
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)

        // Draw image
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: CGRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
