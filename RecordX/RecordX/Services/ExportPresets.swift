//
//  ExportPresets.swift
//  RecordX
//
//  Created for RecordX Project
//

import Foundation
import AVFoundation

/// Supported aspect ratios for export
enum AspectRatio: String, CaseIterable, Identifiable {
    case original = "Original"
    case landscape16_9 = "16:9"
    case portrait9_16 = "9:16"
    case square1_1 = "1:1"
    case cinema21_9 = "21:9"
    case portrait4_5 = "4:5"

    var id: String { rawValue }

    var ratio: CGFloat {
        switch self {
        case .original: return 0 // Use source ratio
        case .landscape16_9: return 16.0 / 9.0
        case .portrait9_16: return 9.0 / 16.0
        case .square1_1: return 1.0
        case .cinema21_9: return 21.0 / 9.0
        case .portrait4_5: return 4.0 / 5.0
        }
    }

    var displayName: String {
        switch self {
        case .original: return "Original"
        case .landscape16_9: return "16:9 (Landscape)"
        case .portrait9_16: return "9:16 (Portrait)"
        case .square1_1: return "1:1 (Square)"
        case .cinema21_9: return "21:9 (Cinematic)"
        case .portrait4_5: return "4:5 (Instagram)"
        }
    }

    /// Calculate output size maintaining aspect ratio
    func calculateSize(from sourceSize: CGSize) -> CGSize {
        if self == .original {
            return sourceSize
        }

        let targetRatio = self.ratio
        let sourceRatio = sourceSize.width / sourceSize.height

        var newWidth: CGFloat
        var newHeight: CGFloat

        if sourceRatio > targetRatio {
            // Source is wider - fit to height
            newHeight = sourceSize.height
            newWidth = newHeight * targetRatio
        } else {
            // Source is taller - fit to width
            newWidth = sourceSize.width
            newHeight = newWidth / targetRatio
        }

        // Ensure even dimensions for video encoding
        newWidth = floor(newWidth / 2) * 2
        newHeight = floor(newHeight / 2) * 2

        return CGSize(width: newWidth, height: newHeight)
    }
}

/// Platform-specific export presets
enum ExportPlatform: String, CaseIterable, Identifiable {
    case youtube
    case youtubeShorts
    case tiktok
    case instagram
    case instagramStory
    case twitter
    case linkedin
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .youtube: return "YouTube"
        case .youtubeShorts: return "YouTube Shorts"
        case .tiktok: return "TikTok"
        case .instagram: return "Instagram Feed"
        case .instagramStory: return "Instagram Story"
        case .twitter: return "Twitter/X"
        case .linkedin: return "LinkedIn"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .youtube: return "play.rectangle.fill"
        case .youtubeShorts: return "rectangle.portrait.fill"
        case .tiktok: return "music.note"
        case .instagram: return "camera.fill"
        case .instagramStory: return "rectangle.portrait.fill"
        case .twitter: return "bubble.left.fill"
        case .linkedin: return "briefcase.fill"
        case .custom: return "slider.horizontal.3"
        }
    }

    var preset: ExportPreset {
        switch self {
        case .youtube:
            return ExportPreset(
                name: "YouTube",
                aspectRatio: .landscape16_9,
                resolution: .r1080p,
                frameRate: 60,
                videoBitrate: 12_000_000,
                audioBitrate: 320_000,
                codec: .h264,
                format: .mp4
            )
        case .youtubeShorts:
            return ExportPreset(
                name: "YouTube Shorts",
                aspectRatio: .portrait9_16,
                resolution: .r1080p,
                frameRate: 60,
                videoBitrate: 8_000_000,
                audioBitrate: 256_000,
                codec: .h264,
                format: .mp4
            )
        case .tiktok:
            return ExportPreset(
                name: "TikTok",
                aspectRatio: .portrait9_16,
                resolution: .r1080p,
                frameRate: 30,
                videoBitrate: 6_000_000,
                audioBitrate: 256_000,
                codec: .h264,
                format: .mp4
            )
        case .instagram:
            return ExportPreset(
                name: "Instagram Feed",
                aspectRatio: .square1_1,
                resolution: .r1080p,
                frameRate: 30,
                videoBitrate: 5_000_000,
                audioBitrate: 256_000,
                codec: .h264,
                format: .mp4
            )
        case .instagramStory:
            return ExportPreset(
                name: "Instagram Story",
                aspectRatio: .portrait9_16,
                resolution: .r1080p,
                frameRate: 30,
                videoBitrate: 6_000_000,
                audioBitrate: 256_000,
                codec: .h264,
                format: .mp4
            )
        case .twitter:
            return ExportPreset(
                name: "Twitter/X",
                aspectRatio: .landscape16_9,
                resolution: .r720p,
                frameRate: 30,
                videoBitrate: 5_000_000,
                audioBitrate: 256_000,
                codec: .h264,
                format: .mp4
            )
        case .linkedin:
            return ExportPreset(
                name: "LinkedIn",
                aspectRatio: .landscape16_9,
                resolution: .r1080p,
                frameRate: 30,
                videoBitrate: 8_000_000,
                audioBitrate: 256_000,
                codec: .h264,
                format: .mp4
            )
        case .custom:
            return ExportPreset.default
        }
    }
}

