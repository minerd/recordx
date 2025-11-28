//
//  GIFExporter.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import AppKit

/// GIF Export configuration options
struct GIFExportConfig {
    var frameRate: Int = 15           // FPS for GIF (lower = smaller file)
    var loopCount: Int = 0            // 0 = infinite loop
    var quality: CGFloat = 0.8        // 0.0 - 1.0
    var maxWidth: Int = 640           // Max width in pixels
    var startTime: Double = 0         // Start time in seconds
    var duration: Double? = nil       // Duration (nil = full video)
    var speedMultiplier: Double = 1.0 // Playback speed

    static let `default` = GIFExportConfig()
    static let highQuality = GIFExportConfig(frameRate: 24, quality: 1.0, maxWidth: 1280)
    static let smallFile = GIFExportConfig(frameRate: 10, quality: 0.6, maxWidth: 480)
    static let socialMedia = GIFExportConfig(frameRate: 15, quality: 0.8, maxWidth: 540)
}

/// Progress callback for GIF export
typealias GIFExportProgress = (Double) -> Void

/// Completion callback for GIF export
typealias GIFExportCompletion = (Result<URL, GIFExportError>) -> Void

/// Errors that can occur during GIF export
enum GIFExportError: Error, LocalizedError {
    case invalidVideoURL
    case cannotCreateAsset
    case cannotCreateImageGenerator
    case cannotCreateDestination
    case exportFailed(String)
    case cancelled
    case noFramesGenerated

    var errorDescription: String? {
        switch self {
        case .invalidVideoURL:
            return "Invalid video URL provided"
        case .cannotCreateAsset:
            return "Cannot create video asset"
        case .cannotCreateImageGenerator:
            return "Cannot create image generator"
        case .cannotCreateDestination:
            return "Cannot create GIF destination file"
        case .exportFailed(let reason):
            return "Export failed: \(reason)"
        case .cancelled:
            return "Export was cancelled"
        case .noFramesGenerated:
            return "No frames were generated from video"
        }
    }
}

/// Service for exporting videos to GIF format
class GIFExporter {

    static let shared = GIFExporter()

    private var isCancelled = false

    private init() {}

    /// Cancel the current export operation
    func cancel() {
        isCancelled = true
    }

