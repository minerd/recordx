//
//  AutoZoom.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit

/// Configuration for automatic zoom behavior
struct AutoZoomConfig {
    /// Whether auto zoom is enabled
    var enabled: Bool = true

    /// Zoom level (1.0 = no zoom, 2.0 = 2x zoom)
    var zoomLevel: CGFloat = 2.0

    /// Duration of zoom animation (seconds)
    var animationDuration: Double = 0.5

    /// How long to hold zoom before zooming out (seconds)
    var holdDuration: Double = 1.5

    /// Easing function for zoom animation
    var easingFunction: EasingFunction = .easeInOutCubic

    /// Whether to zoom on mouse clicks
    var zoomOnClick: Bool = true

    /// Whether to zoom on keyboard shortcuts
    var zoomOnKeyboard: Bool = true

    /// Whether to follow cursor during zoom
    var followCursor: Bool = true

    /// Padding around focus area (pixels)
    var focusPadding: CGFloat = 50

    /// Minimum time between zoom events (seconds)
    var cooldownDuration: Double = 0.3

    static let `default` = AutoZoomConfig()
    static let subtle = AutoZoomConfig(zoomLevel: 1.5, animationDuration: 0.3, holdDuration: 1.0)
    static let dramatic = AutoZoomConfig(zoomLevel: 3.0, animationDuration: 0.7, holdDuration: 2.0)
}

/// Represents a zoom event
struct ZoomEvent {
    var timestamp: TimeInterval
    var position: CGPoint
    var zoomLevel: CGFloat
    var duration: Double
    var type: ZoomEventType

    enum ZoomEventType {
        case click
        case keyboard
        case manual
        case automatic
    }
}

/// Region of interest detected for zooming
struct ZoomRegion {
    var rect: CGRect
    var priority: Int
    var type: RegionType

    enum RegionType {
        case cursor
        case textInput
        case button
        case menu
        case dialog
        case custom
    }
}

/// Service for automatic intelligent zoom during recording
class AutoZoomService {

    static let shared = AutoZoomService()

    private var config: AutoZoomConfig = .default
    private var isZoomedIn = false
    private var currentZoomLevel: CGFloat = 1.0
    private var targetZoomLevel: CGFloat = 1.0
    private var zoomCenter: CGPoint = .zero
    private var lastZoomTime: TimeInterval = 0
    private var zoomEvents: [ZoomEvent] = []

    private var mouseMonitor: Any?
    private var keyboardMonitor: Any?
    private var displayLink: CVDisplayLink?

    private var animationStartTime: TimeInterval = 0
    private var animationStartZoom: CGFloat = 1.0
    private var animationTargetZoom: CGFloat = 1.0
    private var animationStartCenter: CGPoint = .zero
    private var animationTargetCenter: CGPoint = .zero
    private var isAnimating = false

    // Callback for zoom updates
    var onZoomUpdate: ((CGFloat, CGPoint) -> Void)?

    private init() {}

    /// Configure the auto zoom service
    func configure(_ config: AutoZoomConfig) {
        self.config = config
    }

    /// Start monitoring for zoom triggers
    func startMonitoring() {
        guard config.enabled else { return }

        if config.zoomOnClick {
            startMouseMonitoring()
        }

        if config.zoomOnKeyboard {
            startKeyboardMonitoring()
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }

        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }

