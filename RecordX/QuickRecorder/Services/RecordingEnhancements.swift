//
//  RecordingEnhancements.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import AppKit
import AVFoundation

/// Central manager for all recording enhancement features
class RecordingEnhancementsManager {

    static let shared = RecordingEnhancementsManager()

    // Services
    private let cursorSmoother = CursorSmoother.shared
    private let autoZoomService = AutoZoomService.shared
    private let smartAutoZoom = SmartAutoZoomService.shared
    private let gifExporter = GIFExporter.shared
    private let audioNormalizer = AudioNormalizer.shared
    private let noiseReducer = NoiseReducer.shared
    private let audioEnhancer = AudioEnhancer.shared
    private let visualEffectsRenderer = VisualEffectsRenderer.shared
    private let deviceFrameService = DeviceFrameService.shared

    // Smart zoom preference
    private var useSmartZoom: Bool { UserDefaults.standard.bool(forKey: "useSmartZoom") }

    // State
    private var isRecording = false
    private var recordingStartTime: Date?

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration

    private var cursorSmoothingEnabled: Bool { UserDefaults.standard.bool(forKey: "cursorSmoothingEnabled") }
    private var cursorSmoothingIntensity: Double { UserDefaults.standard.double(forKey: "cursorSmoothingIntensity") }
    private var cursorSmoothingEasing: String { UserDefaults.standard.string(forKey: "cursorSmoothingEasing") ?? "easeInOutCubic" }
    private var cursorScale: Double { UserDefaults.standard.double(forKey: "cursorScale") }

    private var autoZoomEnabled: Bool { UserDefaults.standard.bool(forKey: "autoZoomEnabled") }
    private var autoZoomLevel: Double { UserDefaults.standard.double(forKey: "autoZoomLevel") }
    private var autoZoomDuration: Double { UserDefaults.standard.double(forKey: "autoZoomDuration") }
    private var autoZoomHoldDuration: Double { UserDefaults.standard.double(forKey: "autoZoomHoldDuration") }
    private var zoomOnClick: Bool { UserDefaults.standard.bool(forKey: "zoomOnClick") }
    private var zoomOnKeyboard: Bool { UserDefaults.standard.bool(forKey: "zoomOnKeyboard") }
    private var zoomFollowCursor: Bool { UserDefaults.standard.bool(forKey: "zoomFollowCursor") }

    private var visualEffectsEnabled: Bool { UserDefaults.standard.bool(forKey: "visualEffectsEnabled") }
    private var effectCornerRadius: Double { UserDefaults.standard.double(forKey: "effectCornerRadius") }
    private var effectPadding: Double { UserDefaults.standard.double(forKey: "effectPadding") }
    private var effectShadowEnabled: Bool { UserDefaults.standard.bool(forKey: "effectShadowEnabled") }
    private var effectShadowRadius: Double { UserDefaults.standard.double(forKey: "effectShadowRadius") }
    private var effectShadowOpacity: Double { UserDefaults.standard.double(forKey: "effectShadowOpacity") }

    private var audioNormalizationEnabled: Bool { UserDefaults.standard.bool(forKey: "audioNormalizationEnabled") }
    private var audioNormalizationTarget: Double { UserDefaults.standard.double(forKey: "audioNormalizationTarget") }
    private var noiseReductionEnabled: Bool { UserDefaults.standard.bool(forKey: "noiseReductionEnabled") }
    private var noiseReductionStrength: Double { UserDefaults.standard.double(forKey: "noiseReductionStrength") }

    private var deviceFrameEnabled: Bool { UserDefaults.standard.bool(forKey: "deviceFrameEnabled") }
    private var deviceFrameType: String { UserDefaults.standard.string(forKey: "deviceFrameType") ?? "macbookPro14" }
    private var deviceFrameColor: String { UserDefaults.standard.string(forKey: "deviceFrameColor") ?? "spaceBlack" }
    private var deviceFrameShadow: Bool { UserDefaults.standard.bool(forKey: "deviceFrameShadow") }

