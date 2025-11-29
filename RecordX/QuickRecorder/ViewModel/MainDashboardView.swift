//
//  MainDashboardView.swift
//  RecordX
//
//  Modern Screen Studio-like dashboard interface
//

import SwiftUI
import ScreenCaptureKit
import AVFoundation

// MARK: - Main Dashboard

struct MainDashboardView: View {
    @State private var selectedTab: DashboardTab = .record
    @State private var recentRecordings: [RecordingItem] = []
    @State private var isRecording = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(NSColor.windowBackgroundColor),
                    Color(NSColor.windowBackgroundColor).opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Navigation Bar
                TopNavigationBar(
                    selectedTab: $selectedTab,
                    showSettings: $showSettings
                )

                // Main Content
                switch selectedTab {
                case .record:
                    RecordingDashboard(isRecording: $isRecording)
                case .library:
                    LibraryView(recordings: $recentRecordings)
                case .editor:
                    EditorPlaceholderView()
                }
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            loadRecentRecordings()
        }
    }

    private func loadRecentRecordings() {
        if let saveDir = UserDefaults.standard.string(forKey: "saveDirectory") {
            let fm = FileManager.default
            if let files = try? fm.contentsOfDirectory(atPath: saveDir) {
                recentRecordings = files
                    .filter { $0.hasSuffix(".mp4") || $0.hasSuffix(".mov") }
                    .prefix(20)
                    .map { filename in
                        let url = URL(fileURLWithPath: saveDir).appendingPathComponent(filename)
                        let attrs = try? fm.attributesOfItem(atPath: url.path)
                        let date = attrs?[.modificationDate] as? Date ?? Date()
                        let size = attrs?[.size] as? Int64 ?? 0
                        return RecordingItem(id: UUID(), name: filename, url: url, date: date, size: size, thumbnail: nil)
                    }
                    .sorted { $0.date > $1.date }
            }
        }
    }
}

// MARK: - Dashboard Tabs

enum DashboardTab: String, CaseIterable {
    case record = "Record"
    case library = "Library"
    case editor = "Editor"

    var icon: String {
        switch self {
        case .record: return "record.circle"
        case .library: return "photo.on.rectangle.angled"
        case .editor: return "slider.horizontal.3"
        }
    }
}

// MARK: - Recording Item Model

struct RecordingItem: Identifiable {
    let id: UUID
    let name: String
    let url: URL
    let date: Date
    let size: Int64
    var thumbnail: NSImage?

    var formattedSize: String { ByteCountFormatter.string(fromByteCount: size, countStyle: .file) }
    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Top Navigation Bar

struct TopNavigationBar: View {
    @Binding var selectedTab: DashboardTab
    @Binding var showSettings: Bool

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("RecordX")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
            }
            .padding(.leading, 20)

            Spacer()

            HStack(spacing: 4) {
                ForEach(DashboardTab.allCases, id: \.self) { tab in
                    TabButton(title: tab.rawValue, icon: tab.icon, isSelected: selectedTab == tab) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    }
                }
            }
            .padding(4)
            .background(Color.primary.opacity(0.05))
            .cornerRadius(10)

            Spacer()

            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill").font(.system(size: 16)).foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
        }
        .frame(height: 60)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium))
                Text(title).font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recording Dashboard

struct RecordingDashboard: View {
    @Binding var isRecording: Bool
    @State private var selectedSource: RecordingSource = .screen
    @State private var recordMic = false
    @State private var recordSystemAudio = true
    @State private var showCursor = true
    @State private var selectedQuality: RecordingQuality = .high

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("What would you like to record?")
                    .font(.system(size: 24, weight: .semibold))
                Text("Choose a recording source to get started")
                    .font(.system(size: 14)).foregroundColor(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                RecordingSourceCard(source: .screen, isSelected: selectedSource == .screen) { selectedSource = .screen }
                RecordingSourceCard(source: .window, isSelected: selectedSource == .window) { selectedSource = .window }
                RecordingSourceCard(source: .area, isSelected: selectedSource == .area) { selectedSource = .area }
                RecordingSourceCard(source: .application, isSelected: selectedSource == .application) { selectedSource = .application }
                RecordingSourceCard(source: .audio, isSelected: selectedSource == .audio) { selectedSource = .audio }
                RecordingSourceCard(source: .device, isSelected: selectedSource == .device) { selectedSource = .device }
            }
            .padding(.horizontal, 40)

