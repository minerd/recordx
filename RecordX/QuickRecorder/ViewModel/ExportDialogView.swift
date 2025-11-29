//
//  ExportDialogView.swift
//  RecordX
//
//  Created for RecordX Project
//

import SwiftUI
import AVFoundation

/// Export dialog for customizing video export options
struct ExportDialogView: View {
    let videoURL: URL
    let onExport: (ExportOptions) -> Void
    let onCancel: () -> Void

    @State private var exportType: ExportType = .video
    @State private var selectedPlatform: String = "youtube"
    @State private var customResolution: String = "1080p"
    @State private var customFrameRate: Int = 30
    @State private var customBitrate: Int = 8000

    // GIF options
    @State private var gifFrameRate: Int = 15
    @State private var gifQuality: Double = 0.8
    @State private var gifMaxWidth: Int = 640
    @State private var gifLoopCount: Int = 0

    // Effects options
    @State private var applyVisualEffects: Bool = false
    @State private var cornerRadius: Double = 12.0
    @State private var padding: Double = 20.0
    @State private var addShadow: Bool = true

    // Device frame options
    @State private var addDeviceFrame: Bool = false
    @State private var deviceType: String = "macbookPro14"
    @State private var deviceColor: String = "spaceBlack"

    // Audio options
    @State private var normalizeAudio: Bool = false
    @State private var reduceNoise: Bool = false

    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var videoInfo: VideoInfo?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Export Recording")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Video Info
                    if let info = videoInfo {
                        GroupBox(label: Label("Source Video", systemImage: "film")) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(videoURL.lastPathComponent)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Text("\(info.resolution) • \(info.duration) • \(info.fileSize)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Export Type
                    GroupBox(label: Label("Export Type", systemImage: "doc.badge.arrow.up")) {
                        Picker("", selection: $exportType) {
                            Text("Video").tag(ExportType.video)
                            Text("GIF").tag(ExportType.gif)
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                    }

                    // Video Export Options
                    if exportType == .video {
                        GroupBox(label: Label("Platform Preset", systemImage: "display")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("", selection: $selectedPlatform) {
                                    Text("YouTube (16:9, 1080p)").tag("youtube")
                                    Text("YouTube Shorts (9:16)").tag("youtubeShorts")
                                    Text("TikTok (9:16)").tag("tiktok")
                                    Text("Instagram Post (1:1)").tag("instagram")
                                    Text("Instagram Story (9:16)").tag("instagramStory")
                                    Text("Twitter/X (16:9)").tag("twitter")
                                    Text("LinkedIn (16:9)").tag("linkedin")
                                    Divider()
                                    Text("Custom...").tag("custom")
                                }
                                .pickerStyle(.menu)

                                if selectedPlatform == "custom" {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading) {
                                            Text("Resolution")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Picker("", selection: $customResolution) {
                                                Text("4K (2160p)").tag("2160p")
                                                Text("1440p").tag("1440p")
                                                Text("1080p").tag("1080p")
                                                Text("720p").tag("720p")
                                                Text("480p").tag("480p")
                                            }
                                            .pickerStyle(.menu)
                                            .frame(width: 120)
                                        }

                                        VStack(alignment: .leading) {
                                            Text("Frame Rate")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Picker("", selection: $customFrameRate) {
                                                Text("24 fps").tag(24)
                                                Text("30 fps").tag(30)
                                                Text("60 fps").tag(60)
                                            }
                                            .pickerStyle(.menu)
                                            .frame(width: 100)
                                        }

                                        VStack(alignment: .leading) {
                                            Text("Bitrate")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Picker("", selection: $customBitrate) {
                                                Text("4 Mbps").tag(4000)
                                                Text("8 Mbps").tag(8000)
                                                Text("16 Mbps").tag(16000)
                                                Text("32 Mbps").tag(32000)
                                            }
                                            .pickerStyle(.menu)
                                            .frame(width: 100)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // GIF Export Options
                    if exportType == .gif {
                        GroupBox(label: Label("GIF Settings", systemImage: "photo.on.rectangle")) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Frame Rate")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $gifFrameRate) {
                                        Text("10 FPS").tag(10)
                                        Text("15 FPS").tag(15)
                                        Text("20 FPS").tag(20)
                                        Text("25 FPS").tag(25)
                                        Text("30 FPS").tag(30)
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 100)
                                    Spacer()
                                }

                                HStack {
                                    Text("Quality")
                                        .frame(width: 100, alignment: .leading)
                                    Slider(value: $gifQuality, in: 0.3...1.0, step: 0.1)
                                        .frame(width: 150)
                                    Text(String(format: "%.0f%%", gifQuality * 100))
                                        .foregroundColor(.secondary)
                                        .frame(width: 40)
                                    Spacer()
                                }

                                HStack {
                                    Text("Max Width")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $gifMaxWidth) {
                                        Text("480px").tag(480)
                                        Text("640px").tag(640)
                                        Text("800px").tag(800)
                                        Text("1024px").tag(1024)
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 100)
                                    Spacer()
                                }

                                HStack {
                                    Text("Loop")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $gifLoopCount) {
                                        Text("Infinite").tag(0)
                                        Text("Once").tag(1)
                                        Text("Twice").tag(2)
                                        Text("3 times").tag(3)
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 100)
                                    Spacer()
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Visual Effects
                    GroupBox(label: Label("Visual Effects", systemImage: "wand.and.stars")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Apply Visual Effects", isOn: $applyVisualEffects)

                            if applyVisualEffects {
                                HStack {
                                    Text("Corner Radius")
                                        .frame(width: 100, alignment: .leading)
                                    Slider(value: $cornerRadius, in: 0...50, step: 2)
                                        .frame(width: 150)
                                    Text(String(format: "%.0fpx", cornerRadius))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50)
                                    Spacer()
                                }

                                HStack {
                                    Text("Padding")
                                        .frame(width: 100, alignment: .leading)
                                    Slider(value: $padding, in: 0...100, step: 5)
                                        .frame(width: 150)
                                    Text(String(format: "%.0fpx", padding))
                                        .foregroundColor(.secondary)
                                        .frame(width: 50)
                                    Spacer()
                                }

                                Toggle("Add Shadow", isOn: $addShadow)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Device Frame
                    GroupBox(label: Label("Device Frame", systemImage: "laptopcomputer")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Wrap in Device Frame", isOn: $addDeviceFrame)

                            if addDeviceFrame {
                                HStack {
                                    Text("Device")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $deviceType) {
                                        Text("MacBook Pro 14\"").tag("macbookPro14")
                                        Text("MacBook Pro 16\"").tag("macbookPro16")
                                        Text("MacBook Air 13\"").tag("macbookAir13")
                                        Text("iMac 24\"").tag("iMac24")
                                        Divider()
                                        Text("iPhone 15 Pro").tag("iPhone15Pro")
                                        Text("iPhone 15 Pro Max").tag("iPhone15ProMax")
                                        Divider()
                                        Text("iPad Pro 13\"").tag("iPadPro13")
                                        Text("iPad Pro 11\"").tag("iPadPro11")
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 160)
                                    Spacer()
                                }

                                HStack {
                                    Text("Color")
                                        .frame(width: 100, alignment: .leading)
                                    Picker("", selection: $deviceColor) {
                                        Text("Space Black").tag("spaceBlack")
                                        Text("Space Gray").tag("spaceGray")
                                        Text("Silver").tag("silver")
                                        Text("Starlight").tag("starlight")
                                        Text("Midnight").tag("midnight")
                                    }
                                    .pickerStyle(.menu)
                                    .frame(width: 120)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Audio Enhancement
                    if exportType == .video {
                        GroupBox(label: Label("Audio Enhancement", systemImage: "waveform")) {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Normalize Audio (LUFS)", isOn: $normalizeAudio)
                                Toggle("Reduce Background Noise", isOn: $reduceNoise)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                if isExporting {
                    ProgressView(value: exportProgress)
                        .frame(width: 200)
                    Text(String(format: "%.0f%%", exportProgress * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Export") {
                    startExport()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isExporting)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 520, height: 650)
        .onAppear {
            loadVideoInfo()
        }
    }

    private func loadVideoInfo() {
        let asset = AVAsset(url: videoURL)

        Task {
            do {
                let duration = try await asset.load(.duration)
                let tracks = try await asset.loadTracks(withMediaType: .video)

                var resolution = "Unknown"
                if let track = tracks.first {
                    let size = try await track.load(.naturalSize)
                    resolution = "\(Int(size.width))x\(Int(size.height))"
                }

                let durationString = formatDuration(CMTimeGetSeconds(duration))
                let fileSize = formatFileSize(videoURL)

                await MainActor.run {
                    videoInfo = VideoInfo(
                        resolution: resolution,
                        duration: durationString,
                        fileSize: fileSize
                    )
                }
            } catch {
                print("Failed to load video info: \(error)")
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatFileSize(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return "Unknown"
        }

        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private func startExport() {
        isExporting = true
        exportProgress = 0.0

        let options = ExportOptions(
            type: exportType,
            platform: selectedPlatform,
            customResolution: customResolution,
            customFrameRate: customFrameRate,
            customBitrate: customBitrate,
            gifFrameRate: gifFrameRate,
            gifQuality: gifQuality,
            gifMaxWidth: gifMaxWidth,
            gifLoopCount: gifLoopCount,
            applyVisualEffects: applyVisualEffects,
            cornerRadius: cornerRadius,
            padding: padding,
            addShadow: addShadow,
            addDeviceFrame: addDeviceFrame,
            deviceType: deviceType,
            deviceColor: deviceColor,
            normalizeAudio: normalizeAudio,
            reduceNoise: reduceNoise
        )

        onExport(options)
    }
}

// MARK: - Supporting Types

enum ExportType {
    case video
    case gif
}

struct ExportOptions {
    let type: ExportType
    let platform: String
    let customResolution: String
    let customFrameRate: Int
    let customBitrate: Int
    let gifFrameRate: Int
    let gifQuality: Double
    let gifMaxWidth: Int
    let gifLoopCount: Int
    let applyVisualEffects: Bool
    let cornerRadius: Double
    let padding: Double
    let addShadow: Bool
    let addDeviceFrame: Bool
    let deviceType: String
    let deviceColor: String
    let normalizeAudio: Bool
    let reduceNoise: Bool
}

struct VideoInfo {
    let resolution: String
    let duration: String
    let fileSize: String
}

// MARK: - Quick Export Button

struct QuickExportButton: View {
    let videoURL: URL
    @State private var showingExportDialog = false

    var body: some View {
        Button(action: {
            showingExportDialog = true
        }) {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $showingExportDialog) {
            ExportDialogView(
                videoURL: videoURL,
                onExport: { options in
                    performExport(options: options)
                    showingExportDialog = false
                },
                onCancel: {
                    showingExportDialog = false
                }
            )
        }
    }

    private func performExport(options: ExportOptions) {
        // This will integrate with the export services
        print("Exporting with options: \(options)")
    }
}

// MARK: - Export Progress View

struct ExportProgressView: View {
    let progress: Double
    let status: String
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)

            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(String(format: "%.0f%%", progress * 100))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Cancel") {
                onCancel()
            }
        }
        .padding()
        .frame(width: 300)
    }
}
