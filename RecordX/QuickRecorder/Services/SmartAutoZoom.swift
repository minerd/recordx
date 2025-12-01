//
//  SmartAutoZoom.swift
//  RecordX
//
//  Professional auto-zoom algorithm with UI detection and smart timing
//

import Foundation
import CoreGraphics
import AppKit
import ScreenCaptureKit
import ApplicationServices

// MARK: - Smart Zoom Configuration

struct SmartZoomConfig {
    // Zoom levels based on element type
    var buttonZoomLevel: CGFloat = 2.5
    var textFieldZoomLevel: CGFloat = 2.0
    var menuZoomLevel: CGFloat = 2.2
    var dialogZoomLevel: CGFloat = 1.8
    var defaultZoomLevel: CGFloat = 2.0

    // Timing
    var animationDuration: Double = 0.4
    var holdDuration: Double = 1.5
    var cooldownDuration: Double = 0.5
    var rapidClickThreshold: Double = 0.15  // Ignore clicks faster than this

    // Behavior
    var enableUIDetection: Bool = true
    var enableSmoothFollow: Bool = true
    var followSpeed: CGFloat = 0.12
    var enableContentAwareZoom: Bool = true

    // Scroll behavior
    var zoomOutOnScroll: Bool = true
    var scrollCooldown: Double = 0.3

    // Padding
    var elementPadding: CGFloat = 30
    var screenEdgePadding: CGFloat = 50

    static let `default` = SmartZoomConfig()
    static let minimal = SmartZoomConfig(
        buttonZoomLevel: 1.8,
        textFieldZoomLevel: 1.5,
        defaultZoomLevel: 1.5,
        animationDuration: 0.3,
        holdDuration: 1.0
    )
    static let cinematic = SmartZoomConfig(
        buttonZoomLevel: 3.0,
        textFieldZoomLevel: 2.5,
        defaultZoomLevel: 2.5,
        animationDuration: 0.6,
        holdDuration: 2.0
    )
}

// MARK: - Detected UI Element

struct DetectedUIElement {
    var frame: CGRect
    var role: String
    var title: String?
    var isInteractive: Bool
    var zoomPriority: Int

    enum ElementType {
        case button
        case textField
        case menu
        case menuItem
        case dialog
        case popover
        case slider
        case checkbox
        case link
        case toolbar
        case unknown
    }

    var elementType: ElementType {
        switch role {
        case "AXButton", "AXPopUpButton": return .button
        case "AXTextField", "AXTextArea", "AXSearchField", "AXComboBox": return .textField
        case "AXMenu", "AXMenuBar": return .menu
        case "AXMenuItem": return .menuItem
        case "AXDialog", "AXSheet": return .dialog
        case "AXPopover": return .popover
        case "AXSlider": return .slider
        case "AXCheckBox", "AXRadioButton": return .checkbox
        case "AXLink": return .link
        case "AXToolbar": return .toolbar
        default: return .unknown
        }
    }
}

// MARK: - Zoom State

enum ZoomState {
    case idle
    case zoomingIn
    case zoomed
    case following
    case zoomingOut
}

// MARK: - Smart Auto Zoom Service

class SmartAutoZoomService: ObservableObject {

    static let shared = SmartAutoZoomService()

    // Published state
    @Published var currentState: ZoomState = .idle
    @Published var currentZoomLevel: CGFloat = 1.0
    @Published var zoomCenter: CGPoint = .zero
    @Published var detectedElement: DetectedUIElement?

    // Configuration
    private var config: SmartZoomConfig = .default

    // Timing state
    private var lastClickTime: TimeInterval = 0
    private var lastScrollTime: TimeInterval = 0
    private var lastZoomTriggerTime: TimeInterval = 0
    private var clickCount: Int = 0
    private var zoomOutTimer: DispatchWorkItem?