            HStack(spacing: 24) {
                QuickSettingToggle(icon: "mic.fill", label: "Microphone", isOn: $recordMic)
                QuickSettingToggle(icon: "speaker.wave.2.fill", label: "System Audio", isOn: $recordSystemAudio)
                QuickSettingToggle(icon: "cursorarrow", label: "Show Cursor", isOn: $showCursor)
                Divider().frame(height: 30)
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundColor(.secondary)
                    Picker("", selection: $selectedQuality) {
                        ForEach(RecordingQuality.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu).frame(width: 100)
                }
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
            .background(Color.primary.opacity(0.03)).cornerRadius(12)
            .padding(.horizontal, 40)

            Spacer()

            RecordButton(isRecording: $isRecording, selectedSource: selectedSource)
                .padding(.bottom, 40)
        }
    }
}

// MARK: - Recording Source

enum RecordingSource: String, CaseIterable {
    case screen = "Screen", window = "Window", area = "Screen Area"
    case application = "Application", audio = "System Audio", device = "Mobile Device"

    var icon: String {
        switch self {
        case .screen: return "display"
        case .window: return "macwindow"
        case .area: return "viewfinder"
        case .application: return "app.dashed"
        case .audio: return "waveform"
        case .device: return "iphone"
        }
    }

    var description: String {
        switch self {
        case .screen: return "Record entire display"
        case .window: return "Record a specific window"
        case .area: return "Select a region"
        case .application: return "Record an app"
        case .audio: return "Audio only"
        case .device: return "iOS/iPadOS device"
        }
    }

    var color: Color {
        switch self {
        case .screen: return .blue
        case .window: return .purple
        case .area: return .green
        case .application: return .orange
        case .audio: return .pink
        case .device: return .cyan
        }
    }
}

enum RecordingQuality: String, CaseIterable { case standard = "Standard", high = "High", ultra = "Ultra" }

// MARK: - Recording Source Card

struct RecordingSourceCard: View {
    let source: RecordingSource
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle().fill(source.color.opacity(isSelected ? 0.2 : 0.1)).frame(width: 56, height: 56)
                    Image(systemName: source.icon).font(.system(size: 24, weight: .medium)).foregroundColor(isSelected ? source.color : .secondary)
                }
                VStack(spacing: 4) {
                    Text(source.rawValue).font(.system(size: 14, weight: .semibold))
                    Text(source.description).font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 20)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(isHovered ? 0.06 : 0.03)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(isSelected ? source.color : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// MARK: - Quick Setting Toggle

struct QuickSettingToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(isOn ? .accentColor : .secondary).frame(width: 20)
                Text(label).font(.system(size: 13, weight: .medium)).foregroundColor(isOn ? .primary : .secondary)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle").font(.system(size: 14)).foregroundColor(isOn ? .accentColor : .secondary.opacity(0.5))
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(isOn ? Color.accentColor.opacity(0.1) : Color.clear).cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Record Button

struct RecordButton: View {
    @Binding var isRecording: Bool
    let selectedSource: RecordingSource
    @State private var isHovered = false
    @State private var isPulsing = false
    var appDelegate: AppDelegate { AppDelegate.shared }

    var body: some View {
        Button(action: startRecording) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Color.red).frame(width: 16, height: 16).scaleEffect(isPulsing ? 1.2 : 1.0).opacity(isPulsing ? 0.6 : 1.0)
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                }
                Text("Start Recording").font(.system(size: 16, weight: .semibold))
            }
            .padding(.horizontal, 32).padding(.vertical, 16)
            .background(LinearGradient(colors: [Color.red, Color.red.opacity(0.8)], startPoint: .top, endPoint: .bottom))
            .foregroundColor(.white).cornerRadius(30)
            .shadow(color: .red.opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 16 : 8, y: 4)
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onAppear { withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) { isPulsing = true } }
    }

    private func startRecording() {
        closeMainWindow()
        switch selectedSource {
        case .screen: appDelegate.createNewWindow(view: ScreenSelector(), title: "Screen Selector".local)
        case .window: appDelegate.createNewWindow(view: WinSelector(), title: "Window Selector".local)
        case .area:
            SCContext.updateAvailableContent { DispatchQueue.main.async { appDelegate.showAreaSelector(size: NSSize(width: 600, height: 450)) } }
        case .application: appDelegate.createNewWindow(view: AppSelector(), title: "App Selector".local)
        case .audio:
            if let display = SCContext.getSCDisplayWithMouse() {
                appDelegate.createCountdownPanel(screen: display) {
                    AppDelegate.shared.prepRecord(type: "audio", screens: SCContext.getSCDisplayWithMouse(), windows: nil, applications: nil)
                }
            }
        case .device: break
        }
    }
}

