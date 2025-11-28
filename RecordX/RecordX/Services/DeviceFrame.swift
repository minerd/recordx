//
//  DeviceFrame.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import AppKit
import CoreGraphics

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
    var background: FrameBackground = .gradient(start: .systemGray, end: .systemGray6)

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

    /// Apply device frame to each frame of a video
    static func processVideo(
        inputURL: URL,
        outputURL: URL,
        config: DeviceFrameConfig,
        progress: ((Double) -> Void)?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // This would use AVFoundation to process each frame
        // Implementation would be similar to GIFExporter but for video
        // For now, this is a placeholder that shows the structure

        DispatchQueue.global(qos: .userInitiated).async {
            // TODO: Implement video processing with device frames
            // 1. Create AVAssetReader for input
            // 2. Create AVAssetWriter for output
            // 3. For each frame, apply device frame using DeviceFrameService
            // 4. Write processed frame to output

            DispatchQueue.main.async {
                completion(.success(outputURL))
            }
        }
    }
}