/// Video resolution options
enum VideoResolution: String, CaseIterable, Identifiable {
    case r4K = "4K"
    case r1440p = "1440p"
    case r1080p = "1080p"
    case r720p = "720p"
    case r480p = "480p"

    var id: String { rawValue }

    var height: Int {
        switch self {
        case .r4K: return 2160
        case .r1440p: return 1440
        case .r1080p: return 1080
        case .r720p: return 720
        case .r480p: return 480
        }
    }

    var displayName: String {
        switch self {
        case .r4K: return "4K (2160p)"
        case .r1440p: return "2K (1440p)"
        case .r1080p: return "Full HD (1080p)"
        case .r720p: return "HD (720p)"
        case .r480p: return "SD (480p)"
        }
    }
}

/// Video codec options
enum VideoCodec: String, CaseIterable, Identifiable {
    case h264
    case h265
    case prores

    var id: String { rawValue }

    var avCodecType: AVVideoCodecType {
        switch self {
        case .h264: return .h264
        case .h265: return .hevc
        case .prores: return .proRes422
        }
    }

    var displayName: String {
        switch self {
        case .h264: return "H.264 (Compatible)"
        case .h265: return "H.265/HEVC (Smaller)"
        case .prores: return "ProRes (Quality)"
        }
    }
}

/// Export format options
enum ExportFormat: String, CaseIterable, Identifiable {
    case mp4
    case mov
    case gif
    case webm

    var id: String { rawValue }

    var fileExtension: String { rawValue }

    var avFileType: AVFileType? {
        switch self {
        case .mp4: return .mp4
        case .mov: return .mov
        case .gif: return nil // GIF uses different export path
        case .webm: return nil // WebM needs custom implementation
        }
    }

    var displayName: String {
        switch self {
        case .mp4: return "MP4"
        case .mov: return "MOV"
        case .gif: return "GIF"
        case .webm: return "WebM"
        }
    }
}