    /// Export a video file to GIF format
    /// - Parameters:
    ///   - videoURL: URL of the source video
    ///   - outputURL: URL for the output GIF (optional, will generate if nil)
    ///   - config: Export configuration
    ///   - progress: Progress callback (0.0 - 1.0)
    ///   - completion: Completion callback with result
    func exportToGIF(
        from videoURL: URL,
        to outputURL: URL? = nil,
        config: GIFExportConfig = .default,
        progress: GIFExportProgress? = nil,
        completion: @escaping GIFExportCompletion
    ) {
        isCancelled = false

        // Validate input
        guard FileManager.default.fileExists(atPath: videoURL.path) else {
            completion(.failure(.invalidVideoURL))
            return
        }

        // Create output URL if not provided
        let finalOutputURL = outputURL ?? generateOutputURL(from: videoURL)

        // Run export on background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            do {
                let url = try self.performExport(
                    from: videoURL,
                    to: finalOutputURL,
                    config: config,
                    progress: progress
                )
                DispatchQueue.main.async {
                    completion(.success(url))
                }
            } catch let error as GIFExportError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.exportFailed(error.localizedDescription)))
                }
            }
        }
    }

    /// Synchronous export (for use with async/await)
    @available(macOS 10.15, *)
    func exportToGIF(
        from videoURL: URL,
        to outputURL: URL? = nil,
        config: GIFExportConfig = .default,
        progress: GIFExportProgress? = nil
    ) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            exportToGIF(from: videoURL, to: outputURL, config: config, progress: progress) { result in
                continuation.resume(with: result)
            }
        }
    }

    // MARK: - Private Methods

    private func generateOutputURL(from videoURL: URL) -> URL {
        let directory = videoURL.deletingLastPathComponent()
        let baseName = videoURL.deletingPathExtension().lastPathComponent
        return directory.appendingPathComponent("\(baseName).gif")
    }

    private func performExport(
        from videoURL: URL,
        to outputURL: URL,
        config: GIFExportConfig,
        progress: GIFExportProgress?
    ) throws -> URL {

        // Create asset
        let asset = AVURLAsset(url: videoURL)

        // Get video duration
        let duration = asset.duration.seconds
        let exportDuration = config.duration ?? (duration - config.startTime)

        // Calculate frame times
        let frameInterval = 1.0 / Double(config.frameRate) / config.speedMultiplier
        var frameTimes: [NSValue] = []
        var currentTime = config.startTime

        while currentTime < config.startTime + exportDuration {
            let cmTime = CMTime(seconds: currentTime, preferredTimescale: 600)
            frameTimes.append(NSValue(time: cmTime))
            currentTime += frameInterval
        }

        guard !frameTimes.isEmpty else {
            throw GIFExportError.noFramesGenerated
        }

        // Create image generator
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        // Calculate scale for max width
        if let videoTrack = asset.tracks(withMediaType: .video).first {
            let naturalSize = videoTrack.naturalSize
            let transform = videoTrack.preferredTransform
            let videoSize = naturalSize.applying(transform)
            let actualWidth = abs(videoSize.width)

            if actualWidth > CGFloat(config.maxWidth) {
                let scale = CGFloat(config.maxWidth) / actualWidth
                generator.maximumSize = CGSize(
                    width: CGFloat(config.maxWidth),
                    height: abs(videoSize.height) * scale
                )
            }
        }

        // Generate frames
        var cgImages: [CGImage] = []
        var completedFrames = 0
        let totalFrames = frameTimes.count

        generator.generateCGImagesAsynchronously(forTimes: frameTimes) { [weak self] requestedTime, image, actualTime, result, error in
            guard let self = self else { return }

            if self.isCancelled {
                generator.cancelAllCGImageGeneration()
                return
            }

            if result == .succeeded, let image = image {
                cgImages.append(image)
            }

            completedFrames += 1
            let currentProgress = Double(completedFrames) / Double(totalFrames) * 0.8 // 80% for frame generation
            DispatchQueue.main.async {
                progress?(currentProgress)
            }
        }

        // Wait for all frames (simple polling approach)
        while cgImages.count < frameTimes.count && !isCancelled {
            Thread.sleep(forTimeInterval: 0.1)
        }

        if isCancelled {
            throw GIFExportError.cancelled
        }

        guard !cgImages.isEmpty else {
            throw GIFExportError.noFramesGenerated
        }

        // Create GIF
        let gifURL = try createGIF(
            from: cgImages,
            to: outputURL,
            frameDelay: frameInterval,
            loopCount: config.loopCount,
            progress: { p in
                DispatchQueue.main.async {
                    progress?(0.8 + p * 0.2) // Last 20% for GIF creation
                }
            }
        )

        return gifURL
    }

    private func createGIF(
        from images: [CGImage],
        to outputURL: URL,
        frameDelay: Double,
        loopCount: Int,
        progress: ((Double) -> Void)?
    ) throws -> URL {

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Create destination
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            images.count,
            nil
        ) else {
            throw GIFExportError.cannotCreateDestination
        }

        // GIF properties
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        // Frame properties
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
            ]
        ]

        // Add frames
        for (index, image) in images.enumerated() {
            if isCancelled {
                throw GIFExportError.cancelled
            }

            CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
            progress?(Double(index + 1) / Double(images.count))
        }

        // Finalize
        guard CGImageDestinationFinalize(destination) else {
            throw GIFExportError.exportFailed("Failed to finalize GIF")
        }

        return outputURL
    }

    /// Get estimated file size for a video with given config
    func estimateFileSize(for videoURL: URL, config: GIFExportConfig) -> Int64? {
        let asset = AVURLAsset(url: videoURL)
        let duration = config.duration ?? asset.duration.seconds
        let frameCount = Int(duration * Double(config.frameRate))

        // Rough estimation: ~50KB per frame at default quality, scaled by config
        let bytesPerFrame = Int64(50_000 * config.quality)
        let scaleFactor = Double(config.maxWidth) / 640.0

        return Int64(Double(frameCount) * Double(bytesPerFrame) * scaleFactor * scaleFactor)
    }
}

// MARK: - Convenience Extensions

extension URL {
    /// Convert video to GIF using default settings
    func toGIF(completion: @escaping GIFExportCompletion) {
        GIFExporter.shared.exportToGIF(from: self, completion: completion)
    }

    /// Convert video to GIF with custom config
    func toGIF(config: GIFExportConfig, completion: @escaping GIFExportCompletion) {
        GIFExporter.shared.exportToGIF(from: self, config: config, completion: completion)
    }
}
