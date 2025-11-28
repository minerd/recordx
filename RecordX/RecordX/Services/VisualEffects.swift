//
//  VisualEffects.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import AppKit
import CoreGraphics
import CoreImage

// MARK: - Visual Effects Configuration

/// Complete visual styling configuration for video export
struct VisualEffectsConfig {
    /// Background configuration
    var background: BackgroundConfig = .default

    /// Shadow configuration
    var shadow: VideoShadowConfig = .default

    /// Border/stroke configuration
    var border: BorderConfig = .none

    /// Corner radius (0 = square corners)
    var cornerRadius: CGFloat = 12

    /// Padding around the content
    var padding: PaddingConfig = .default

    /// Inset effect (content appears recessed)
    var inset: InsetConfig = .none

    /// Reflection effect
    var reflection: ReflectionConfig = .none

    static let `default` = VisualEffectsConfig()

    static let minimal = VisualEffectsConfig(
        background: .solid(.white),
        shadow: .none,
        cornerRadius: 8,
        padding: .uniform(20)
    )

    static let professional = VisualEffectsConfig(
        background: .gradient(GradientConfig(
            colors: [.systemIndigo, .systemPurple],
            direction: .diagonal
        )),
        shadow: .dramatic,
        cornerRadius: 16,
        padding: .uniform(60)
    )

    static let floating = VisualEffectsConfig(
        background: .transparent,
        shadow: .floating,
        cornerRadius: 20,
        padding: .uniform(80)
    )
}

// MARK: - Background Configuration

enum BackgroundConfig {
    case solid(NSColor)
    case gradient(GradientConfig)
    case image(NSImage, ImageFit)
    case blur(BlurBackgroundConfig)
    case transparent

    static let `default` = BackgroundConfig.gradient(GradientConfig.default)

    enum ImageFit {
        case fill
        case fit
        case stretch
        case tile
    }
}

struct GradientConfig {
    var colors: [NSColor]
    var direction: GradientDirection
    var locations: [CGFloat]?

    static let `default` = GradientConfig(
        colors: [NSColor.systemGray6, NSColor.systemGray5],
        direction: .vertical
    )

    enum GradientDirection {
        case horizontal
        case vertical
        case diagonal
        case radial

        func startEndPoints(in rect: CGRect) -> (start: CGPoint, end: CGPoint) {
            switch self {
            case .horizontal:
                return (CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.maxX, y: rect.midY))
            case .vertical:
                return (CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.midX, y: rect.maxY))
            case .diagonal:
                return (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.maxY))
            case .radial:
                return (CGPoint(x: rect.midX, y: rect.midY), CGPoint(x: rect.maxX, y: rect.maxY))
            }
        }
    }
}

struct BlurBackgroundConfig {
    var sourceImage: NSImage?
    var blurRadius: CGFloat = 30
    var saturation: CGFloat = 1.5
    var brightness: CGFloat = 0.0
}

// MARK: - Shadow Configuration

struct VideoShadowConfig {
    var enabled: Bool = true
    var color: NSColor = .black
    var opacity: CGFloat = 0.25
    var radius: CGFloat = 20
    var offsetX: CGFloat = 0
    var offsetY: CGFloat = 10
    var spread: CGFloat = 0

    static let `default` = VideoShadowConfig()
    static let none = VideoShadowConfig(enabled: false)
    static let subtle = VideoShadowConfig(opacity: 0.15, radius: 10, offsetY: 5)
    static let dramatic = VideoShadowConfig(opacity: 0.4, radius: 40, offsetY: 20)
    static let floating = VideoShadowConfig(opacity: 0.3, radius: 60, offsetY: 30, spread: -10)

    func apply(to context: CGContext, rect: CGRect, cornerRadius: CGFloat) {
        guard enabled else { return }

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: offsetX, height: -offsetY),
            blur: radius,
            color: color.withAlphaComponent(opacity).cgColor
        )

        // Draw the shape that casts the shadow
        let path = CGPath(roundedRect: rect.insetBy(dx: spread, dy: spread),
                         cornerWidth: cornerRadius,
                         cornerHeight: cornerRadius,
                         transform: nil)
        context.addPath(path)
        context.setFillColor(NSColor.black.cgColor)
        context.fillPath()
        context.restoreGState()
    }
}

