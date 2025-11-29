//
//  StudioEditorView.swift
//  RecordX
//
//  Professional video editor with Screen Studio-like interface
//

import SwiftUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers

// MARK: - Studio Editor View

struct StudioEditorView: View {
    var videoURL: URL?
    @StateObject private var editorState = EditorStateManager()
    @State private var selectedPanel: EditorPanel = .canvas

    var body: some View {
        Group {
            if editorState.videoURL != nil {
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
            } else {
                EditorDropZone(onVideoSelected: { url in
                    editorState.loadVideo(url: url)
                })
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let url = videoURL {
                editorState.loadVideo(url: url)
            }
        }
        .onChange(of: videoURL) { newURL in
            if let url = newURL {
                editorState.loadVideo(url: url)
            }
        }
    }
}

// MARK: - Editor Drop Zone

struct EditorDropZone: View {
    var onVideoSelected: (URL) -> Void
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.4))

            VStack(spacing: 8) {
                Text("No Video Selected")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Drag and drop a video here, or select from Library")
                    .foregroundColor(.secondary)
            }

            Button(action: selectVideo) {
                Label("Open Video File", systemImage: "folder")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(isDragging ? .accentColor : .secondary.opacity(0.3))
                .padding(40)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            if let provider = providers.first {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async {
                            onVideoSelected(url)
                        }
                    }
                }
                return true
            }
            return false
        }
    }

    private func selectVideo() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            onVideoSelected(url)
        }
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
    @State private var isDraggingPlayhead = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Timeline")
                    .font(.headline)

                Spacer()

                // Trim & Cut Controls
                HStack(spacing: 4) {
                    Button(action: { editorState.setTrimStart() }) {
                        Label("Set Start", systemImage: "arrow.right.to.line")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Set trim start at playhead")

                    Button(action: { editorState.setTrimEnd() }) {
                        Label("Set End", systemImage: "arrow.left.to.line")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Set trim end at playhead")

                    Divider().frame(height: 20)

                    Button(action: { editorState.splitAtPlayhead() }) {
                        Label("Split", systemImage: "scissors")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Split video at playhead")

                    Button(action: { editorState.resetTrim() }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Reset trim")
                }

                Divider().frame(height: 20)

                // Trimmed duration
                Text("Output: \(editorState.formatTime(editorState.trimmedDuration))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)

                Divider().frame(height: 20)

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
                    // Clickable background for seeking
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isDraggingPlayhead = true
                                    let x = max(0, min(value.location.x, geometry.size.width))
                                    let newTime = (Double(x) / Double(geometry.size.width)) * editorState.duration / editorState.timelineZoom
                                    editorState.seekTo(time: max(0, min(newTime, editorState.duration)))
                                }
                                .onEnded { _ in
                                    isDraggingPlayhead = false
                                }
                        )

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

                    // Playhead (draggable)
                    DraggablePlayhead(
                        editorState: editorState,
                        totalWidth: geometry.size.width,
                        isDragging: $isDraggingPlayhead
                    )
                }
            }
            .background(Color(NSColor.textBackgroundColor))
        }
    }
}

// MARK: - Draggable Playhead

struct DraggablePlayhead: View {
    @ObservedObject var editorState: EditorStateManager
    let totalWidth: CGFloat
    @Binding var isDragging: Bool
    @State private var isHovered = false

    var position: CGFloat {
        guard editorState.duration > 0 else { return 0 }
        return CGFloat(editorState.currentTime / editorState.duration) * totalWidth * editorState.timelineZoom
    }

    var body: some View {
        VStack(spacing: 0) {
            // Playhead handle (larger hit area)
            ZStack {
                // Shadow/glow when dragging
                if isDragging || isHovered {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .blur(radius: 4)
                }

                // Triangle head
                Triangle()
                    .fill(Color.red)
                    .frame(width: isDragging ? 16 : 12, height: isDragging ? 10 : 8)
            }
            .frame(width: 24, height: 16)

            // Line
            Rectangle()
                .fill(Color.red)
                .frame(width: isDragging ? 3 : 2, height: 100)
        }
        .position(x: position, y: 60)
        .onHover { isHovered = $0 }
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    let x = max(0, min(value.location.x, totalWidth))
                    let newTime = (Double(x) / Double(totalWidth)) * editorState.duration / editorState.timelineZoom
                    editorState.seekTo(time: max(0, min(newTime, editorState.duration)))
                }
                .onEnded { _ in
                    isDragging = false
                }
        )
        .cursor(.resizeLeftRight)
        .animation(.easeOut(duration: 0.1), value: isDragging)
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
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Full track background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))

                // Segments
                if editorState.segments.count > 1 {
                    ForEach(editorState.segments) { segment in
                        SegmentView(segment: segment, editorState: editorState, totalWidth: geometry.size.width)
                    }
                } else {
                    // Simple trim view
                    TrimOverlayView(editorState: editorState, totalWidth: geometry.size.width)
                }
            }
        }
    }
}