// MARK: - Library View

struct LibraryView: View {
    @Binding var recordings: [RecordingItem]
    @State private var searchText = ""

    var filteredRecordings: [RecordingItem] {
        searchText.isEmpty ? recordings : recordings.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Search recordings...", text: $searchText).textFieldStyle(.plain)
                }
                .padding(10).background(Color.primary.opacity(0.05)).cornerRadius(10)
            }
            .padding()

            if filteredRecordings.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "film.stack").font(.system(size: 48)).foregroundColor(.secondary.opacity(0.5))
                    Text("No recordings yet").font(.headline).foregroundColor(.secondary)
                    Text("Your recordings will appear here").font(.subheadline).foregroundColor(.secondary.opacity(0.7))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280), spacing: 16)], spacing: 16) {
                        ForEach(filteredRecordings) { RecordingCard(recording: $0) }
                    }.padding()
                }
            }
        }
    }
}

struct RecordingCard: View {
    let recording: RecordingItem
    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                if let thumb = thumbnail {
                    Image(nsImage: thumb).resizable().aspectRatio(16/9, contentMode: .fill).frame(height: 120).clipped()
                } else {
                    Rectangle().fill(Color.primary.opacity(0.1)).frame(height: 120)
                        .overlay(Image(systemName: "film").font(.system(size: 32)).foregroundColor(.secondary.opacity(0.3)))
                }
                if isHovered {
                    Color.black.opacity(0.4)
                    Image(systemName: "play.circle.fill").font(.system(size: 40)).foregroundColor(.white)
                }
            }.cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text(recording.name).font(.system(size: 12, weight: .medium)).lineLimit(1).truncationMode(.middle)
                HStack { Text(recording.formattedDate); Text("•"); Text(recording.formattedSize) }.font(.system(size: 11)).foregroundColor(.secondary)
            }.padding(8)
        }
        .background(Color.primary.opacity(0.03)).cornerRadius(12)
        .onHover { isHovered = $0 }
        .onTapGesture { NSWorkspace.shared.open(recording.url) }
        .contextMenu {
            Button("Open") { NSWorkspace.shared.open(recording.url) }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([recording.url]) }
            Divider()
            Button("Delete", role: .destructive) { try? FileManager.default.removeItem(at: recording.url) }
        }
        .onAppear { generateThumbnail() }
    }

    private func generateThumbnail() {
        let asset = AVAsset(url: recording.url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 225)
        Task {
            do {
                let cgImage = try await generator.image(at: CMTime(seconds: 1, preferredTimescale: 600)).image
                await MainActor.run { thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height)) }
            } catch {}
        }
    }
}

// MARK: - Editor Placeholder

struct EditorPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "slider.horizontal.3").font(.system(size: 64)).foregroundColor(.secondary.opacity(0.3))
            Text("Video Editor").font(.title2).fontWeight(.semibold)
            Text("Drop a video here or select from your library").foregroundColor(.secondary)
            Button("Open from Library") {}.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