// MARK: - Border Configuration

struct BorderConfig {
    var enabled: Bool = false
    var color: NSColor = .white
    var width: CGFloat = 2
    var opacity: CGFloat = 1.0
    var style: BorderStyle = .solid

    static let none = BorderConfig()
    static let thin = BorderConfig(enabled: true, width: 1, opacity: 0.5)
    static let medium = BorderConfig(enabled: true, width: 2)
    static let thick = BorderConfig(enabled: true, width: 4)

    enum BorderStyle {
        case solid
        case dashed
        case dotted
    }

    func apply(to context: CGContext, rect: CGRect, cornerRadius: CGFloat) {
        guard enabled else { return }

        context.saveGState()
        context.setStrokeColor(color.withAlphaComponent(opacity).cgColor)
        context.setLineWidth(width)

        switch style {
        case .solid:
            break
        case .dashed:
            context.setLineDash(phase: 0, lengths: [width * 3, width * 2])
        case .dotted:
            context.setLineDash(phase: 0, lengths: [width, width * 2])
        }

        let path = CGPath(roundedRect: rect.insetBy(dx: width/2, dy: width/2),
                         cornerWidth: cornerRadius,
                         cornerHeight: cornerRadius,
                         transform: nil)
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }
}

// MARK: - Padding Configuration

struct PaddingConfig {
    var top: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    var right: CGFloat

    static let `default` = PaddingConfig.uniform(40)
    static let none = PaddingConfig(top: 0, bottom: 0, left: 0, right: 0)

    static func uniform(_ value: CGFloat) -> PaddingConfig {
        return PaddingConfig(top: value, bottom: value, left: value, right: value)
    }

    static func symmetric(horizontal: CGFloat, vertical: CGFloat) -> PaddingConfig {
        return PaddingConfig(top: vertical, bottom: vertical, left: horizontal, right: horizontal)
    }

    var horizontal: CGFloat { left + right }
    var vertical: CGFloat { top + bottom }
}

// MARK: - Inset Configuration

struct InsetConfig {
    var enabled: Bool = false
    var depth: CGFloat = 3
    var lightAngle: CGFloat = 135 // degrees, 0 = right, 90 = top
    var highlightColor: NSColor = .white
    var shadowColor: NSColor = .black
    var highlightOpacity: CGFloat = 0.3
    var shadowOpacity: CGFloat = 0.3

    static let none = InsetConfig()
    static let subtle = InsetConfig(enabled: true, depth: 2, highlightOpacity: 0.2, shadowOpacity: 0.2)
    static let deep = InsetConfig(enabled: true, depth: 5, highlightOpacity: 0.4, shadowOpacity: 0.4)
}

// MARK: - Reflection Configuration

struct ReflectionConfig {
    var enabled: Bool = false
    var opacity: CGFloat = 0.3
    var height: CGFloat = 0.3 // Percentage of original height
    var fadeLength: CGFloat = 0.5 // How quickly it fades

    static let none = ReflectionConfig()
    static let subtle = ReflectionConfig(enabled: true, opacity: 0.2, height: 0.2)
    static let standard = ReflectionConfig(enabled: true, opacity: 0.3, height: 0.3)
}

// MARK: - Visual Effects Renderer

/// Renders visual effects onto images and video frames
class VisualEffectsRenderer {

    static let shared = VisualEffectsRenderer()

    private init() {}