    // Animation state
    private var animationStartTime: TimeInterval = 0
    private var animationStartZoom: CGFloat = 1.0
    private var animationTargetZoom: CGFloat = 1.0
    private var animationStartCenter: CGPoint = .zero
    private var animationTargetCenter: CGPoint = .zero
    private var displayLink: CVDisplayLink?

    // Follow state
    private var isFollowing = false
    private var followTimer: Timer?
    private var targetFollowCenter: CGPoint = .zero

    // Monitors
    private var mouseClickMonitor: Any?
    private var mouseMoveMonitor: Any?
    private var scrollMonitor: Any?
    private var keyboardMonitor: Any?

    // Callback
    var onZoomUpdate: ((CGFloat, CGPoint) -> Void)?

    // Event history for smart decisions
    private var recentClicks: [(time: TimeInterval, position: CGPoint)] = []
    private var recentKeys: [(time: TimeInterval, char: String)] = []

    private init() {}

    // MARK: - Configuration

    func configure(_ config: SmartZoomConfig) {
        self.config = config
    }

    // MARK: - Start/Stop Monitoring

    func startMonitoring() {
        print("[SmartZoom] Starting monitoring...")

        // Mouse click monitor
        mouseClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.handleMouseClick(event)
        }

        // Mouse move monitor (for smooth follow)
        if config.enableSmoothFollow {
            startFollowTimer()
        }

