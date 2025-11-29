//
//  StudioEditorView.swift
//  RecordX
//
//  Professional video editor with Screen Studio-like interface
//

import SwiftUI
import AVFoundation
import AVKit

// MARK: - Studio Editor View

struct StudioEditorView: View {
    @StateObject private var editorState = EditorStateManager()
    @State private var selectedPanel: EditorPanel = .canvas

    var body: some View {
        HSplitView {
            // Left: Properties Panel
            PropertiesSidebar(editorState: editorState, selectedPanel: $selectedPanel)
                .frame(minWidth: 280, maxWidth: 320)

            // Center: Preview + Timeline
            VStack(spacing: 0) {
                EditorPreviewArea(editorState: editorState)
                Divider()
                EditorTimeline(editorState: editorState)
                    .frame(height: 160)
            }

            // Right: Export Options
            ExportSidebar(editorState: editorState)
                .frame(minWidth: 240, maxWidth: 280)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Editor Panel Enum

enum EditorPanel: String, CaseIterable {
    case canvas = "Canvas"
    case cursor = "Cursor"
    case zoom = "Zoom"
    case background = "Background"
    case audio = "Audio"

    var icon: String {
        switch self {
        case .canvas: return "rectangle.dashed"
        case .cursor: return "cursorarrow"
        case .zoom: return "plus.magnifyingglass"
        case .background: return "rectangle.fill"
        case .audio: return "waveform"
        }
    }
}

// MARK: - Properties Sidebar

struct PropertiesSidebar: View {
    @ObservedObject var editorState: EditorStateManager
    @Binding var selectedPanel: EditorPanel

    var body: some View {
        VStack(spacing: 0) {
            // Panel Tabs
            HStack(spacing: 0) {
                ForEach(EditorPanel.allCases, id: \.self) { panel in
                    PanelTabButton(panel: panel, isSelected: selectedPanel == panel) {
                        selectedPanel = panel
                    }
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Panel Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedPanel {
                    case .canvas:
                        CanvasPanelContent(editorState: editorState)
                    case .cursor:
                        CursorPanelContent(editorState: editorState)
                    case .zoom:
                        ZoomPanelContent(editorState: editorState)
                    case .background:
                        BackgroundPanelContent(editorState: editorState)
                    case .audio:
                        AudioPanelContent(editorState: editorState)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

struct PanelTabButton: View {
    let panel: EditorPanel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: panel.icon)
                    .font(.system(size: 14))
                Text(panel.rawValue)
                    .font(.system(size: 9, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .accentColor : .secondary)
    }
}

// MARK: - Panel Contents

struct CanvasPanelContent: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PropertySection(title: "Size") {
                HStack {
                    PropertyField(label: "W", value: $editorState.canvasWidth)
                    PropertyField(label: "H", value: $editorState.canvasHeight)
                }

                HStack(spacing: 8) {
                    PresetButton(label: "1080p") {
                        editorState.canvasWidth = 1920
                        editorState.canvasHeight = 1080
                    }
                    PresetButton(label: "4K") {
                        editorState.canvasWidth = 3840
                        editorState.canvasHeight = 2160
                    }
                    PresetButton(label: "Square") {
                        editorState.canvasWidth = 1080
                        editorState.canvasHeight = 1080
                    }
                }
            }

            PropertySection(title: "Padding") {
                Slider(value: $editorState.canvasPadding, in: 0...200, step: 8)
                Text("\(Int(editorState.canvasPadding))px")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            PropertySection(title: "Corner Radius") {
                Slider(value: $editorState.cornerRadius, in: 0...48, step: 4)
                Text("\(Int(editorState.cornerRadius))px")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            PropertySection(title: "Shadow") {
                Toggle("Enable Shadow", isOn: $editorState.shadowEnabled)
                if editorState.shadowEnabled {
                    Slider(value: $editorState.shadowRadius, in: 0...100, step: 5)
                    Text("Radius: \(Int(editorState.shadowRadius))px")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct CursorPanelContent: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PropertySection(title: "Cursor Style") {
                Toggle("Smooth Cursor", isOn: $editorState.smoothCursorEnabled)

                if editorState.smoothCursorEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Smoothness")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $editorState.cursorSmoothness, in: 0.1...1.0, step: 0.1)
                    }
                }
            }

            PropertySection(title: "Cursor Size") {
                Slider(value: $editorState.cursorScale, in: 0.5...3.0, step: 0.1)
                Text("\(String(format: "%.1f", editorState.cursorScale))x")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            PropertySection(title: "Click Effects") {
                Toggle("Show Click Animation", isOn: $editorState.showClickAnimation)
                Toggle("Highlight Clicks", isOn: $editorState.highlightClicks)

                if editorState.highlightClicks {
                    ColorPicker("Click Color", selection: $editorState.clickColor)
                }
            }
        }
    }
}

struct ZoomPanelContent: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PropertySection(title: "Auto Zoom") {
                Toggle("Enable Auto Zoom", isOn: $editorState.autoZoomEnabled)

                if editorState.autoZoomEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Zoom Level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $editorState.zoomLevel, in: 1.0...4.0, step: 0.25)
                        Text("\(String(format: "%.2f", editorState.zoomLevel))x")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            PropertySection(title: "Zoom Animation") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $editorState.zoomDuration, in: 0.1...2.0, step: 0.1)
                    Text("\(String(format: "%.1f", editorState.zoomDuration))s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Picker("Easing", selection: $editorState.zoomEasing) {
                    Text("Linear").tag("linear")
                    Text("Ease In").tag("easeIn")
                    Text("Ease Out").tag("easeOut")
                    Text("Ease In Out").tag("easeInOut")
                }
                .pickerStyle(.menu)
            }

            PropertySection(title: "Keyframes") {
                Text("\(editorState.zoomKeyframes.count) zoom points")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Add Zoom at Playhead") {
                    editorState.addZoomKeyframe()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

struct BackgroundPanelContent: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PropertySection(title: "Background Type") {
                Picker("Type", selection: $editorState.backgroundType) {
                    Text("Solid").tag("solid")
                    Text("Gradient").tag("gradient")
                    Text("Wallpaper").tag("wallpaper")
                    Text("Image").tag("image")
                }
                .pickerStyle(.segmented)
            }

            if editorState.backgroundType == "solid" {
                PropertySection(title: "Color") {
                    ColorPicker("Background Color", selection: $editorState.backgroundColor)
                }
            }

            if editorState.backgroundType == "gradient" {
                PropertySection(title: "Gradient") {
                    ColorPicker("Start Color", selection: $editorState.gradientStartColor)
                    ColorPicker("End Color", selection: $editorState.gradientEndColor)

                    Slider(value: $editorState.gradientAngle, in: 0...360, step: 15)
                    Text("Angle: \(Int(editorState.gradientAngle))°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if editorState.backgroundType == "wallpaper" {
                PropertySection(title: "Wallpaper") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 8) {
                        ForEach(["ventura", "sonoma", "sequoia", "monterey"], id: \.self) { name in
                            WallpaperThumbnail(name: name, isSelected: editorState.selectedWallpaper == name) {
                                editorState.selectedWallpaper = name
                            }
                        }
                    }
                }
            }
        }
    }
}

struct WallpaperThumbnail: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(
                    colors: wallpaperColors(for: name),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    func wallpaperColors(for name: String) -> [Color] {
        switch name {
        case "ventura": return [.purple, .orange]
        case "sonoma": return [.pink, .purple]
        case "sequoia": return [.blue, .cyan]
        case "monterey": return [.blue, .purple]
        default: return [.gray, .gray]
        }
    }
}

struct AudioPanelContent: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PropertySection(title: "System Audio") {
                Toggle("Include System Audio", isOn: $editorState.includeSystemAudio)

                if editorState.includeSystemAudio {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $editorState.systemAudioVolume, in: 0...2, step: 0.1)
                        Text("\(Int(editorState.systemAudioVolume * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            PropertySection(title: "Microphone") {
                Toggle("Include Microphone", isOn: $editorState.includeMicrophone)

                if editorState.includeMicrophone {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Volume")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Slider(value: $editorState.microphoneVolume, in: 0...2, step: 0.1)
                        Text("\(Int(editorState.microphoneVolume * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Noise Reduction", isOn: $editorState.noiseReductionEnabled)
                }
            }

            PropertySection(title: "Audio Effects") {
                Toggle("Normalize Audio", isOn: $editorState.normalizeAudio)
                Toggle("Remove Silence", isOn: $editorState.removeSilence)
            }
        }
    }
}

// MARK: - Property UI Components

struct PropertySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            content
        }
    }
}

