//
//  SmoothCursor.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import CoreGraphics
import AppKit

/// Configuration for cursor smoothing
struct CursorSmoothConfig {
    /// Smoothing intensity (0.0 = no smoothing, 1.0 = maximum smoothing)
    var intensity: Double = 0.7

    /// Minimum distance to trigger smoothing (pixels)
    var minDistance: CGFloat = 5

    /// Maximum interpolation points between cursor positions
    var maxInterpolationPoints: Int = 10

    /// Easing function for cursor movement
    var easingFunction: EasingFunction = .easeInOutCubic

    /// Whether to smooth click animations
    var smoothClicks: Bool = true

    /// Cursor scale factor (1.0 = original size)
    var cursorScale: CGFloat = 1.0

    /// Auto-hide cursor when idle (seconds, 0 = disabled)
    var autoHideDelay: Double = 0

    static let `default` = CursorSmoothConfig()
    static let subtle = CursorSmoothConfig(intensity: 0.3, maxInterpolationPoints: 5)
    static let cinematic = CursorSmoothConfig(intensity: 0.9, maxInterpolationPoints: 15, easingFunction: .easeInOutQuart)
}

/// Easing functions for smooth animations
enum EasingFunction: String, CaseIterable, Identifiable {
    case linear
    case easeInQuad
    case easeOutQuad
    case easeInOutQuad
    case easeInCubic
    case easeOutCubic
    case easeInOutCubic
    case easeInQuart
    case easeOutQuart
    case easeInOutQuart
    case easeInOutExpo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .easeInQuad: return "Ease In (Quad)"
        case .easeOutQuad: return "Ease Out (Quad)"
        case .easeInOutQuad: return "Ease In/Out (Quad)"
        case .easeInCubic: return "Ease In (Cubic)"
        case .easeOutCubic: return "Ease Out (Cubic)"
        case .easeInOutCubic: return "Ease In/Out (Cubic)"
        case .easeInQuart: return "Ease In (Quart)"
        case .easeOutQuart: return "Ease Out (Quart)"
        case .easeInOutQuart: return "Ease In/Out (Quart)"
        case .easeInOutExpo: return "Ease In/Out (Expo)"
        }
    }

    /// Calculate eased value for progress (0.0 - 1.0)
    func ease(_ t: Double) -> Double {
        switch self {
        case .linear:
            return t
        case .easeInQuad:
            return t * t
        case .easeOutQuad:
            return t * (2 - t)
        case .easeInOutQuad:
            return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
        case .easeInCubic:
            return t * t * t
        case .easeOutCubic:
            let t1 = t - 1
            return t1 * t1 * t1 + 1
        case .easeInOutCubic:
            return t < 0.5 ? 4 * t * t * t : (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
        case .easeInQuart:
            return t * t * t * t
        case .easeOutQuart:
            let t1 = t - 1
            return 1 - t1 * t1 * t1 * t1
        case .easeInOutQuart:
            let t1 = t - 1
            return t < 0.5 ? 8 * t * t * t * t : 1 - 8 * t1 * t1 * t1 * t1
        case .easeInOutExpo:
            if t == 0 { return 0 }
            if t == 1 { return 1 }
            return t < 0.5
                ? pow(2, 20 * t - 10) / 2
                : (2 - pow(2, -20 * t + 10)) / 2
        }
    }
}

/// Represents a cursor position with timestamp
struct CursorPoint {
    var position: CGPoint
    var timestamp: TimeInterval
    var isClick: Bool
    var clickType: ClickType

    enum ClickType {
        case none
        case leftDown
        case leftUp
        case rightDown
        case rightUp
        case drag
    }

    init(position: CGPoint, timestamp: TimeInterval = Date().timeIntervalSince1970, isClick: Bool = false, clickType: ClickType = .none) {
        self.position = position
        self.timestamp = timestamp
        self.isClick = isClick
        self.clickType = clickType
    }
}

/// Service for smoothing cursor movements
class CursorSmoother {

    static let shared = CursorSmoother()

    private var rawPoints: [CursorPoint] = []
    private var smoothedPoints: [CursorPoint] = []
    private var config: CursorSmoothConfig = .default

    private init() {}

    /// Configure the smoother
    func configure(_ config: CursorSmoothConfig) {
        self.config = config
    }

    /// Add a raw cursor point
    func addPoint(_ point: CursorPoint) {
        rawPoints.append(point)
    }

