//
//  SettingsView.swift
//  QuickRecorder
//
//  Created by apple on 2024/4/19.
//

import SwiftUI
import Sparkle
import ServiceManagement
import KeyboardShortcuts
import MatrixColorSelector

struct SettingsView: View {
    @State private var selectedItem: String? = "General"

    var body: some View {
        NavigationView {
            List(selection: $selectedItem) {
                NavigationLink(destination: GeneralView(), tag: "General", selection: $selectedItem) {
                    Label("General", image: "gear")
                }
                NavigationLink(destination: RecorderView(), tag: "Recorder", selection: $selectedItem) {
                    Label("Recorder", image: "record")
                }
                NavigationLink(destination: EffectsView(), tag: "Effects", selection: $selectedItem) {
                    Label("Effects", systemImage: "wand.and.stars")
                }
                NavigationLink(destination: OutputView(), tag: "Output", selection: $selectedItem) {
                    Label("Output", image: "film")
                }
                NavigationLink(destination: ExportView(), tag: "Export", selection: $selectedItem) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                NavigationLink(destination: HotkeyView(), tag: "Hotkey", selection: $selectedItem) {
                    Label("Hotkey", image: "hotkey")
                }
                NavigationLink(destination: BlocklistView(), tag: "Blocklist", selection: $selectedItem) {
                    Label("Blocklist", image: "blacklist")
                }
            }
            .listStyle(.sidebar)
            .padding(.top, 9)
        }.frame(width: 650, height: 580)
    }
}

struct GeneralView: View {
    @AppStorage("countdown") private var countdown: Int = 0
    @AppStorage("poSafeDelay") private var poSafeDelay: Int = 1
    @AppStorage("showOnDock") private var showOnDock: Bool = true
    @AppStorage("showMenubar") private var showMenubar: Bool = false
    
    @State private var launchAtLogin = false

    var body: some View {
        SForm {
            SGroupBox(label: "Startup") {
                if #available(macOS 13, *) {
                    SToggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            }catch{
                                print("Failed to \(newValue ? "enable" : "disable") launch at login: \(error.localizedDescription)")
                            }
                        }
                    SDivider()
                }
                SToggle("Show RecordX on Dock", isOn: $showOnDock)
                    //.disabled(!showMenubar)
                SDivider()
                SToggle("Show RecordX on Menu Bar", isOn: $showMenubar)
                    //.disabled(!showOnDock)
            }
            SGroupBox(label: "Update") { UpdaterSettingsView(updater: updaterController.updater) }
            VStack(spacing: 8) {
                CheckForUpdatesView(updater: updaterController.updater)
                if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("RecordX v\(appVersion)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear{ if #available(macOS 13, *) { launchAtLogin = (SMAppService.mainApp.status == .enabled) }}
        .onChange(of: showMenubar) { _ in updateStatusBar() }
        .onChange(of: showOnDock) { newValue in
            if !newValue {
                NSApp.setActivationPolicy(.accessory)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                NSApp.setActivationPolicy(.regular)
            }
        }
    }
}

struct RecorderView: View {
    @AppStorage("countdown")        private var countdown: Int = 0
    @AppStorage("poSafeDelay")      private var poSafeDelay: Int = 1
    @AppStorage("highlightMouse")   private var highlightMouse: Bool = false
    @AppStorage("includeMenuBar")   private var includeMenuBar: Bool = true
    @AppStorage("hideDesktopFiles") private var hideDesktopFiles: Bool = false
    @AppStorage("trimAfterRecord")  private var trimAfterRecord: Bool = false
    @AppStorage("miniStatusBar")    private var miniStatusBar: Bool = false
    @AppStorage("hideSelf")         private var hideSelf: Bool = true
    @AppStorage("preventSleep")     private var preventSleep: Bool = true
    @AppStorage("showPreview")      private var showPreview: Bool = true
    @AppStorage("hideCCenter")      private var hideCCenter: Bool = false
    
    @State private var userColor: Color = Color.black