struct PropertyField: View {
    let label: String
    @Binding var value: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            TextField("", value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
        }
    }
}

struct PresetButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Editor Preview Area

struct EditorPreviewArea: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        ZStack {
            // Background
            backgroundView

            // Video Preview
            if let videoURL = editorState.videoURL {
                VideoPlayerView(url: videoURL, player: editorState.player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .padding(editorState.canvasPadding / 4)
                    .cornerRadius(editorState.cornerRadius / 2)
                    .shadow(
                        color: editorState.shadowEnabled ? .black.opacity(0.3) : .clear,
                        radius: editorState.shadowRadius / 4
                    )
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Drop a video here or open from library")
                        .foregroundColor(.secondary)

                    Button("Open Video") {
                        editorState.openVideoFile()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            // Playback Controls
            VStack {
                Spacer()
                PlaybackControls(editorState: editorState)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    var backgroundView: some View {
        switch editorState.backgroundType {
        case "solid":
            editorState.backgroundColor
        case "gradient":
            LinearGradient(
                colors: [editorState.gradientStartColor, editorState.gradientEndColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            Color(NSColor.controlBackgroundColor)
        }
    }
}

struct VideoPlayerView: NSViewRepresentable {
    let url: URL
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}

struct PlaybackControls: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        HStack(spacing: 20) {
            Button(action: { editorState.seekBackward() }) {
                Image(systemName: "gobackward.10")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            Button(action: { editorState.togglePlayback() }) {
                Image(systemName: editorState.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
            }
            .buttonStyle(.plain)

            Button(action: { editorState.seekForward() }) {
                Image(systemName: "goforward.10")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(editorState.currentTimeString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)

            Text("/")
                .foregroundColor(.secondary)

            Text(editorState.durationString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Editor Timeline

struct EditorTimeline: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Timeline")
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { editorState.zoomTimelineOut() }) {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(editorState.timelineZoom * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 40)

                    Button(action: { editorState.zoomTimelineIn() }) {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Timeline Content
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Time ruler
                    TimeRuler(duration: editorState.duration, zoom: editorState.timelineZoom)

                    // Video track
                    if editorState.videoURL != nil {
                        VideoTrack(editorState: editorState)
                            .frame(height: 60)
                            .offset(y: 30)
                    }

                    // Zoom keyframes
                    ForEach(editorState.zoomKeyframes) { keyframe in
                        ZoomKeyframeMarker(keyframe: keyframe, duration: editorState.duration, width: geometry.size.width)
                    }

                    // Playhead
                    PlayheadView(position: editorState.playheadPosition(in: geometry.size.width))
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

struct TimeRuler: View {
    let duration: Double
    let zoom: Double

    var body: some View {
        GeometryReader { geometry in
            let tickCount = Int(duration / 5) + 1

            ForEach(0..<tickCount, id: \.self) { i in
                let seconds = i * 5
                let x = CGFloat(seconds) / CGFloat(duration) * geometry.size.width * zoom

                if x <= geometry.size.width {
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.3))
                            .frame(width: 1, height: 8)

                        Text(formatTime(seconds))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                    .position(x: x, y: 12)
                }
            }
        }
        .frame(height: 24)
    }

    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

struct VideoTrack: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.blue.opacity(0.3))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.blue, lineWidth: 1)
            )
            .overlay(
                HStack {
                    Image(systemName: "film")
                        .foregroundColor(.blue)
                    Text("Recording")
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 8)
            )
    }
}

struct ZoomKeyframeMarker: View {
    let keyframe: ZoomKeyframe
    let duration: Double
    let width: CGFloat

    var body: some View {
        let x = CGFloat(keyframe.time / duration) * width

        VStack(spacing: 0) {
            Image(systemName: "diamond.fill")
                .font(.system(size: 10))
                .foregroundColor(.orange)

            Rectangle()
                .fill(Color.orange.opacity(0.5))
                .frame(width: 1)
        }
        .position(x: x, y: 60)
    }
}

struct PlayheadView: View {
    let position: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(Color.red)
                .frame(width: 12, height: 8)

            Rectangle()
                .fill(Color.red)
                .frame(width: 2)
        }
        .position(x: position, y: 60)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Export Sidebar

struct ExportSidebar: View {
    @ObservedObject var editorState: EditorStateManager

    var body: some View {
        VStack(spacing: 0) {
            Text("Export")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PropertySection(title: "Format") {
                        Picker("", selection: $editorState.exportFormat) {
                            Text("MP4 (H.264)").tag("mp4")
                            Text("MP4 (HEVC)").tag("hevc")
                            Text("ProRes").tag("prores")
                            Text("GIF").tag("gif")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    PropertySection(title: "Quality") {
                        Picker("", selection: $editorState.exportQuality) {
                            Text("High (Original)").tag("high")
                            Text("Medium").tag("medium")
                            Text("Low").tag("low")
                            Text("Custom").tag("custom")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        if editorState.exportQuality == "custom" {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bitrate: \(Int(editorState.customBitrate)) Mbps")
                                    .font(.caption)
                                Slider(value: $editorState.customBitrate, in: 1...50, step: 1)
                            }
                        }
                    }

                    PropertySection(title: "Frame Rate") {
                        Picker("", selection: $editorState.exportFrameRate) {
                            Text("Original").tag(0)
                            Text("24 fps").tag(24)
                            Text("30 fps").tag(30)
                            Text("60 fps").tag(60)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }

                    if editorState.exportFormat == "gif" {
                        PropertySection(title: "GIF Options") {
                            Toggle("Loop Forever", isOn: $editorState.gifLoop)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Colors: \(Int(editorState.gifColors))")
                                    .font(.caption)
                                Slider(value: $editorState.gifColors, in: 16...256, step: 16)
                            }
                        }
                    }

                    Spacer()

                    VStack(spacing: 12) {
                        Text("Estimated Size: \(editorState.estimatedFileSize)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: { editorState.exportVideo() }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Editor State Manager

class EditorStateManager: ObservableObject {
    // Video
    @Published var videoURL: URL?
    @Published var player = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 60

    // Canvas
    @Published var canvasWidth = 1920
    @Published var canvasHeight = 1080
    @Published var canvasPadding: Double = 64
    @Published var cornerRadius: Double = 12
    @Published var shadowEnabled = true
    @Published var shadowRadius: Double = 30

    // Cursor
    @Published var smoothCursorEnabled = true
    @Published var cursorSmoothness: Double = 0.5
    @Published var cursorScale: Double = 1.0
    @Published var showClickAnimation = true
    @Published var highlightClicks = true
    @Published var clickColor = Color.blue

    // Zoom
    @Published var autoZoomEnabled = true
    @Published var zoomLevel: Double = 2.0
    @Published var zoomDuration: Double = 0.5
    @Published var zoomEasing = "easeInOut"
    @Published var zoomKeyframes: [ZoomKeyframe] = []

    // Background
    @Published var backgroundType = "gradient"
    @Published var backgroundColor = Color.black
    @Published var gradientStartColor = Color.purple
    @Published var gradientEndColor = Color.blue
    @Published var gradientAngle: Double = 135
    @Published var selectedWallpaper = "ventura"

    // Audio
    @Published var includeSystemAudio = true
    @Published var systemAudioVolume: Double = 1.0
    @Published var includeMicrophone = false
    @Published var microphoneVolume: Double = 1.0
    @Published var noiseReductionEnabled = false
    @Published var normalizeAudio = false
    @Published var removeSilence = false

    // Timeline
    @Published var timelineZoom: Double = 1.0

    // Export
    @Published var exportFormat = "mp4"
    @Published var exportQuality = "high"
    @Published var exportFrameRate = 0
    @Published var customBitrate: Double = 20
    @Published var gifLoop = true
    @Published var gifColors: Double = 256

    var currentTimeString: String {
        formatTime(currentTime)
    }

    var durationString: String {
        formatTime(duration)
    }

    var estimatedFileSize: String {
        let bitrate = exportQuality == "custom" ? customBitrate : (exportQuality == "high" ? 20.0 : exportQuality == "medium" ? 10.0 : 5.0)
        let size = bitrate * duration / 8
        if size > 1000 {
            return String(format: "%.1f GB", size / 1000)
        }
        return String(format: "%.0f MB", size)
    }

    func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func playheadPosition(in width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(currentTime / duration) * width * timelineZoom
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func seekForward() {
        let newTime = min(currentTime + 10, duration)
        currentTime = newTime
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }

    func seekBackward() {
        let newTime = max(currentTime - 10, 0)
        currentTime = newTime
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }

    func zoomTimelineIn() {
        timelineZoom = min(timelineZoom * 1.2, 4.0)
    }

    func zoomTimelineOut() {
        timelineZoom = max(timelineZoom / 1.2, 0.5)
    }

    func addZoomKeyframe() {
        let keyframe = ZoomKeyframe(id: UUID(), time: currentTime, level: zoomLevel, position: .zero)
        zoomKeyframes.append(keyframe)
        zoomKeyframes.sort { $0.time < $1.time }
    }

    func openVideoFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .quickTimeMovie]
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            loadVideo(from: url)
        }
    }

    func loadVideo(from url: URL) {
        videoURL = url
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)

        Task {
            if let duration = try? await asset.load(.duration) {
                await MainActor.run {
                    self.duration = duration.seconds
                }
            }
        }
    }

    func exportVideo() {
        // Export logic would go here
        print("Exporting video with format: \(exportFormat), quality: \(exportQuality)")
    }
}

struct ZoomKeyframe: Identifiable {
    let id: UUID
    let time: Double
    let level: Double
    let position: CGPoint
}