    /// Apply visual effects to an image
    func applyEffects(to image: NSImage, config: VisualEffectsConfig) -> NSImage? {
        guard let sourceImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let sourceSize = CGSize(width: sourceImage.width, height: sourceImage.height)
        let outputSize = calculateOutputSize(for: sourceSize, config: config)

        let result = NSImage(size: outputSize)
        result.lockFocus()

        guard let context = NSGraphicsContext.current?.cgContext else {
            result.unlockFocus()
            return nil
        }

        // Draw background
        drawBackground(context: context, rect: CGRect(origin: .zero, size: outputSize), config: config.background)

        // Calculate content rect
        let contentRect = CGRect(
            x: config.padding.left,
            y: config.padding.bottom,
            width: sourceSize.width,
            height: sourceSize.height
        )

        // Draw shadow
        config.shadow.apply(to: context, rect: contentRect, cornerRadius: config.cornerRadius)

        // Draw content with corner radius
        context.saveGState()
        let clipPath = CGPath(roundedRect: contentRect,
                             cornerWidth: config.cornerRadius,
                             cornerHeight: config.cornerRadius,
                             transform: nil)
        context.addPath(clipPath)
        context.clip()
        context.draw(sourceImage, in: contentRect)
        context.restoreGState()

        // Draw border
        config.border.apply(to: context, rect: contentRect, cornerRadius: config.cornerRadius)

        // Draw inset effect
        if config.inset.enabled {
            drawInset(context: context, rect: contentRect, config: config.inset, cornerRadius: config.cornerRadius)
        }

        // Draw reflection
        if config.reflection.enabled {
            drawReflection(context: context, image: sourceImage, rect: contentRect, config: config.reflection, cornerRadius: config.cornerRadius)
        }

        result.unlockFocus()
        return result
    }

    /// Calculate output size including padding
    func calculateOutputSize(for sourceSize: CGSize, config: VisualEffectsConfig) -> CGSize {
        return CGSize(
            width: sourceSize.width + config.padding.horizontal,
            height: sourceSize.height + config.padding.vertical
        )
    }

    // MARK: - Private Drawing Methods

    private func drawBackground(context: CGContext, rect: CGRect, config: BackgroundConfig) {
        switch config {
        case .solid(let color):
            context.setFillColor(color.cgColor)
            context.fill(rect)

        case .gradient(let gradientConfig):
            drawGradient(context: context, rect: rect, config: gradientConfig)

        case .image(let image, let fit):
            drawImageBackground(context: context, rect: rect, image: image, fit: fit)

        case .blur(let blurConfig):
            drawBlurredBackground(context: context, rect: rect, config: blurConfig)

        case .transparent:
            break
        }
    }

    private func drawGradient(context: CGContext, rect: CGRect, config: GradientConfig) {
        let colors = config.colors.map { $0.cgColor } as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        let locations = config.locations ?? config.colors.enumerated().map { CGFloat($0.offset) / CGFloat(config.colors.count - 1) }

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else { return }

        let (start, end) = config.direction.startEndPoints(in: rect)

        if config.direction == .radial {
            context.drawRadialGradient(
                gradient,
                startCenter: start,
                startRadius: 0,
                endCenter: start,
                endRadius: max(rect.width, rect.height),
                options: []
            )
        } else {
            context.drawLinearGradient(gradient, start: start, end: end, options: [])
        }
    }

    private func drawImageBackground(context: CGContext, rect: CGRect, image: NSImage, fit: BackgroundConfig.ImageFit) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        var drawRect = rect

        switch fit {
        case .fill:
            let scale = max(rect.width / imageSize.width, rect.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            drawRect = CGRect(
                x: rect.midX - scaledSize.width / 2,
                y: rect.midY - scaledSize.height / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )

        case .fit:
            let scale = min(rect.width / imageSize.width, rect.height / imageSize.height)
            let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
            drawRect = CGRect(
                x: rect.midX - scaledSize.width / 2,
                y: rect.midY - scaledSize.height / 2,
                width: scaledSize.width,
                height: scaledSize.height
            )

        case .stretch:
            drawRect = rect

        case .tile:
            context.saveGState()
            context.clip(to: rect)
            var x: CGFloat = 0
            while x < rect.width {
                var y: CGFloat = 0
                while y < rect.height {
                    context.draw(cgImage, in: CGRect(x: x, y: y, width: imageSize.width, height: imageSize.height))
                    y += imageSize.height
                }
                x += imageSize.width
            }
            context.restoreGState()
            return
        }

        context.draw(cgImage, in: drawRect)
    }