    /// Add a raw cursor position
    func addPosition(_ position: CGPoint, isClick: Bool = false, clickType: CursorPoint.ClickType = .none) {
        let point = CursorPoint(position: position, isClick: isClick, clickType: clickType)
        addPoint(point)
    }

    /// Clear all recorded points
    func clear() {
        rawPoints.removeAll()
        smoothedPoints.removeAll()
    }

    /// Process and smooth all recorded points
    func processPoints() -> [CursorPoint] {
        guard rawPoints.count >= 2 else { return rawPoints }

        smoothedPoints.removeAll()
        var previousPoint = rawPoints[0]
        smoothedPoints.append(previousPoint)

        for i in 1..<rawPoints.count {
            let currentPoint = rawPoints[i]
            let distance = hypot(currentPoint.position.x - previousPoint.position.x,
                                currentPoint.position.y - previousPoint.position.y)

            // If distance is small enough, don't smooth
            if distance < config.minDistance {
                smoothedPoints.append(currentPoint)
                previousPoint = currentPoint
                continue
            }

            // Calculate number of interpolation points based on distance and intensity
            let interpolationCount = min(
                config.maxInterpolationPoints,
                max(1, Int(distance * config.intensity / 10))
            )

            // Generate interpolated points
            for j in 1...interpolationCount {
                let progress = Double(j) / Double(interpolationCount + 1)
                let easedProgress = config.easingFunction.ease(progress)

                let interpolatedX = previousPoint.position.x + CGFloat(easedProgress) * (currentPoint.position.x - previousPoint.position.x)
                let interpolatedY = previousPoint.position.y + CGFloat(easedProgress) * (currentPoint.position.y - previousPoint.position.y)

                let interpolatedTimestamp = previousPoint.timestamp + (currentPoint.timestamp - previousPoint.timestamp) * progress

                let interpolatedPoint = CursorPoint(
                    position: CGPoint(x: interpolatedX, y: interpolatedY),
                    timestamp: interpolatedTimestamp,
                    isClick: false,
                    clickType: .none
                )
                smoothedPoints.append(interpolatedPoint)
            }

            smoothedPoints.append(currentPoint)
            previousPoint = currentPoint
        }

        return smoothedPoints
    }

    /// Get smoothed position at a specific timestamp
    func getSmoothedPosition(at timestamp: TimeInterval) -> CGPoint? {
        let points = smoothedPoints.isEmpty ? processPoints() : smoothedPoints
        guard !points.isEmpty else { return nil }

        // Find the two points surrounding the timestamp
        var beforeIndex = 0
        var afterIndex = points.count - 1

        for (index, point) in points.enumerated() {
            if point.timestamp <= timestamp {
                beforeIndex = index
            }
            if point.timestamp >= timestamp && index < afterIndex {
                afterIndex = index
                break
            }
        }

        if beforeIndex == afterIndex {
            return points[beforeIndex].position
        }

        let beforePoint = points[beforeIndex]
        let afterPoint = points[afterIndex]

        // Interpolate between the two points
        let timeDiff = afterPoint.timestamp - beforePoint.timestamp
        let progress = timeDiff > 0 ? (timestamp - beforePoint.timestamp) / timeDiff : 0

        let x = beforePoint.position.x + CGFloat(progress) * (afterPoint.position.x - beforePoint.position.x)
        let y = beforePoint.position.y + CGFloat(progress) * (afterPoint.position.y - beforePoint.position.y)

        return CGPoint(x: x, y: y)
    }

    /// Apply Catmull-Rom spline smoothing for even smoother curves
    func applyCatmullRomSmoothing(tension: CGFloat = 0.5) -> [CursorPoint] {
        guard rawPoints.count >= 4 else { return processPoints() }

        var result: [CursorPoint] = []
        let points = rawPoints

        for i in 0..<points.count - 1 {
            let p0 = i > 0 ? points[i - 1].position : points[i].position
            let p1 = points[i].position
            let p2 = points[i + 1].position
            let p3 = i < points.count - 2 ? points[i + 2].position : points[i + 1].position

            let t0 = points[i].timestamp
            let t1 = points[i + 1].timestamp

            result.append(points[i])

            // Generate intermediate points using Catmull-Rom
            let segments = max(1, Int(config.intensity * 10))
            for j in 1..<segments {
                let t = CGFloat(j) / CGFloat(segments)

                let x = catmullRom(p0.x, p1.x, p2.x, p3.x, t: t, tension: tension)
                let y = catmullRom(p0.y, p1.y, p2.y, p3.y, t: t, tension: tension)
                let timestamp = t0 + (t1 - t0) * Double(t)

                result.append(CursorPoint(
                    position: CGPoint(x: x, y: y),
                    timestamp: timestamp,
                    isClick: false,
                    clickType: .none
                ))
            }
        }

        result.append(points.last!)
        smoothedPoints = result
        return result
    }