/// Complete export preset configuration
struct ExportPreset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var aspectRatio: AspectRatio
    var resolution: VideoResolution
    var frameRate: Int
    var videoBitrate: Int      // bits per second
    var audioBitrate: Int      // bits per second
    var codec: VideoCodec
    var format: ExportFormat

    // Additional options
    var includeAudio: Bool = true
    var normalizeAudio: Bool = true
    var removeNoise: Bool = false
    var addDeviceFrame: Bool = false
    var deviceFrameType: DeviceFrameType = .none

    static let `default` = ExportPreset(
        name: "Default",
        aspectRatio: .original,
        resolution: .r1080p,
        frameRate: 60,
        videoBitrate: 8_000_000,
        audioBitrate: 256_000,
        codec: .h265,
        format: .mp4
    )

    // Codable conformance for custom types
    enum CodingKeys: String, CodingKey {
        case id, name, aspectRatio, resolution, frameRate, videoBitrate, audioBitrate, codec, format
        case includeAudio, normalizeAudio, removeNoise, addDeviceFrame, deviceFrameType
    }

    init(name: String, aspectRatio: AspectRatio, resolution: VideoResolution, frameRate: Int,
         videoBitrate: Int, audioBitrate: Int, codec: VideoCodec, format: ExportFormat) {
        self.name = name
        self.aspectRatio = aspectRatio
        self.resolution = resolution
        self.frameRate = frameRate
        self.videoBitrate = videoBitrate
        self.audioBitrate = audioBitrate
        self.codec = codec
        self.format = format
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aspectRatio = AspectRatio(rawValue: try container.decode(String.self, forKey: .aspectRatio)) ?? .original
        resolution = VideoResolution(rawValue: try container.decode(String.self, forKey: .resolution)) ?? .r1080p
        frameRate = try container.decode(Int.self, forKey: .frameRate)
        videoBitrate = try container.decode(Int.self, forKey: .videoBitrate)
        audioBitrate = try container.decode(Int.self, forKey: .audioBitrate)
        codec = VideoCodec(rawValue: try container.decode(String.self, forKey: .codec)) ?? .h265
        format = ExportFormat(rawValue: try container.decode(String.self, forKey: .format)) ?? .mp4
        includeAudio = try container.decodeIfPresent(Bool.self, forKey: .includeAudio) ?? true
        normalizeAudio = try container.decodeIfPresent(Bool.self, forKey: .normalizeAudio) ?? true
        removeNoise = try container.decodeIfPresent(Bool.self, forKey: .removeNoise) ?? false
        addDeviceFrame = try container.decodeIfPresent(Bool.self, forKey: .addDeviceFrame) ?? false
        deviceFrameType = DeviceFrameType(rawValue: try container.decodeIfPresent(String.self, forKey: .deviceFrameType) ?? "") ?? .none
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(aspectRatio.rawValue, forKey: .aspectRatio)
        try container.encode(resolution.rawValue, forKey: .resolution)
        try container.encode(frameRate, forKey: .frameRate)
        try container.encode(videoBitrate, forKey: .videoBitrate)
        try container.encode(audioBitrate, forKey: .audioBitrate)
        try container.encode(codec.rawValue, forKey: .codec)
        try container.encode(format.rawValue, forKey: .format)
        try container.encode(includeAudio, forKey: .includeAudio)
        try container.encode(normalizeAudio, forKey: .normalizeAudio)
        try container.encode(removeNoise, forKey: .removeNoise)
        try container.encode(addDeviceFrame, forKey: .addDeviceFrame)
        try container.encode(deviceFrameType.rawValue, forKey: .deviceFrameType)
    }

    /// Get video settings dictionary for AVAssetWriter
    func videoSettings(for size: CGSize) -> [String: Any] {
        let outputSize = aspectRatio.calculateSize(from: size)
        let scaledHeight = min(Int(outputSize.height), resolution.height)
        let scaledWidth = Int(CGFloat(scaledHeight) * (outputSize.width / outputSize.height))

        return [
            AVVideoCodecKey: codec.avCodecType,
            AVVideoWidthKey: scaledWidth,
            AVVideoHeightKey: scaledHeight,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoProfileLevelKey: codec == .h265 ? kVTProfileLevel_HEVC_Main_AutoLevel : AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
    }

    /// Get audio settings dictionary for AVAssetWriter
    func audioSettings() -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: audioBitrate
        ]
    }
}

/// Device frame types for mockup export
enum DeviceFrameType: String, CaseIterable, Identifiable, Codable {
    case none = ""
    case macbookPro14 = "MacBook Pro 14\""
    case macbookPro16 = "MacBook Pro 16\""
    case macbookAir = "MacBook Air"
    case iMac = "iMac"
    case studioDisplay = "Studio Display"
    case iPhone15Pro = "iPhone 15 Pro"
    case iPhone15ProMax = "iPhone 15 Pro Max"
    case iPadPro = "iPad Pro"

    var id: String { rawValue }

    var displayName: String {
        rawValue.isEmpty ? "None" : rawValue
    }

    var isLaptop: Bool {
        switch self {
        case .macbookPro14, .macbookPro16, .macbookAir:
            return true
        default:
            return false
        }
    }

    var isMobile: Bool {
        switch self {
        case .iPhone15Pro, .iPhone15ProMax, .iPadPro:
            return true
        default:
            return false
        }
    }
}

/// Manager for saving/loading custom presets
class PresetManager {
    static let shared = PresetManager()

    private let presetsKey = "RecordX.CustomPresets"

    private init() {}

    var customPresets: [ExportPreset] {
        get {
            guard let data = UserDefaults.standard.data(forKey: presetsKey),
                  let presets = try? JSONDecoder().decode([ExportPreset].self, from: data) else {
                return []
            }
            return presets
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: presetsKey)
            }
        }
    }

    func savePreset(_ preset: ExportPreset) {
        var presets = customPresets
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        customPresets = presets
    }

    func deletePreset(_ preset: ExportPreset) {
        customPresets.removeAll { $0.id == preset.id }
    }

    func allPresets() -> [ExportPreset] {
        let platformPresets = ExportPlatform.allCases.filter { $0 != .custom }.map { $0.preset }
        return platformPresets + customPresets
    }
}