struct SegmentView: View {
    let segment: VideoSegment
    @ObservedObject var editorState: EditorStateManager
    let totalWidth: CGFloat
    @State private var isHovered = false

    var xPosition: CGFloat {
        CGFloat(segment.startTime / editorState.duration) * totalWidth
    }

    var segmentWidth: CGFloat {
        CGFloat(segment.duration / editorState.duration) * totalWidth
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(segment.isEnabled ? Color.blue.opacity(0.4) : Color.gray.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(segment.isEnabled ? Color.blue : Color.gray, lineWidth: isHovered ? 2 : 1)
            )
            .overlay(
                Group {
                    if !segment.isEnabled {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.gray)
                    }
                }
            )
            .frame(width: max(segmentWidth - 2, 10))
            .offset(x: xPosition + 1)
            .onHover { isHovered = $0 }
            .contextMenu {
                if segment.isEnabled {
                    Button("Delete Segment") {
                        editorState.deleteSegment(id: segment.id)
                    }
                } else {
                    Button("Restore Segment") {
                        editorState.restoreSegment(id: segment.id)
                    }
                }
            }
    }
}

struct TrimOverlayView: View {
    @ObservedObject var editorState: EditorStateManager
    let totalWidth: CGFloat
    @State private var isDraggingStart = false
    @State private var isDraggingEnd = false

    var trimStartX: CGFloat {
        CGFloat(editorState.trimStart / editorState.duration) * totalWidth
    }

    var trimEndX: CGFloat {
        CGFloat(editorState.trimEnd / editorState.duration) * totalWidth
    }

    var trimWidth: CGFloat {
        trimEndX - trimStartX
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Dimmed areas (outside trim)
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: trimStartX)
                Spacer()
            }

            HStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: totalWidth - trimEndX)
            }

            // Active trim area
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .frame(width: max(trimWidth, 20))
                .offset(x: trimStartX)

            // Start handle
            TrimHandle(position: trimStartX, isStart: true)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newStart = max(0, min(Double(value.location.x / totalWidth) * editorState.duration, editorState.trimEnd - 0.5))
                            editorState.trimStart = newStart
                        }
                )

            // End handle
            TrimHandle(position: trimEndX, isStart: false)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let newEnd = max(editorState.trimStart + 0.5, min(Double(value.location.x / totalWidth) * editorState.duration, editorState.duration))
                            editorState.trimEnd = newEnd
                        }
                )
        }
    }
}