        stopDisplayLink()
    }

    /// Manually trigger zoom to a position
    func zoomTo(position: CGPoint, level: CGFloat? = nil, animated: Bool = true) {
        let now = Date().timeIntervalSince1970

        // Check cooldown
        guard now - lastZoomTime >= config.cooldownDuration else { return }
        lastZoomTime = now

        let zoomLevel = level ?? config.zoomLevel

        if animated {
            animateZoom(to: position, level: zoomLevel)
        } else {
            currentZoomLevel = zoomLevel
            zoomCenter = position
            isZoomedIn = zoomLevel > 1.0
            onZoomUpdate?(currentZoomLevel, zoomCenter)
        }

        // Record event
        let event = ZoomEvent(
            timestamp: now,
            position: position,
            zoomLevel: zoomLevel,
            duration: config.holdDuration,
            type: .manual
        )
        zoomEvents.append(event)

        // Schedule zoom out
        if isZoomedIn {
            scheduleZoomOut()
        }
    }

    /// Zoom out to normal view
    func zoomOut(animated: Bool = true) {
        if animated {
            animateZoom(to: zoomCenter, level: 1.0)
        } else {
            currentZoomLevel = 1.0
            isZoomedIn = false
            onZoomUpdate?(currentZoomLevel, zoomCenter)
        }
    }

    /// Get all recorded zoom events
    func getZoomEvents() -> [ZoomEvent] {
        return zoomEvents
    }

    /// Clear recorded zoom events
    func clearEvents() {
        zoomEvents.removeAll()
    }

    /// Calculate the visible rect at current zoom level
    func calculateVisibleRect(screenSize: CGSize) -> CGRect {
        let zoomedWidth = screenSize.width / currentZoomLevel
        let zoomedHeight = screenSize.height / currentZoomLevel

        let originX = zoomCenter.x - zoomedWidth / 2
        let originY = zoomCenter.y - zoomedHeight / 2

        return CGRect(
            x: max(0, min(originX, screenSize.width - zoomedWidth)),
            y: max(0, min(originY, screenSize.height - zoomedHeight)),
            width: zoomedWidth,
            height: zoomedHeight
        )
    }

    /// Apply zoom transform to a point
    func transformPoint(_ point: CGPoint, screenSize: CGSize) -> CGPoint {
        let visibleRect = calculateVisibleRect(screenSize: screenSize)

        let x = (point.x - visibleRect.origin.x) * currentZoomLevel
        let y = (point.y - visibleRect.origin.y) * currentZoomLevel

        return CGPoint(x: x, y: y)
    }

    // MARK: - Private Methods

    private func startMouseMonitoring() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.config.enabled else { return }

            let position = NSEvent.mouseLocation
            self.handleClickAt(position: position)
        }
    }

    private func startKeyboardMonitoring() {
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.config.enabled else { return }

            // Zoom on certain keyboard events (typing in text fields, etc.)
            if self.isTypingEvent(event) {
                let position = NSEvent.mouseLocation
                self.handleKeyboardEventAt(position: position)
            }
        }
    }

    private func isTypingEvent(_ event: NSEvent) -> Bool {
        // Check if this is a typing event (letters, numbers, etc.)
        guard let characters = event.characters else { return false }
        return !characters.isEmpty && !event.modifierFlags.contains(.command)
    }

    private func handleClickAt(position: CGPoint) {
        let now = Date().timeIntervalSince1970

        // Check cooldown
        guard now - lastZoomTime >= config.cooldownDuration else { return }

        // Detect region of interest around click
        let region = detectRegionOfInterest(at: position)

        // Calculate optimal zoom center
        let zoomPosition = config.followCursor ? position : region?.rect.center ?? position

        // Trigger zoom
        zoomTo(position: zoomPosition, animated: true)

        // Record event
        let event = ZoomEvent(
            timestamp: now,
            position: zoomPosition,
            zoomLevel: config.zoomLevel,
            duration: config.holdDuration,
            type: .click
        )
        zoomEvents.append(event)
    }

    private func handleKeyboardEventAt(position: CGPoint) {
        let now = Date().timeIntervalSince1970

        guard now - lastZoomTime >= config.cooldownDuration else { return }

        // For keyboard events, zoom to cursor position
        zoomTo(position: position, animated: true)

        let event = ZoomEvent(
            timestamp: now,
            position: position,
            zoomLevel: config.zoomLevel,
            duration: config.holdDuration,
            type: .keyboard
        )
        zoomEvents.append(event)
    }

    private func detectRegionOfInterest(at position: CGPoint) -> ZoomRegion? {
        // Try to detect UI elements at the position
        // This is a simplified implementation - full implementation would use Accessibility APIs

        let cursorRegion = ZoomRegion(
            rect: CGRect(
                x: position.x - config.focusPadding,
                y: position.y - config.focusPadding,
                width: config.focusPadding * 2,
                height: config.focusPadding * 2
            ),
            priority: 1,
            type: .cursor
        )

        return cursorRegion
    }

    private func animateZoom(to position: CGPoint, level: CGFloat) {
        animationStartTime = CACurrentMediaTime()
        animationStartZoom = currentZoomLevel
        animationTargetZoom = level
        animationStartCenter = zoomCenter
        animationTargetCenter = position

        isAnimating = true
        startDisplayLink()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }

        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)

        guard let displayLink = displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { (displayLink, inNow, inOutputTime, flagsIn, flagsOut, context) -> CVReturn in
            let service = Unmanaged<AutoZoomService>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async {
                service.updateAnimation()
            }
            return kCVReturnSuccess
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, pointer)
        CVDisplayLinkStart(displayLink)
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }

    private func updateAnimation() {
        guard isAnimating else { return }

        let now = CACurrentMediaTime()
        let elapsed = now - animationStartTime
        let progress = min(1.0, elapsed / config.animationDuration)

        let easedProgress = config.easingFunction.ease(progress)

        // Interpolate zoom level
        currentZoomLevel = animationStartZoom + CGFloat(easedProgress) * (animationTargetZoom - animationStartZoom)

        // Interpolate center position
        zoomCenter = CGPoint(
            x: animationStartCenter.x + CGFloat(easedProgress) * (animationTargetCenter.x - animationStartCenter.x),
            y: animationStartCenter.y + CGFloat(easedProgress) * (animationTargetCenter.y - animationStartCenter.y)
        )

        // Notify listeners
        onZoomUpdate?(currentZoomLevel, zoomCenter)

        // Check if animation complete
        if progress >= 1.0 {
            isAnimating = false
            isZoomedIn = currentZoomLevel > 1.0
            stopDisplayLink()
        }
    }

    private func scheduleZoomOut() {
        DispatchQueue.main.asyncAfter(deadline: .now() + config.holdDuration) { [weak self] in
            guard let self = self, self.isZoomedIn else { return }
            self.zoomOut(animated: true)
        }
    }
}