    private func catmullRom(_ p0: CGFloat, _ p1: CGFloat, _ p2: CGFloat, _ p3: CGFloat, t: CGFloat, tension: CGFloat) -> CGFloat {
        let t2 = t * t
        let t3 = t2 * t

        let m0 = (1 - tension) * (p2 - p0) / 2
        let m1 = (1 - tension) * (p3 - p1) / 2

        let a = 2 * p1 - 2 * p2 + m0 + m1
        let b = -3 * p1 + 3 * p2 - 2 * m0 - m1
        let c = m0
        let d = p1

        return a * t3 + b * t2 + c * t + d
    }

    /// Remove jitter from cursor movements
    func removeJitter(threshold: CGFloat = 3) -> [CursorPoint] {
        guard rawPoints.count >= 3 else { return rawPoints }

        var filtered: [CursorPoint] = [rawPoints[0]]

        for i in 1..<rawPoints.count - 1 {
            let prev = filtered.last!.position
            let current = rawPoints[i].position
            let next = rawPoints[i + 1].position

            // Check if current point is a jitter (deviation from line between prev and next)
            let lineDirection = CGPoint(x: next.x - prev.x, y: next.y - prev.y)
            let lineLength = hypot(lineDirection.x, lineDirection.y)

            if lineLength > 0 {
                let normalizedLine = CGPoint(x: lineDirection.x / lineLength, y: lineDirection.y / lineLength)
                let toCurrent = CGPoint(x: current.x - prev.x, y: current.y - prev.y)
                let projection = toCurrent.x * normalizedLine.x + toCurrent.y * normalizedLine.y
                let closestPoint = CGPoint(
                    x: prev.x + projection * normalizedLine.x,
                    y: prev.y + projection * normalizedLine.y
                )
                let deviation = hypot(current.x - closestPoint.x, current.y - closestPoint.y)

                // If deviation is small enough, it's probably jitter
                if deviation > threshold || rawPoints[i].isClick {
                    filtered.append(rawPoints[i])
                }
            } else {
                filtered.append(rawPoints[i])
            }
        }

        filtered.append(rawPoints.last!)
        return filtered
    }
}

// MARK: - Click Effect Generator

/// Generates smooth click effect animations
class ClickEffectGenerator {

    /// Generate click ripple effect frames
    static func generateRippleEffect(
        at position: CGPoint,
        color: NSColor = .systemBlue,
        maxRadius: CGFloat = 30,
        frameCount: Int = 10
    ) -> [(CGImage, Double)] {
        var frames: [(CGImage, Double)] = []
        let frameDuration = 0.3 / Double(frameCount)

        for i in 0..<frameCount {
            let progress = Double(i) / Double(frameCount - 1)
            let radius = maxRadius * CGFloat(EasingFunction.easeOutQuad.ease(progress))
            let alpha = CGFloat(1.0 - progress)

            let size = CGSize(width: maxRadius * 2 + 10, height: maxRadius * 2 + 10)
            let image = NSImage(size: size)

            image.lockFocus()
            let context = NSGraphicsContext.current!.cgContext

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            context.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(2)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            context.strokePath()

            image.unlockFocus()

            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                frames.append((cgImage, frameDuration))
            }
        }

        return frames
    }

    /// Generate click highlight effect
    static func generateHighlightEffect(
        at position: CGPoint,
        color: NSColor = .systemYellow,
        size: CGFloat = 20
    ) -> NSImage {
        let imageSize = CGSize(width: size * 2, height: size * 2)
        let image = NSImage(size: imageSize)

        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext

        let center = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)

        // Draw gradient circle
        let colors = [
            color.withAlphaComponent(0.6).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ] as CFArray

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: size,
                options: []
            )
        }

        image.unlockFocus()
        return image
    }
}