struct TrimHandle: View {
    let position: CGFloat
    let isStart: Bool
    @State private var isHovered = false

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.yellow)
            .frame(width: 8, height: 50)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.orange, lineWidth: 1)
            )
            .overlay(
                VStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.orange.opacity(0.6))
                            .frame(width: 4, height: 2)
                    }
                }
            )
            .offset(x: position - 4)
            .scaleEffect(isHovered ? 1.1 : 1.0)
            .onHover { isHovered = $0 }
            .cursor(.resizeLeftRight)
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct ZoomKeyframeMarker: View {
    let keyframe: EditorZoomKeyframe
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

    private var timeObserver: Any?
    private var isSeeking = false

    // Trim & Cut
    @Published var trimStart: Double = 0
    @Published var trimEnd: Double = 60
    @Published var segments: [VideoSegment] = []
    @Published var selectedSegmentId: UUID?
    @Published var isTrimMode = false
    @Published var splitPoints: [Double] = []

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
    @Published var zoomKeyframes: [EditorZoomKeyframe] = []

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
        seekTo(time: newTime)
    }

    func seekBackward() {
        let newTime = max(currentTime - 10, 0)
        seekTo(time: newTime)
    }

    func seekTo(time: Double) {
        isSeeking = true
        currentTime = time
        player.seek(to: CMTime(seconds: time, preferredTimescale: 600)) { [weak self] _ in
            self?.isSeeking = false
        }
    }

    func setupTimeObserver() {
        // Remove existing observer
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Add periodic time observer (60fps for smooth playhead)
        let interval = CMTime(seconds: 1.0/60.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, !self.isSeeking else { return }
            self.currentTime = time.seconds

            // Auto-stop at trim end
            if self.currentTime >= self.trimEnd && self.isPlaying {
                self.player.pause()
                self.isPlaying = false
                self.seekTo(time: self.trimStart)
            }
        }
    }

    func cleanupTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    func zoomTimelineIn() {
        timelineZoom = min(timelineZoom * 1.2, 4.0)
    }

    func zoomTimelineOut() {
        timelineZoom = max(timelineZoom / 1.2, 0.5)
    }

    func addZoomKeyframe() {
        let keyframe = EditorZoomKeyframe(id: UUID(), time: currentTime, level: zoomLevel, position: .zero)
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
        loadVideo(url: url)
    }

    func loadVideo(url: URL) {
        videoURL = url
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)

        // Setup time observer for playhead sync
        setupTimeObserver()

        Task {
            if let duration = try? await asset.load(.duration) {
                await MainActor.run {
                    self.duration = duration.seconds
                    self.trimEnd = duration.seconds
                    self.trimStart = 0
                    self.currentTime = 0
                    self.segments = [VideoSegment(id: UUID(), startTime: 0, endTime: duration.seconds, isEnabled: true)]
                    self.splitPoints = []
                }
            }
        }
    }

    deinit {
        cleanupTimeObserver()
    }

    // MARK: - Trim & Cut Functions

    func setTrimStart() {
        trimStart = currentTime
        if trimStart > trimEnd {
            trimEnd = duration
        }
    }

    func setTrimEnd() {
        trimEnd = currentTime
        if trimEnd < trimStart {
            trimStart = 0
        }
    }

    func resetTrim() {
        trimStart = 0
        trimEnd = duration
    }

    func splitAtPlayhead() {
        guard currentTime > 0 && currentTime < duration else { return }

        // Add split point
        if !splitPoints.contains(currentTime) {
            splitPoints.append(currentTime)
            splitPoints.sort()
        }

        // Rebuild segments
        rebuildSegments()
    }

    func rebuildSegments() {
        var newSegments: [VideoSegment] = []
        var points = [0.0] + splitPoints + [duration]
        points = Array(Set(points)).sorted()

        for i in 0..<(points.count - 1) {
            let segment = VideoSegment(
                id: UUID(),
                startTime: points[i],
                endTime: points[i + 1],
                isEnabled: true
            )
            newSegments.append(segment)
        }

        segments = newSegments
    }

    func deleteSegment(id: UUID) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            segments[index].isEnabled = false
        }
    }

    func restoreSegment(id: UUID) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            segments[index].isEnabled = true
        }
    }

    func removeSplit(at time: Double) {
        splitPoints.removeAll { abs($0 - time) < 0.1 }
        rebuildSegments()
    }

    func goToTrimStart() {
        currentTime = trimStart
        player.seek(to: CMTime(seconds: trimStart, preferredTimescale: 600))
    }

    func goToTrimEnd() {
        currentTime = trimEnd
        player.seek(to: CMTime(seconds: trimEnd, preferredTimescale: 600))
    }

    var trimmedDuration: Double {
        if segments.isEmpty {
            return trimEnd - trimStart
        }
        return segments.filter { $0.isEnabled }.reduce(0) { $0 + ($1.endTime - $1.startTime) }
    }

    func exportVideo() {
        // Export logic would go here
        print("Exporting video with format: \(exportFormat), quality: \(exportQuality)")
        print("Trim: \(trimStart) - \(trimEnd)")
        print("Segments: \(segments.filter { $0.isEnabled }.count)")
    }
}

// MARK: - Video Segment

struct VideoSegment: Identifiable {
    let id: UUID
    var startTime: Double
    var endTime: Double
    var isEnabled: Bool

    var duration: Double {
        endTime - startTime
    }
}

struct EditorZoomKeyframe: Identifiable {
    let id: UUID
    let time: Double
    let level: Double
    let position: CGPoint
}