// MARK: - CGRect Extension

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}

// MARK: - Zoom Keyframe Generator

/// Generates zoom keyframes for post-processing
class ZoomKeyframeGenerator {

    /// Generate zoom keyframes from zoom events
    static func generateKeyframes(from events: [ZoomEvent], config: AutoZoomConfig) -> [ZoomKeyframe] {
        var keyframes: [ZoomKeyframe] = []

        for event in events {
            // Zoom in keyframe
            keyframes.append(ZoomKeyframe(
                timestamp: event.timestamp,
                zoomLevel: event.zoomLevel,
                centerX: event.position.x,
                centerY: event.position.y,
                interpolation: .easeInOut
            ))

            // Hold keyframe
            keyframes.append(ZoomKeyframe(
                timestamp: event.timestamp + config.animationDuration,
                zoomLevel: event.zoomLevel,
                centerX: event.position.x,
                centerY: event.position.y,
                interpolation: .linear
            ))

            // Zoom out keyframe
            keyframes.append(ZoomKeyframe(
                timestamp: event.timestamp + config.animationDuration + event.duration,
                zoomLevel: 1.0,
                centerX: event.position.x,
                centerY: event.position.y,
                interpolation: .easeInOut
            ))
        }

        return keyframes.sorted { $0.timestamp < $1.timestamp }
    }
}

/// Represents a zoom keyframe for video processing
struct ZoomKeyframe {
    var timestamp: TimeInterval
    var zoomLevel: CGFloat
    var centerX: CGFloat
    var centerY: CGFloat
    var interpolation: KeyframeInterpolation

    enum KeyframeInterpolation {
        case linear
        case easeIn
        case easeOut
        case easeInOut
    }
}