    private func loadConfiguration() {
        // Set default values if not present
        let defaults: [String: Any] = [
            "cursorSmoothingIntensity": 0.7,
            "cursorSmoothingEasing": "easeInOutCubic",
            "cursorScale": 1.0,
            "autoZoomLevel": 2.0,
            "autoZoomDuration": 0.5,
            "autoZoomHoldDuration": 1.5,
            "zoomOnClick": true,
            "zoomOnKeyboard": true,
            "zoomFollowCursor": true,
            "effectCornerRadius": 12.0,
            "effectPadding": 20.0,
            "effectShadowEnabled": true,
            "effectShadowRadius": 30.0,
            "effectShadowOpacity": 0.5,
            "audioNormalizationTarget": -14.0,
            "noiseReductionStrength": 0.5,
            "deviceFrameType": "macbookPro14",
            "deviceFrameColor": "spaceBlack",
            "deviceFrameShadow": true
        ]
        UserDefaults.standard.register(defaults: defaults)
    }

    // MARK: - Recording Lifecycle

    /// Called when recording starts
    func onRecordingStart() {
        isRecording = true
        recordingStartTime = Date()

        // Configure and start cursor smoothing
        if cursorSmoothingEnabled {
            configureCursorSmoothing()
        }

        // Configure and start auto-zoom
        if autoZoomEnabled {
            if useSmartZoom {
                configureSmartAutoZoom()
                smartAutoZoom.startMonitoring()
            } else {
                configureAutoZoom()
                autoZoomService.startMonitoring()
            }
        }

        cursorSmoother.clear()
    }

    /// Called when recording stops
    func onRecordingStop() {
        isRecording = false

        // Stop monitoring services
        autoZoomService.stopMonitoring()
        smartAutoZoom.stopMonitoring()

        // Process cursor data
        if cursorSmoothingEnabled {
            _ = cursorSmoother.processPoints()
        }
    }

    /// Called when recording is paused
    func onRecordingPause() {
        // Stop auto-zoom during pause
        autoZoomService.stopMonitoring()
        smartAutoZoom.stopMonitoring()
    }

    /// Called when recording is resumed
    func onRecordingResume() {
        // Restart auto-zoom on resume
        if autoZoomEnabled {
            if useSmartZoom {
                smartAutoZoom.startMonitoring()
            } else {
                autoZoomService.startMonitoring()
            }
        }
    }

    /// Add cursor position during recording
    func addCursorPosition(_ position: CGPoint, isClick: Bool = false, clickType: CursorPoint.ClickType = .none) {
        if cursorSmoothingEnabled {
            cursorSmoother.addPosition(position, isClick: isClick, clickType: clickType)
        }
    }

    // MARK: - Configuration Helpers

    private func configureCursorSmoothing() {
        let easing = easingFromString(cursorSmoothingEasing)
        let config = CursorSmoothConfig(
            intensity: cursorSmoothingIntensity,
            easingFunction: easing,
            cursorScale: CGFloat(cursorScale)
        )
        cursorSmoother.configure(config)
    }

    private func configureAutoZoom() {
        let config = AutoZoomConfig(
            enabled: true,
            zoomLevel: CGFloat(autoZoomLevel),
            animationDuration: autoZoomDuration,
            holdDuration: autoZoomHoldDuration,
            zoomOnClick: zoomOnClick,
            zoomOnKeyboard: zoomOnKeyboard,
            followCursor: zoomFollowCursor
        )
        autoZoomService.configure(config)

        // Connect zoom updates to SCContext for real-time zoom
        autoZoomService.onZoomUpdate = { level, center in
            SCContext.updateZoom(level: level, center: center)
        }
    }

    private func configureSmartAutoZoom() {
        let config = SmartZoomConfig(
            buttonZoomLevel: CGFloat(autoZoomLevel) * 1.25,
            textFieldZoomLevel: CGFloat(autoZoomLevel),
            menuZoomLevel: CGFloat(autoZoomLevel) * 1.1,
            dialogZoomLevel: CGFloat(autoZoomLevel) * 0.9,
            defaultZoomLevel: CGFloat(autoZoomLevel),
            animationDuration: autoZoomDuration,
            holdDuration: autoZoomHoldDuration,
            cooldownDuration: 0.4,
            enableUIDetection: true,
            enableSmoothFollow: zoomFollowCursor,
            enableContentAwareZoom: true
        )
        smartAutoZoom.configure(config)

        // Connect zoom updates to SCContext for real-time zoom
        smartAutoZoom.onZoomUpdate = { level, center in
            SCContext.updateZoom(level: level, center: center)
        }
    }

