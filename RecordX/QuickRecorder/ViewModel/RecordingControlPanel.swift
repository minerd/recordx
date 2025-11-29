//
//  RecordingControlPanel.swift
//  RecordX
//
//  Floating control panel during recording
//

import SwiftUI
import ScreenCaptureKit
import AVFoundation

// MARK: - Recording Control Panel

struct RecordingControlPanel: View {
    @ObservedObject var recordingState: RecordingStateManager
    @State private var isExpanded = true
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.3)) { isExpanded.toggle() } }) {
                Image(systemName: isExpanded ? "chevron.left" : "chevron.right")
                    .font(.system(size: 10, weight: .bold)).foregroundColor(.white.opacity(0.6)).frame(width: 16, height: 40)
            }.buttonStyle(.plain)

            if isExpanded {
                HStack(spacing: 16) {
                    RecordingTimer(startTime: recordingState.startTime)
                    Divider().frame(height: 24).background(Color.white.opacity(0.2))

                    HStack(spacing: 12) {
                        ControlButton(icon: recordingState.isPaused ? "play.fill" : "pause.fill", label: recordingState.isPaused ? "Resume" : "Pause") { recordingState.togglePause() }
                        ControlButton(icon: "camera.fill", label: "Screenshot") { recordingState.takeScreenshot() }
                        ControlButton(icon: "plus.magnifyingglass", label: "Zoom") { recordingState.triggerZoom() }
                    }

                    Divider().frame(height: 24).background(Color.white.opacity(0.2))

                    Button(action: { recordingState.stopRecording() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill").font(.system(size: 12, weight: .bold))
                            Text("Stop").font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.red).foregroundColor(.white).cornerRadius(6)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.black.opacity(0.75)).shadow(color: .black.opacity(0.3), radius: 10, y: 5))
        .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

struct ControlButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundColor(isActive ? .accentColor : .white)
                    .frame(width: 32, height: 32).background(Circle().fill(isHovered ? Color.white.opacity(0.15) : Color.clear))
                Text(label).font(.system(size: 9, weight: .medium)).foregroundColor(.white.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct RecordingTimer: View {
    let startTime: Date?
    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?

    var formattedTime: String {
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color.red).frame(width: 8, height: 8).shadow(color: .red.opacity(0.5), radius: 4)
            Text(formattedTime).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(.white)
        }
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let start = startTime { elapsed = Date().timeIntervalSince(start) }
        }
    }
}

// MARK: - Recording State Manager

class RecordingStateManager: ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var startTime: Date?

    func startRecording() { isRecording = true; isPaused = false; startTime = Date() }
    func stopRecording() { isRecording = false; isPaused = false; SCContext.stopRecording() }
    func togglePause() {
        isPaused.toggle()
        SCContext.isPaused = isPaused
        if !isPaused { SCContext.isResume = true }
    }
    func takeScreenshot() { SCContext.saveFrame = true }
    func triggerZoom() {
        AutoZoomService.shared.zoomTo(position: NSEvent.mouseLocation, level: nil, animated: true)
    }
}

// MARK: - Post Recording Actions

struct PostRecordingActionsView: View {
    let videoURL: URL
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VideoThumbnailView(url: videoURL).frame(width: 320, height: 180).cornerRadius(12).shadow(radius: 10)
            Text("Recording Complete!").font(.headline)

            HStack(spacing: 16) {
                ActionButton(icon: "play.circle.fill", label: "Play", color: .blue) { NSWorkspace.shared.open(videoURL); onDismiss() }
                ActionButton(icon: "folder.fill", label: "Show in Finder", color: .orange) { NSWorkspace.shared.activateFileViewerSelecting([videoURL]); onDismiss() }
                ActionButton(icon: "square.and.arrow.up.fill", label: "Export", color: .purple) { onDismiss() }
                ActionButton(icon: "wand.and.stars", label: "Edit", color: .pink) { onDismiss() }
            }

            Button("Dismiss") { onDismiss() }.buttonStyle(.plain).foregroundColor(.secondary)
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(NSColor.windowBackgroundColor)).shadow(color: .black.opacity(0.2), radius: 20))
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 24)).foregroundColor(color)
                    .frame(width: 56, height: 56).background(Circle().fill(color.opacity(isHovered ? 0.2 : 0.1)))
                Text(label).font(.system(size: 11, weight: .medium))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumb = thumbnail { Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fill) }
            else { Rectangle().fill(Color.gray.opacity(0.2)).overlay(ProgressView()) }
        }
        .onAppear { generateThumbnail() }
    }

    private func generateThumbnail() {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 360)
        Task {
            do {
                if #available(macOS 13, *) {
                    let cgImage = try await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)).image
                    await MainActor.run { thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)) }
                } else {
                    var actualTime = CMTime.zero
                    let cgImage = try generator.copyCGImage(at: CMTime(seconds: 0.5, preferredTimescale: 600), actualTime: &actualTime)
                    await MainActor.run { thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)) }
                }
            } catch {}
        }
    }
}