    var body: some View {
        SForm(spacing: 10) {
            SGroupBox(label: "Recorder") {
                SSteper("Delay Before Recording", value: $countdown, min: 0, max: 99)
                SDivider()
                if #available(macOS 14, *) {
                    SSteper("Presenter Overlay Delay", value: $poSafeDelay, min: 0, max: 99, tips: "If enabling Presenter Overlay causes recording failure, please increase this value.")
                    SDivider()
                }
                SItem(label: "Custom Background Color") {
                    if #unavailable(macOS 13) {
                        ColorPicker("", selection: $userColor)
                    } else {
                        MatrixColorSelector("", selection: $userColor)
                            .onChange(of: userColor) { userColor in ud.setColor(userColor, forKey: "userColor") }
                    }
                }
            }
            SGroupBox {
                SToggle("Mini size Menu Bar controller", isOn: $miniStatusBar)
                SDivider()
                SToggle("Prevent Mac from sleeping while recording", isOn: $preventSleep)
                SDivider()
                if #available(macOS 13, *) {
                    SToggle("Show floating preview after recording", isOn: $showPreview)
                    SDivider()
                }
                SToggle("Open video trimmer after recording", isOn: $trimAfterRecord)
            }
            SGroupBox {
                SToggle("Exclude RecordX itself", isOn: $hideSelf)
                SDivider()
                if #available (macOS 13, *) {
                    SToggle("Include Menu Bar in Recording", isOn: $includeMenuBar)
                    SDivider()
                }
                SToggle("Hide Control Center Icons", isOn: $hideCCenter, tips: "Hide the clock, Wi-Fi, bluetooth, volume and other system icons in the menu bar.")
                SDivider()
                SToggle("Highlight the Mouse Cursor", isOn: $highlightMouse, tips: "Not available for \"Single Window Capture\"")
                SDivider()
                SToggle("Exclude Files on Desktop", isOn: $hideDesktopFiles, tips: "If enabled, all files on the Desktop will be hidden from the video when recording.")
            }
        }.onAppear{ userColor = ud.color(forKey: "userColor") ?? Color.black }
    }
}

struct OutputView: View {
    @AppStorage("encoder")          private var encoder: Encoder = .h265
    @AppStorage("videoFormat")      private var videoFormat: VideoFormat = .mp4
    @AppStorage("audioFormat")      private var audioFormat: AudioFormat = .aac
    @AppStorage("audioQuality")     private var audioQuality: AudioQuality = .high
    @AppStorage("pixelFormat")      private var pixelFormat: PixFormat = .delault
    @AppStorage("background")       private var background: BackgroundType = .wallpaper
    @AppStorage("remuxAudio")       private var remuxAudio: Bool = true
    @AppStorage("enableAEC")        private var enableAEC: Bool = false
    @AppStorage("AECLevel")         private var AECLevel: String = "mid"
    @AppStorage("withAlpha")        private var withAlpha: Bool = false
    @AppStorage("saveDirectory")    private var saveDirectory: String?

    var body: some View {
        SForm(spacing: 30) {
            SGroupBox(label: "Audio") {
                SPicker("Quality", selection: $audioQuality) {
                    if audioFormat == .alac || audioFormat == .flac {
                        Text("Lossless").tag(audioQuality)
                    }
                    Text("Normal - 128Kbps").tag(AudioQuality.normal)
                    Text("Good - 192Kbps").tag(AudioQuality.good)
                    Text("High - 256Kbps").tag(AudioQuality.high)
                    Text("Extreme - 320Kbps").tag(AudioQuality.extreme)
                }.disabled(audioFormat == .alac || audioFormat == .flac)
                SDivider()
                SPicker("Format", selection: $audioFormat) {
                    Text("MP3").tag(AudioFormat.mp3)
                    Text("AAC").tag(AudioFormat.aac)
                    Text("ALAC (Lossless)").tag(AudioFormat.alac)
                    Text("FLAC (Lossless)").tag(AudioFormat.flac)
                    Text("Opus").tag(AudioFormat.opus)
                }
                SDivider()
                if #available(macOS 13, *) {
                    SToggle("Record Microphone to Main Track", isOn: $remuxAudio)
                    SDivider()
                }
                SToggle("Enable Acoustic Echo Cancellation", isOn: $enableAEC)
                if #available(macOS 14, *) {
                    SDivider()
                    SPicker("Audio Ducking Level", selection: $AECLevel) {
                        Text("Min").tag("min")
                        Text("Mid").tag("mid")
                        Text("Max").tag("max")
                    }.disabled(!enableAEC)
                }
            }
            SGroupBox(label: "Video") {
                SPicker("Format", selection: $videoFormat) {
                    Text("MOV").tag(VideoFormat.mov)
                    Text("MP4").tag(VideoFormat.mp4)
                }.disabled(withAlpha)
                SDivider()
                SPicker("Encoder", selection: $encoder) {
                    Text("H.264").tag(Encoder.h264)
                    Text("H.265").tag(Encoder.h265)
                }.disabled(withAlpha)
                SDivider()
                SToggle("Recording with Alpha Channel", isOn: $withAlpha)
            }
            SGroupBox(label: "Save") {
                SItem(label: "Output Folder") {
                    Text(String(format: "Currently set to \"%@\"".local, saveDirectory!.lastPathComponent))
                        .font(.footnote)
                        .foregroundColor(Color.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Button("Select...", action: { updateOutputDirectory() })
                }
            }
        }.onChange(of: withAlpha) {alpha in
            if alpha {
                encoder = Encoder.h265; videoFormat = VideoFormat.mov
            } else {
                if background == .clear { background = .wallpaper }
            }
        }
    }
    
    func updateOutputDirectory() { // todo: re-sandbox
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowedContentTypes = []
        openPanel.allowsOtherFileTypes = false
        if openPanel.runModal() == NSApplication.ModalResponse.OK {
            if let path = openPanel.urls.first?.path { saveDirectory = path }
        }
    }
}