    private func drawBlurredBackground(context: CGContext, rect: CGRect, config: BlurBackgroundConfig) {
        guard let sourceImage = config.sourceImage,
              let cgImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }

        let ciImage = CIImage(cgImage: cgImage)
        let ciContext = CIContext()

        // Apply blur
        guard let blurFilter = CIFilter(name: "CIGaussianBlur") else { return }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(config.blurRadius, forKey: kCIInputRadiusKey)

        guard var outputImage = blurFilter.outputImage else { return }

        // Apply saturation if needed
        if config.saturation != 1.0 {
            guard let saturationFilter = CIFilter(name: "CIColorControls") else { return }
            saturationFilter.setValue(outputImage, forKey: kCIInputImageKey)
            saturationFilter.setValue(config.saturation, forKey: kCIInputSaturationKey)
            saturationFilter.setValue(config.brightness, forKey: kCIInputBrightnessKey)
            if let result = saturationFilter.outputImage {
                outputImage = result
            }
        }

        // Render to context
        if let blurredCGImage = ciContext.createCGImage(outputImage, from: ciImage.extent) {
            context.draw(blurredCGImage, in: rect)
        }
    }

    private func drawInset(context: CGContext, rect: CGRect, config: InsetConfig, cornerRadius: CGFloat) {
        let angleRad = config.lightAngle * .pi / 180

        // Top/left highlight
        context.saveGState()
        let highlightPath = CGMutablePath()
        highlightPath.move(to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius))
        highlightPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        highlightPath.addArc(center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                            radius: cornerRadius, startAngle: .pi, endAngle: .pi * 1.5, clockwise: false)
        highlightPath.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))

        context.addPath(highlightPath)
        context.setStrokeColor(config.highlightColor.withAlphaComponent(config.highlightOpacity).cgColor)
        context.setLineWidth(config.depth)
        context.strokePath()
        context.restoreGState()

        // Bottom/right shadow
        context.saveGState()
        let shadowPath = CGMutablePath()
        shadowPath.move(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius))
        shadowPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        shadowPath.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                         radius: cornerRadius, startAngle: 0, endAngle: .pi / 2, clockwise: false)
        shadowPath.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))

        context.addPath(shadowPath)
        context.setStrokeColor(config.shadowColor.withAlphaComponent(config.shadowOpacity).cgColor)
        context.setLineWidth(config.depth)
        context.strokePath()
        context.restoreGState()
    }

    private func drawReflection(context: CGContext, image: CGImage, rect: CGRect, config: ReflectionConfig, cornerRadius: CGFloat) {
        let reflectionHeight = rect.height * config.height
        let reflectionRect = CGRect(
            x: rect.minX,
            y: rect.minY - reflectionHeight - 5,
            width: rect.width,
            height: reflectionHeight
        )

        context.saveGState()

        // Clip to rounded rect
        let clipPath = CGPath(roundedRect: reflectionRect,
                             cornerWidth: cornerRadius,
                             cornerHeight: cornerRadius,
                             transform: nil)
        context.addPath(clipPath)
        context.clip()

        // Flip and draw
        context.translateBy(x: 0, y: reflectionRect.minY + reflectionRect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.setAlpha(config.opacity)

        // Draw the flipped image
        context.draw(image, in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height))

        // Apply gradient fade
        let fadeColors = [
            NSColor.white.withAlphaComponent(1.0).cgColor,
            NSColor.white.withAlphaComponent(0.0).cgColor
        ] as CFArray

        if let fadeGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: fadeColors, locations: [0, config.fadeLength]) {
            context.setBlendMode(.destinationIn)
            context.drawLinearGradient(
                fadeGradient,
                start: CGPoint(x: reflectionRect.midX, y: reflectionRect.maxY),
                end: CGPoint(x: reflectionRect.midX, y: reflectionRect.minY),
                options: []
            )
        }

        context.restoreGState()
    }
}