    private func easingFromString(_ str: String) -> EasingFunction {
        switch str {
        case "linear": return .linear
        case "easeInOutCubic": return .easeInOutCubic
        case "easeInOutQuart": return .easeInOutQuart
        case "easeInOutExpo": return .easeInOutExpo
        default: return .easeInOutCubic
        }
    }

    // MARK: - Post-Processing

    /// Apply post-processing enhancements to a video file
    func postProcessVideo(
        inputURL: URL,
        outputURL: URL,
        progress: ((Double, String) -> Void)?,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        var currentURL = inputURL
        var tempURLs: [URL] = []
        var currentStep = 0
        let totalSteps = countActiveSteps()

        func updateProgress(_ stepProgress: Double, _ message: String) {
            let overall = (Double(currentStep) + stepProgress) / Double(max(1, totalSteps))
            progress?(overall, message)
        }

        func processNext() {
            // Step 1: Audio Enhancement
            if (audioNormalizationEnabled || noiseReductionEnabled) && currentStep == 0 {
                updateProgress(0, "Enhancing audio...")

                let tempURL = createTempURL(extension: currentURL.pathExtension)
                tempURLs.append(tempURL)

                processAudio(inputURL: currentURL, outputURL: tempURL) { result in
                    switch result {
                    case .success(let url):
                        currentURL = url
                        currentStep += 1
                        updateProgress(1.0, "Audio enhanced")
                        processNext()
                    case .failure(let error):
                        self.cleanup(tempURLs)
                        completion(.failure(error))
                    }
                }
                return
            }

            // Step 2: Visual Effects
            if visualEffectsEnabled {
                let effectStep = audioNormalizationEnabled || noiseReductionEnabled ? 1 : 0
                if currentStep == effectStep {
                    updateProgress(0, "Applying visual effects...")

                    // Visual effects would be applied during frame processing
                    // For now, we'll skip to the final step
                    currentStep += 1
                    processNext()
                    return
                }
            }

            // Step 3: Device Frame
            if deviceFrameEnabled {
                let frameStep = countStepsBefore(.deviceFrame)
                if currentStep == frameStep {
                    updateProgress(0, "Adding device frame...")

                    // Device frame would be applied during video processing
                    currentStep += 1
                    processNext()
                    return
                }
            }

            // Final: Copy to output
            do {
                if currentURL != inputURL {
                    try FileManager.default.copyItem(at: currentURL, to: outputURL)
                } else {
                    try FileManager.default.copyItem(at: inputURL, to: outputURL)
                }
                cleanup(tempURLs)
                completion(.success(outputURL))
            } catch {
                cleanup(tempURLs)
                completion(.failure(error))
            }
        }

        processNext()
    }

    private func processAudio(inputURL: URL, outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        // Extract audio from video, process, and merge back
        // This is a simplified version - full implementation would use AVFoundation

        if audioNormalizationEnabled && noiseReductionEnabled {
            // Use AudioEnhancer for combined processing
            let config = AudioEnhancer.EnhancementConfig(
                normalize: true,
                normalizationConfig: AudioNormalizationConfig(targetLUFS: audioNormalizationTarget),
                reduceNoise: true,
                noiseReductionConfig: NoiseReductionConfig(strength: noiseReductionStrength)
            )

            audioEnhancer.enhance(
                inputURL: inputURL,
                outputURL: outputURL,
                config: config,
                progress: nil,
                completion: completion
            )
        } else if audioNormalizationEnabled {
            let config = AudioNormalizationConfig(targetLUFS: audioNormalizationTarget)
            audioNormalizer.normalize(
                inputURL: inputURL,
                outputURL: outputURL,
                config: config,
                progress: nil,
                completion: completion
            )
        } else if noiseReductionEnabled {
            let config = NoiseReductionConfig(strength: noiseReductionStrength)
            noiseReducer.reduceNoise(
                inputURL: inputURL,
                outputURL: outputURL,
                config: config,
                progress: nil,
                completion: completion
            )
        } else {
            completion(.success(inputURL))
        }
    }

    private enum ProcessingStep {
        case audio
        case visualEffects
        case deviceFrame
    }