struct HotkeyView: View {
    var body: some View {
        SForm(spacing: 10) {
            SGroupBox(label: "Hotkey") {
                SItem(label: "Open Main Panel") { KeyboardShortcuts.Recorder("", name: .showPanel) }
            }
            SGroupBox {
                SItem(label: "Stop Recording") { KeyboardShortcuts.Recorder("", name: .stop) }
                SDivider()
                SItem(label: "Pause / Resume") { KeyboardShortcuts.Recorder("", name: .pauseResume) }
            }
            SGroupBox {
                SItem(label: "Record System Audio") { KeyboardShortcuts.Recorder("", name: .startWithAudio) }
                SDivider()
                SItem(label: "Record Current Screen") { KeyboardShortcuts.Recorder("", name: .startWithScreen) }
                SDivider()
                SItem(label: "Record Topmost Window") { KeyboardShortcuts.Recorder("", name: .startWithWindow) }
                SDivider()
                SItem(label: "Select Area to Record") { KeyboardShortcuts.Recorder("", name: .startWithArea) }
            }
            SGroupBox {
                SItem(label: "Save Current Frame") { KeyboardShortcuts.Recorder("", name: .saveFrame) }
                SDivider()
                SItem(label: "Toggle Screen Magnifier") {KeyboardShortcuts.Recorder("", name: .screenMagnifier) }
            }
        }
    }
}

struct BlocklistView: View {
    var body: some View {
        SForm(spacing: 0, noSpacer: true) {
            SGroupBox(label: "Blocklist") {
                    BundleSelector()
                    Text("These apps will be excluded when recording \"Screen\" or \"Screen Area\"\nBut if the app is launched after the recording starts, it cannot be excluded.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(Color.secondary)
            }
        }
    }
}

// MARK: - Effects View

struct EffectsView: View {
    // Cursor Smoothing
    @AppStorage("cursorSmoothingEnabled") private var cursorSmoothingEnabled: Bool = false
    @AppStorage("cursorSmoothingIntensity") private var cursorSmoothingIntensity: Double = 0.7
    @AppStorage("cursorSmoothingEasing") private var cursorSmoothingEasing: String = "easeInOutCubic"
    @AppStorage("cursorScale") private var cursorScale: Double = 1.0

    // Auto Zoom
    @AppStorage("autoZoomEnabled") private var autoZoomEnabled: Bool = false
    @AppStorage("useSmartZoom") private var useSmartZoom: Bool = true
    @AppStorage("autoZoomLevel") private var autoZoomLevel: Double = 2.0
    @AppStorage("autoZoomDuration") private var autoZoomDuration: Double = 0.5
    @AppStorage("autoZoomHoldDuration") private var autoZoomHoldDuration: Double = 1.5
    @AppStorage("zoomOnClick") private var zoomOnClick: Bool = true
    @AppStorage("zoomOnKeyboard") private var zoomOnKeyboard: Bool = true
    @AppStorage("zoomFollowCursor") private var zoomFollowCursor: Bool = true