        // Scroll monitor
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
        }

        // Keyboard monitor
        keyboardMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyboard(event)
        }
    }

    func stopMonitoring() {
        print("[SmartZoom] Stopping monitoring...")

        if let monitor = mouseClickMonitor {
            NSEvent.removeMonitor(monitor)
            mouseClickMonitor = nil
        }

        if let monitor = mouseMoveMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMoveMonitor = nil
        }

        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }

        if let monitor = keyboardMonitor {
            NSEvent.removeMonitor(monitor)
            keyboardMonitor = nil
        }

        followTimer?.invalidate()
        followTimer = nil

        stopDisplayLink()
        zoomOutTimer?.cancel()
    }

    // MARK: - Mouse Click Handling

    private func handleMouseClick(_ event: NSEvent) {
        let now = Date().timeIntervalSince1970
        let mouseLocation = NSEvent.mouseLocation
        let position = convertToScreenCaptureCoordinates(mouseLocation)

        // Record click for pattern detection
        recentClicks.append((time: now, position: position))
        recentClicks = recentClicks.filter { now - $0.time < 2.0 } // Keep last 2 seconds

        // Check for rapid clicking (spam protection)
        if now - lastClickTime < config.rapidClickThreshold {
            clickCount += 1
            if clickCount > 3 {
                print("[SmartZoom] Rapid clicking detected, ignoring")
                return
            }
        } else {
            clickCount = 1
        }
        lastClickTime = now

        // Check cooldown
        if now - lastZoomTriggerTime < config.cooldownDuration && currentState != .idle {
            // If already zoomed, maybe extend the hold time instead
            if currentState == .zoomed {
                extendZoomHold()
            }
            return
        }

        // Detect UI element at click position
        let element = detectUIElement(at: mouseLocation)

        // Determine if this click should trigger zoom
        if shouldZoomForClick(element: element, position: position) {
            triggerZoom(to: position, element: element, reason: .click)
        }
    }

    // MARK: - Keyboard Handling

    private func handleKeyboard(_ event: NSEvent) {
        let now = Date().timeIntervalSince1970

        // Ignore modifier-only or command shortcuts
        if event.modifierFlags.contains(.command) { return }
        guard let chars = event.characters, !chars.isEmpty else { return }

        // Record key for pattern detection
        recentKeys.append((time: now, char: chars))
        recentKeys = recentKeys.filter { now - $0.time < 2.0 }

        // Only zoom if typing (multiple keys in sequence)
        let recentKeyCount = recentKeys.filter { now - $0.time < 0.5 }.count
        if recentKeyCount < 2 {
            return // Wait for more typing before zooming
        }

        // Check cooldown
        if now - lastZoomTriggerTime < config.cooldownDuration && currentState != .idle {
            if currentState == .zoomed {
                extendZoomHold()
            }
            return
        }

        // Get focused element (text field)
        let mouseLocation = NSEvent.mouseLocation
        let position = convertToScreenCaptureCoordinates(mouseLocation)

        // For keyboard, try to find focused text field
        let focusedElement = detectFocusedElement()

        if let element = focusedElement, element.elementType == .textField {
            let elementCenter = CGPoint(
                x: element.frame.midX,
                y: element.frame.midY
            )
            let convertedCenter = convertToScreenCaptureCoordinates(elementCenter)
            triggerZoom(to: convertedCenter, element: element, reason: .keyboard)
        } else {
            triggerZoom(to: position, element: nil, reason: .keyboard)
        }
    }

    // MARK: - Scroll Handling

    private func handleScroll(_ event: NSEvent) {
        guard config.zoomOutOnScroll else { return }

        let now = Date().timeIntervalSince1970

        // Debounce scroll events
        if now - lastScrollTime < config.scrollCooldown { return }
        lastScrollTime = now

        // If zoomed, zoom out on scroll
        if currentState == .zoomed || currentState == .following {
            print("[SmartZoom] Scroll detected, zooming out")
            animateZoomOut()
        }
    }

    // MARK: - Smooth Follow

    private func startFollowTimer() {
        followTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateFollow()
        }
    }

    private func updateFollow() {
        guard currentState == .zoomed || currentState == .following else { return }
        guard config.enableSmoothFollow else { return }

        let mouseLocation = NSEvent.mouseLocation
        let currentMousePos = convertToScreenCaptureCoordinates(mouseLocation)

        // Check if mouse moved significantly
        let distance = hypot(currentMousePos.x - zoomCenter.x, currentMousePos.y - zoomCenter.y)
        let threshold = (SCContext.originalScreenSize.width / currentZoomLevel) * 0.3

        if distance > threshold {
            // Smoothly follow the cursor
            currentState = .following

            let newX = zoomCenter.x + (currentMousePos.x - zoomCenter.x) * config.followSpeed
            let newY = zoomCenter.y + (currentMousePos.y - zoomCenter.y) * config.followSpeed

            zoomCenter = CGPoint(x: newX, y: newY)
            onZoomUpdate?(currentZoomLevel, zoomCenter)
        }
    }

    // MARK: - UI Element Detection

    private func detectUIElement(at screenPoint: CGPoint) -> DetectedUIElement? {
        guard config.enableUIDetection else { return nil }

        // Use Accessibility API to detect UI element
        let systemWideElement = AXUIElementCreateSystemWide()
        var elementRef: AXUIElement?

        // Get element at position
        let result = AXUIElementCopyElementAtPosition(systemWideElement, Float(screenPoint.x), Float(screenPoint.y), &elementRef)

        guard result == .success, let element = elementRef else {
            return nil
        }

        return extractElementInfo(from: element)
    }

    private func detectFocusedElement() -> DetectedUIElement? {
        guard config.enableUIDetection else { return nil }

        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?

        AXUIElementCopyAttributeValue(systemWideElement, kAXFocusedApplicationAttribute as CFString, &focusedApp)

        guard let app = focusedApp else { return nil }

        var focusedElement: AnyObject?
        AXUIElementCopyAttributeValue(app as! AXUIElement, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard let element = focusedElement else { return nil }

        return extractElementInfo(from: element as! AXUIElement)
    }

    private func extractElementInfo(from element: AXUIElement) -> DetectedUIElement? {
        var role: AnyObject?
        var title: AnyObject?
        var position: AnyObject?
        var size: AnyObject?

        AXUIElementCopyAttributeValue(element, "AXRole" as CFString, &role)
        AXUIElementCopyAttributeValue(element, "AXTitle" as CFString, &title)
        AXUIElementCopyAttributeValue(element, "AXPosition" as CFString, &position)
        AXUIElementCopyAttributeValue(element, "AXSize" as CFString, &size)

        guard let roleStr = role as? String else { return nil }

        var point = CGPoint.zero
        var elementSize = CGSize.zero

        if let posValue = position {
            AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
        }
        if let sizeValue = size {
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &elementSize)
        }

        let rect = CGRect(origin: point, size: elementSize)

        let isInteractive = ["AXButton", "AXTextField", "AXTextArea", "AXCheckBox",
                           "AXRadioButton", "AXSlider", "AXMenuItem", "AXLink",
                           "AXPopUpButton", "AXComboBox", "AXSearchField"].contains(roleStr)

        return DetectedUIElement(
            frame: rect,
            role: roleStr,
            title: title as? String,
            isInteractive: isInteractive,
            zoomPriority: calculateZoomPriority(for: roleStr)
        )
    }

    private func calculateZoomPriority(for role: String) -> Int {
        switch role {
        case "AXTextField", "AXTextArea", "AXSearchField": return 10
        case "AXButton", "AXPopUpButton": return 8
        case "AXMenuItem": return 9
        case "AXCheckBox", "AXRadioButton": return 7
        case "AXSlider": return 6
        case "AXLink": return 5
        default: return 1
        }
    }

    // MARK: - Zoom Decision Logic

    private func shouldZoomForClick(element: DetectedUIElement?, position: CGPoint) -> Bool {
        // Always zoom on interactive elements
        if let element = element, element.isInteractive {
            return true
        }

        // Check click patterns - if user is clicking around rapidly in same area, don't zoom
        let recentClicksInArea = recentClicks.filter { click in
            let distance = hypot(click.position.x - position.x, click.position.y - position.y)
            return distance < 100 && Date().timeIntervalSince1970 - click.time < 1.0
        }

        if recentClicksInArea.count > 2 {
            return false // Too many clicks in same area
        }

        return true
    }

    private func calculateZoomLevel(for element: DetectedUIElement?) -> CGFloat {
        guard config.enableContentAwareZoom, let element = element else {
            return config.defaultZoomLevel
        }

        switch element.elementType {
        case .button:
            // Smaller buttons need more zoom
            let buttonSize = max(element.frame.width, element.frame.height)
            if buttonSize < 30 { return config.buttonZoomLevel * 1.2 }
            if buttonSize < 60 { return config.buttonZoomLevel }
            return config.buttonZoomLevel * 0.8

        case .textField:
            return config.textFieldZoomLevel

        case .menu, .menuItem:
            return config.menuZoomLevel

        case .dialog, .popover:
            return config.dialogZoomLevel

        case .checkbox, .slider:
            return config.buttonZoomLevel * 0.9

        case .link:
            return config.buttonZoomLevel

        default:
            return config.defaultZoomLevel
        }
    }

    private func calculateZoomCenter(for element: DetectedUIElement?, fallback: CGPoint) -> CGPoint {
        guard let element = element else { return fallback }

        // For text fields, center on the field with slight offset for cursor visibility
        if element.elementType == .textField {
            let center = CGPoint(
                x: element.frame.midX + 20, // Slight offset to show cursor
                y: element.frame.midY
            )
            return convertToScreenCaptureCoordinates(center)
        }

        // For menus, show the whole menu
        if element.elementType == .menu || element.elementType == .menuItem {
            return convertToScreenCaptureCoordinates(CGPoint(
                x: element.frame.midX,
                y: element.frame.midY
            ))
        }

        // Default: center on element
        return convertToScreenCaptureCoordinates(CGPoint(
            x: element.frame.midX,
            y: element.frame.midY
        ))
    }

    // MARK: - Zoom Trigger

    enum ZoomReason {
        case click
        case keyboard
        case manual
    }

    private func triggerZoom(to position: CGPoint, element: DetectedUIElement?, reason: ZoomReason) {
        lastZoomTriggerTime = Date().timeIntervalSince1970
        detectedElement = element

        let targetZoom = calculateZoomLevel(for: element)
        let targetCenter = calculateZoomCenter(for: element, fallback: position)

        print("[SmartZoom] Triggering zoom: level=\(targetZoom), reason=\(reason), element=\(element?.role ?? "none")")

        // Cancel any pending zoom out
        zoomOutTimer?.cancel()

        // Animate zoom in
        animateZoom(to: targetCenter, level: targetZoom)

        // Schedule zoom out
        scheduleZoomOut()
    }

    private func extendZoomHold() {
        zoomOutTimer?.cancel()
        scheduleZoomOut()
    }

    private func scheduleZoomOut() {
        zoomOutTimer?.cancel()

        let timer = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.currentState == .zoomed || self.currentState == .following {
                self.animateZoomOut()
            }
        }

        zoomOutTimer = timer
        DispatchQueue.main.asyncAfter(deadline: .now() + config.holdDuration, execute: timer)
    }

    // MARK: - Animation

    private func animateZoom(to position: CGPoint, level: CGFloat) {
        animationStartTime = CACurrentMediaTime()
        animationStartZoom = currentZoomLevel
        animationTargetZoom = level
        animationStartCenter = zoomCenter
        animationTargetCenter = position

        currentState = .zoomingIn
        startDisplayLink()
    }

    private func animateZoomOut() {
        animationStartTime = CACurrentMediaTime()
        animationStartZoom = currentZoomLevel
        animationTargetZoom = 1.0
        animationStartCenter = zoomCenter
        animationTargetCenter = zoomCenter // Stay at same center while zooming out

        currentState = .zoomingOut
        startDisplayLink()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }

        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }

        let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, context) -> CVReturn in
            let service = Unmanaged<SmartAutoZoomService>.fromOpaque(context!).takeUnretainedValue()
            DispatchQueue.main.async {
                service.updateAnimation()
            }
            return kCVReturnSuccess
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(link, callback, pointer)
        CVDisplayLinkStart(link)
    }

    private func stopDisplayLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }

    private func updateAnimation() {
        let now = CACurrentMediaTime()
        let elapsed = now - animationStartTime
        let rawProgress = min(1.0, elapsed / config.animationDuration)

        // Ease in-out cubic
        let progress: Double
        if rawProgress < 0.5 {
            progress = 4 * rawProgress * rawProgress * rawProgress
        } else {
            progress = 1 - pow(-2 * rawProgress + 2, 3) / 2
        }

        // Interpolate
        currentZoomLevel = animationStartZoom + CGFloat(progress) * (animationTargetZoom - animationStartZoom)
        zoomCenter = CGPoint(
            x: animationStartCenter.x + CGFloat(progress) * (animationTargetCenter.x - animationStartCenter.x),
            y: animationStartCenter.y + CGFloat(progress) * (animationTargetCenter.y - animationStartCenter.y)
        )

        onZoomUpdate?(currentZoomLevel, zoomCenter)

        // Check completion
        if rawProgress >= 1.0 {
            stopDisplayLink()

            if animationTargetZoom > 1.0 {
                currentState = .zoomed
            } else {
                currentState = .idle
                detectedElement = nil
            }
        }
    }

    // MARK: - Coordinate Conversion

    private func convertToScreenCaptureCoordinates(_ point: CGPoint) -> CGPoint {
        guard let screen = NSScreen.main else { return point }

        let screenFrame = screen.frame
        let convertedY = screenFrame.height - (point.y - screenFrame.origin.y)
        let convertedX = point.x - screenFrame.origin.x

        return CGPoint(x: convertedX, y: convertedY)
    }
}