    private func countActiveSteps() -> Int {
        var count = 0
        if audioNormalizationEnabled || noiseReductionEnabled { count += 1 }
        if visualEffectsEnabled { count += 1 }
        if deviceFrameEnabled { count += 1 }
        return max(1, count)
    }

    private func countStepsBefore(_ step: ProcessingStep) -> Int {
        var count = 0
        switch step {
        case .audio:
            return 0
        case .visualEffects:
            if audioNormalizationEnabled || noiseReductionEnabled { count += 1 }
            return count
        case .deviceFrame:
            if audioNormalizationEnabled || noiseReductionEnabled { count += 1 }
            if visualEffectsEnabled { count += 1 }
            return count
        }
    }

    private func createTempURL(extension ext: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }

    private func cleanup(_ urls: [URL]) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Visual Effects Application

    /// Build visual effects configuration from current settings
    func buildVisualEffectsConfig() -> VisualEffectsConfig {
        var config = VisualEffectsConfig()
        config.cornerRadius = CGFloat(effectCornerRadius)
        config.padding = PaddingConfig.uniform(CGFloat(effectPadding))
        config.shadow = effectShadowEnabled ? VideoShadowConfig(
            enabled: true,
            opacity: CGFloat(effectShadowOpacity),
            radius: CGFloat(effectShadowRadius)
        ) : .none
        return config
    }

    /// Build device frame configuration from current settings
    func buildDeviceFrameConfig() -> DeviceFrameConfig {
        let deviceType = DeviceType(rawValue: deviceFrameType) ?? .macbookPro14
        let colorVariant = DeviceColorVariant(rawValue: deviceFrameColor) ?? .spaceBlack

        return DeviceFrameConfig(
            deviceType: deviceType,
            colorVariant: colorVariant,
            addShadow: deviceFrameShadow
        )
    }

    /// Apply visual effects to a single frame
    func applyEffectsToFrame(_ image: NSImage) -> NSImage? {
        var result = image

        // Apply visual effects
        if visualEffectsEnabled {
            let config = buildVisualEffectsConfig()
            if let processed = visualEffectsRenderer.applyEffects(to: result, config: config) {
                result = processed
            }
        }

        // Apply device frame
        if deviceFrameEnabled {
            let config = buildDeviceFrameConfig()
            if let framed = deviceFrameService.applyFrame(to: result, config: config) {
                result = framed
            }
        }

        return result
    }

    // MARK: - Export Helpers

    /// Export video as GIF with current settings
    func exportAsGIF(
        inputURL: URL,
        outputURL: URL? = nil,
        progress: ((Double) -> Void)?,
        completion: @escaping GIFExportCompletion
    ) {
        let gifURL = outputURL ?? inputURL.deletingPathExtension().appendingPathExtension("gif")

        let frameRate = UserDefaults.standard.integer(forKey: "gifFrameRate")
        let quality = UserDefaults.standard.double(forKey: "gifQuality")
        let maxWidth = UserDefaults.standard.integer(forKey: "gifMaxWidth")
        let loopCount = UserDefaults.standard.integer(forKey: "gifLoopCount")

        let config = GIFExportConfig(
            frameRate: frameRate > 0 ? frameRate : 15,
            loopCount: loopCount,
            quality: quality > 0 ? CGFloat(quality) : 0.8,
            maxWidth: maxWidth > 0 ? maxWidth : 640
        )

        gifExporter.exportToGIF(
            from: inputURL,
            to: gifURL,
            config: config,
            progress: progress,
            completion: completion
        )
    }

    /// Get zoom keyframes for post-processing
    func getZoomKeyframes() -> [ZoomKeyframe] {
        let events = autoZoomService.getZoomEvents()
        let config = AutoZoomConfig(
            animationDuration: autoZoomDuration,
            holdDuration: autoZoomHoldDuration
        )
        return ZoomKeyframeGenerator.generateKeyframes(from: events, config: config)
    }

    /// Get smoothed cursor points for post-processing
    func getSmoothedCursorPoints() -> [CursorPoint] {
        return cursorSmoother.applyCatmullRomSmoothing()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let recordingEnhancementsConfigChanged = Notification.Name("recordingEnhancementsConfigChanged")
}