    // Visual Effects
    @AppStorage("visualEffectsEnabled") private var visualEffectsEnabled: Bool = false
    @AppStorage("effectCornerRadius") private var effectCornerRadius: Double = 12.0
    @AppStorage("effectPadding") private var effectPadding: Double = 20.0
    @AppStorage("effectShadowEnabled") private var effectShadowEnabled: Bool = true
    @AppStorage("effectShadowRadius") private var effectShadowRadius: Double = 30.0
    @AppStorage("effectShadowOpacity") private var effectShadowOpacity: Double = 0.5

    @AppStorage("cursorCameraEnabled") private var cursorCameraEnabled: Bool = false

    var body: some View {
        ScrollView {
        SForm(spacing: 15) {
            // Quick Toggle for Cursor Camera
            HStack {
                Image(systemName: cursorCameraEnabled ? "video.fill" : "video.slash.fill")
                    .font(.system(size: 24))
                    .foregroundColor(cursorCameraEnabled ? .green : .secondary)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cursor-Following Camera")
                        .font(.headline)
                    Text(cursorCameraEnabled ? "Webcam follows your cursor" : "Webcam overlay disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: $cursorCameraEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).fill(cursorCameraEnabled ? Color.green.opacity(0.1) : Color.secondary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(cursorCameraEnabled ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1))

            SGroupBox(label: "Cursor Smoothing") {
                SToggle("Enable Smooth Cursor Movement", isOn: $cursorSmoothingEnabled)
                SDivider()
                SItem(label: "Smoothing Intensity") {
                    Slider(value: $cursorSmoothingIntensity, in: 0.1...1.0, step: 0.1)
                        .frame(width: 150)
                    Text(String(format: "%.1f", cursorSmoothingIntensity))
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }.disabled(!cursorSmoothingEnabled)
                SDivider()
                SPicker("Easing Function", selection: $cursorSmoothingEasing) {
                    Text("Linear").tag("linear")
                    Text("Ease In/Out (Cubic)").tag("easeInOutCubic")
                    Text("Ease In/Out (Quart)").tag("easeInOutQuart")
                    Text("Ease In/Out (Expo)").tag("easeInOutExpo")
                }.disabled(!cursorSmoothingEnabled)
                SDivider()
                SItem(label: "Cursor Scale") {
                    Slider(value: $cursorScale, in: 0.5...3.0, step: 0.25)
                        .frame(width: 150)
                    Text(String(format: "%.2fx", cursorScale))
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }.disabled(!cursorSmoothingEnabled)
            }

            SGroupBox(label: "Auto Zoom") {
                SToggle("Enable Automatic Zoom", isOn: $autoZoomEnabled, tips: "Automatically zoom in when clicking or typing")
                SDivider()
                SToggle("Use Smart Zoom (Recommended)", isOn: $useSmartZoom, tips: "AI-powered zoom with UI detection, content-aware zoom levels, and smooth cursor following")
                    .disabled(!autoZoomEnabled)
                SDivider()
                SItem(label: "Zoom Level") {
                    Slider(value: $autoZoomLevel, in: 1.5...4.0, step: 0.5)
                        .frame(width: 150)
                    Text(String(format: "%.1fx", autoZoomLevel))
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }.disabled(!autoZoomEnabled)
                SDivider()
                SItem(label: "Animation Duration") {
                    Slider(value: $autoZoomDuration, in: 0.2...1.0, step: 0.1)
                        .frame(width: 150)
                    Text(String(format: "%.1fs", autoZoomDuration))
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }.disabled(!autoZoomEnabled)
                SDivider()
                SItem(label: "Hold Duration") {
                    Slider(value: $autoZoomHoldDuration, in: 0.5...5.0, step: 0.5)
                        .frame(width: 150)
                    Text(String(format: "%.1fs", autoZoomHoldDuration))
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }.disabled(!autoZoomEnabled)
                SDivider()
                SToggle("Zoom on Mouse Clicks", isOn: $zoomOnClick).disabled(!autoZoomEnabled)
                SDivider()
                SToggle("Zoom on Keyboard Input", isOn: $zoomOnKeyboard).disabled(!autoZoomEnabled)
                SDivider()
                SToggle("Follow Cursor While Zoomed", isOn: $zoomFollowCursor).disabled(!autoZoomEnabled)

                if useSmartZoom && autoZoomEnabled {
                    SDivider()
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("Smart Zoom Features:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Label("UI Element Detection", systemImage: "rectangle.dashed")
                        Label("Content-Aware Zoom Levels", systemImage: "slider.horizontal.3")
                        Label("Smooth Cursor Following", systemImage: "cursorarrow.motionlines")
                        Label("Spam Click Protection", systemImage: "hand.tap")
                        Label("Auto Zoom Out on Scroll", systemImage: "scroll")
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
                }
            }

            SGroupBox(label: "Visual Effects") {
                SToggle("Enable Visual Effects", isOn: $visualEffectsEnabled, tips: "Add shadow, rounded corners, and padding to recordings")
                SDivider()
                SItem(label: "Corner Radius") {
                    Slider(value: $effectCornerRadius, in: 0...50, step: 2)
                        .frame(width: 150)
                    Text(String(format: "%.0fpx", effectCornerRadius))
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }.disabled(!visualEffectsEnabled)
                SDivider()
                SItem(label: "Padding") {
                    Slider(value: $effectPadding, in: 0...100, step: 5)
                        .frame(width: 150)
                    Text(String(format: "%.0fpx", effectPadding))
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }.disabled(!visualEffectsEnabled)
                SDivider()
                SToggle("Enable Shadow", isOn: $effectShadowEnabled).disabled(!visualEffectsEnabled)
                SDivider()
                SItem(label: "Shadow Radius") {
                    Slider(value: $effectShadowRadius, in: 5...100, step: 5)
                        .frame(width: 150)
                    Text(String(format: "%.0fpx", effectShadowRadius))
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }.disabled(!visualEffectsEnabled || !effectShadowEnabled)
                SDivider()
                SItem(label: "Shadow Opacity") {
                    Slider(value: $effectShadowOpacity, in: 0.1...1.0, step: 0.1)
                        .frame(width: 150)
                    Text(String(format: "%.0f%%", effectShadowOpacity * 100))
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }.disabled(!visualEffectsEnabled || !effectShadowEnabled)
            }

            SGroupBox(label: "Cursor-Following Camera") {
                CursorCameraSettingsContent()
            }
        }
        }
    }
}

struct CursorCameraSettingsContent: View {
    @AppStorage("cursorCameraEnabled") private var cursorCameraEnabled = false
    @AppStorage("cursorCameraSize") private var cursorCameraSize: Double = 150
    @AppStorage("cursorCameraShape") private var cursorCameraShape: String = "circle"
    @AppStorage("cursorCameraPosition") private var cursorCameraPosition: String = "followCursor"
    @AppStorage("cursorCameraBorderWidth") private var cursorCameraBorderWidth: Double = 3
    @AppStorage("cursorCameraShadow") private var cursorCameraShadow = true
    @AppStorage("cursorCameraSmoothFollow") private var cursorCameraSmoothFollow = true
    @AppStorage("cursorCameraOffsetX") private var cursorCameraOffsetX: Double = 50
    @AppStorage("cursorCameraOffsetY") private var cursorCameraOffsetY: Double = -50

    var body: some View {
        VStack(spacing: 10) {
            SToggle("Enable Cursor-Following Webcam", isOn: $cursorCameraEnabled)
            SDivider()
            SItem(label: "Camera Size") {
                Slider(value: $cursorCameraSize, in: 80...300, step: 10)
                    .frame(width: 150)
                Text("\(Int(cursorCameraSize))px")
                    .foregroundColor(.secondary)
                    .frame(width: 50)
            }.disabled(!cursorCameraEnabled)
            SDivider()
            SPicker("Shape", selection: $cursorCameraShape) {
                Text("Circle").tag("circle")
                Text("Rounded Square").tag("roundedSquare")
                Text("Square").tag("square")
            }.disabled(!cursorCameraEnabled)
            SDivider()
            SPicker("Position", selection: $cursorCameraPosition) {
                Text("Follow Cursor").tag("followCursor")
                Text("Top Left").tag("topLeft")
                Text("Top Right").tag("topRight")
                Text("Bottom Left").tag("bottomLeft")
                Text("Bottom Right").tag("bottomRight")
            }.disabled(!cursorCameraEnabled)

            if cursorCameraPosition == "followCursor" {
                SDivider()
                SItem(label: "Offset X") {
                    Slider(value: $cursorCameraOffsetX, in: -200...200, step: 10)
                        .frame(width: 150)
                    Text("\(Int(cursorCameraOffsetX))")
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }.disabled(!cursorCameraEnabled)
                SDivider()
                SItem(label: "Offset Y") {
                    Slider(value: $cursorCameraOffsetY, in: -200...200, step: 10)
                        .frame(width: 150)
                    Text("\(Int(cursorCameraOffsetY))")
                        .foregroundColor(.secondary)
                        .frame(width: 40)
                }.disabled(!cursorCameraEnabled)
                SDivider()
                SToggle("Smooth Following", isOn: $cursorCameraSmoothFollow).disabled(!cursorCameraEnabled)
            }
            SDivider()
            SItem(label: "Border Width") {
                Slider(value: $cursorCameraBorderWidth, in: 0...10, step: 1)
                    .frame(width: 150)
                Text("\(Int(cursorCameraBorderWidth))px")
                    .foregroundColor(.secondary)
                    .frame(width: 40)
            }.disabled(!cursorCameraEnabled)
            SDivider()
            SToggle("Shadow", isOn: $cursorCameraShadow).disabled(!cursorCameraEnabled)
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    // GIF Export
    @AppStorage("gifFrameRate") private var gifFrameRate: Int = 15
    @AppStorage("gifQuality") private var gifQuality: Double = 0.8
    @AppStorage("gifMaxWidth") private var gifMaxWidth: Int = 640
    @AppStorage("gifLoopCount") private var gifLoopCount: Int = 0

    // Platform Presets
    @AppStorage("defaultExportPlatform") private var defaultExportPlatform: String = "youtube"

    // Audio Enhancement
    @AppStorage("audioNormalizationEnabled") private var audioNormalizationEnabled: Bool = false
    @AppStorage("audioNormalizationTarget") private var audioNormalizationTarget: Double = -14.0
    @AppStorage("noiseReductionEnabled") private var noiseReductionEnabled: Bool = false
    @AppStorage("noiseReductionStrength") private var noiseReductionStrength: Double = 0.5

    // Device Frame
    @AppStorage("deviceFrameEnabled") private var deviceFrameEnabled: Bool = false
    @AppStorage("deviceFrameType") private var deviceFrameType: String = "macbookPro14"
    @AppStorage("deviceFrameColor") private var deviceFrameColor: String = "spaceBlack"
    @AppStorage("deviceFrameShadow") private var deviceFrameShadow: Bool = true

    var body: some View {
        SForm(spacing: 10) {
            SGroupBox(label: "GIF Export") {
                SItem(label: "Frame Rate") {
                    Picker("", selection: $gifFrameRate) {
                        Text("10 FPS").tag(10)
                        Text("15 FPS").tag(15)
                        Text("20 FPS").tag(20)
                        Text("25 FPS").tag(25)
                        Text("30 FPS").tag(30)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                SDivider()
                SItem(label: "Quality") {
                    Slider(value: $gifQuality, in: 0.3...1.0, step: 0.1)
                        .frame(width: 150)
                    Text(String(format: "%.0f%%", gifQuality * 100))
                        .foregroundColor(.secondary)
                        .frame(width: 50)
                }
                SDivider()
                SItem(label: "Max Width") {
                    Picker("", selection: $gifMaxWidth) {
                        Text("480px").tag(480)
                        Text("640px").tag(640)
                        Text("800px").tag(800)
                        Text("1024px").tag(1024)
                        Text("1280px").tag(1280)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
                SDivider()
                SItem(label: "Loop") {
                    Picker("", selection: $gifLoopCount) {
                        Text("Infinite").tag(0)
                        Text("Once").tag(1)
                        Text("Twice").tag(2)
                        Text("3 times").tag(3)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }

            SGroupBox(label: "Platform Presets") {
                SPicker("Default Platform", selection: $defaultExportPlatform) {
                    Text("YouTube (16:9)").tag("youtube")
                    Text("YouTube Shorts (9:16)").tag("youtubeShorts")
                    Text("TikTok (9:16)").tag("tiktok")
                    Text("Instagram Post (1:1)").tag("instagram")
                    Text("Instagram Story (9:16)").tag("instagramStory")
                    Text("Twitter/X (16:9)").tag("twitter")
                    Text("LinkedIn (16:9)").tag("linkedin")
                    Text("Custom").tag("custom")
                }
                Text("Platform presets automatically adjust resolution, aspect ratio, and bitrate for optimal playback.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            SGroupBox(label: "Audio Enhancement") {
                SToggle("Audio Normalization", isOn: $audioNormalizationEnabled, tips: "Normalize audio to consistent loudness level")
                SDivider()
                SItem(label: "Target Loudness (LUFS)") {
                    Picker("", selection: $audioNormalizationTarget) {
                        Text("-14 LUFS (YouTube)").tag(-14.0)
                        Text("-16 LUFS (Podcast)").tag(-16.0)
                        Text("-23 LUFS (Broadcast)").tag(-23.0)
                        Text("-24 LUFS (Streaming)").tag(-24.0)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 180)
                }.disabled(!audioNormalizationEnabled)
                SDivider()
                SToggle("Noise Reduction", isOn: $noiseReductionEnabled, tips: "Reduce background noise from recordings")
                SDivider()
                SItem(label: "Reduction Strength") {
                    Slider(value: $noiseReductionStrength, in: 0.1...1.0, step: 0.1)
                        .frame(width: 150)
                    Text(noiseReductionStrength < 0.4 ? "Gentle" : noiseReductionStrength < 0.7 ? "Medium" : "Strong")
                        .foregroundColor(.secondary)
                        .frame(width: 60)
                }.disabled(!noiseReductionEnabled)
            }

            SGroupBox(label: "Device Frame") {
                SToggle("Wrap in Device Frame", isOn: $deviceFrameEnabled, tips: "Add a device mockup around your recording")
                SDivider()
                SPicker("Device Type", selection: $deviceFrameType) {
                    Section(header: Text("Mac")) {
                        Text("MacBook Pro 14\"").tag("macbookPro14")
                        Text("MacBook Pro 16\"").tag("macbookPro16")
                        Text("MacBook Air 13\"").tag("macbookAir13")
                        Text("MacBook Air 15\"").tag("macbookAir15")
                        Text("iMac 24\"").tag("iMac24")
                        Text("Studio Display").tag("studioDisplay")
                    }
                    Section(header: Text("iPhone")) {
                        Text("iPhone 15 Pro").tag("iPhone15Pro")
                        Text("iPhone 15 Pro Max").tag("iPhone15ProMax")
                        Text("iPhone 15").tag("iPhone15")
                    }
                    Section(header: Text("iPad")) {
                        Text("iPad Pro 13\"").tag("iPadPro13")
                        Text("iPad Pro 11\"").tag("iPadPro11")
                        Text("iPad Air").tag("iPadAir")
                    }
                }.disabled(!deviceFrameEnabled)
                SDivider()
                SPicker("Frame Color", selection: $deviceFrameColor) {
                    Text("Space Black").tag("spaceBlack")
                    Text("Space Gray").tag("spaceGray")
                    Text("Silver").tag("silver")
                    Text("Starlight").tag("starlight")
                    Text("Midnight").tag("midnight")
                }.disabled(!deviceFrameEnabled)
                SDivider()
                SToggle("Add Shadow to Frame", isOn: $deviceFrameShadow).disabled(!deviceFrameEnabled)
            }
        }
    }
}

extension UserDefaults {
    func setColor(_ color: Color?, forKey key: String) {
        guard let color = color else {
            removeObject(forKey: key)
            return
        }
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: NSColor(color), requiringSecureCoding: false)
            set(data, forKey: key)
        } catch {
            print("Error archiving color:", error)
        }
    }
    
    func color(forKey key: String) -> Color? {
        guard let data = data(forKey: key),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return Color(nsColor)
    }
    
    func cgColor(forKey key: String) -> CGColor? {
        guard let data = data(forKey: key),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return nil
        }
        return nsColor.cgColor
    }
}

extension KeyboardShortcuts.Name {
    static let startWithAudio = Self("startWithAudio")
    static let startWithScreen = Self("startWithScreen")
    static let startWithWindow = Self("startWithWindow")
    static let startWithArea = Self("startWithArea")
    static let screenMagnifier = Self("screenMagnifier")
    static let saveFrame = Self("saveFrame")
    static let pauseResume = Self("pauseResume")
    static let stop = Self("stop")
    static let showPanel = Self("showPanel")
}

extension AppDelegate {
    @available(macOS 13.0, *)
    @objc func setLoginItem(_ sender: NSMenuItem) {
        sender.state = sender.state == .on ? .off : .on
        do {
            if sender.state == .on { try SMAppService.mainApp.register() }
            if sender.state == .off { try SMAppService.mainApp.unregister() }
        }catch{
            print("Failed to \(sender.state == .on ? "enable" : "disable") launch at login: \(error.localizedDescription)")
        }
    }
}
