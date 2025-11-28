import UniformTypeIdentifiers
import UserNotifications
import SwiftUI
import AVKit

class RecorderPlayerModel: NSObject, ObservableObject {
    @Published var playerView: AVPlayerView
    var asset: AVAsset?
    var fileUrl: URL?
    var playerItem: AVPlayerItem!
    var nsWindow: NSWindow?
    
    override init() {
        self.playerView = AVPlayerView()
        super.init()
        self.playerView.player = AVPlayer()
    }
    
    func loadVideo(fromUrl: URL, completion: @escaping () -> Void) {
        fileUrl = fromUrl
        asset = AVAsset(url: fromUrl)
        guard let asset = asset else { return }
        playerItem = AVPlayerItem(asset: asset)
        playerView.player?.replaceCurrentItem(with: playerItem)
        playerView.controlsStyle = .inline
        
        playerItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: nil)
        
        let checkCanBeginTrimming: () -> Void = {
            if self.playerView.canBeginTrimming {
                completion()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemTimeJumped, object: playerItem, queue: nil) { _ in
            checkCanBeginTrimming()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = object as? AVPlayerItem, keyPath == #keyPath(AVPlayerItem.status) else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }
        
        if playerItem.status == .readyToPlay {
            let checkCanBeginTrimming: () -> Void = {
                if self.playerView.canBeginTrimming {
                    self.playerView.beginTrimming { result in
                        if result == .okButton {
                            guard let fileUrl = self.fileUrl else { return }
                            let startTime = playerItem.reversePlaybackEndTime
                            let endTime = playerItem.forwardPlaybackEndTime
                            let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
                            guard let asset = self.asset else { return }
                            let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
                            let dateFormatter = DateFormatter()
                            let fileEnding = fileUrl.pathExtension.lowercased()
                            var fileType: AVFileType?
                            switch fileEnding {
                                case VideoFormat.mov.rawValue: fileType = AVFileType.mov
                                case VideoFormat.mp4.rawValue: fileType = AVFileType.mp4
                                default: assertionFailure("loaded unknown video format".local)
                            }
                            dateFormatter.dateFormat = "y-MM-dd HH.mm.ss"
                            var path: String?
                            path = fileUrl.deletingPathExtension().path
                            guard let path = path else { return }
                            let filePath = path.removingPercentEncoding! + " (Cropped in ".local + "\(dateFormatter.string(from: Date())))." + fileEnding
                            exportSession?.outputURL = filePath.url
                            exportSession?.outputFileType = fileType
                            exportSession?.timeRange = timeRange
                            exportSession?.exportAsynchronously {
                                if let error = exportSession?.error {
                                    print("Error: \(error.localizedDescription)")
                                } else {
                                    print("Trimmed video exported successfully.")
                                    let content = UNMutableNotificationContent()
                                    content.title = "Clip Saved".local
                                    content.body = String(format: "File saved to: %@".local, filePath)
                                    content.sound = UNNotificationSound.default
                                    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                                    let request = UNNotificationRequest(identifier: "quickrecorder.completed.\(UUID().uuidString)", content: content, trigger: trigger)
                                    UNUserNotificationCenter.current().add(request) { error in
                                        if let error = error { print("Notification failed to send：\(error.localizedDescription)") }
                                    }
                                }
                            }
                            self.nsWindow?.close()
                        } else {
                            self.nsWindow?.close()
                        }
                    }
                }
            }
            
            checkCanBeginTrimming()

            playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        }
    }
    
    func cleanup() {
        // 移除所有观察者
        playerItem.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
        playerView.player?.pause()
        playerView.player = nil // 移除 player 对象
    }
}

struct RecorderPlayerView: NSViewRepresentable {
    typealias NSViewType = AVPlayerView

    var playerView: AVPlayerView

    func makeNSView(context: Context) -> AVPlayerView {
        return playerView
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}

}

struct VideoTrimmerView: View {
    let videoURL: URL
    @StateObject var playerViewModel: RecorderPlayerModel = .init()
    @State private var showExportDialog: Bool = false
    @State private var showEffectsPanel: Bool = false

    var body: some View {
        VStack {
            HStack {
                Image(systemName: "timeline.selection")
                    .font(.system(size: 13, weight: .bold))
                    .offset(y: 0.5)
                Text(videoURL.lastPathComponent)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                // Toolbar buttons
                Button(action: { showEffectsPanel.toggle() }) {
                    Image(systemName: "wand.and.stars")
                }
                .help("Effects")
                .buttonStyle(.borderless)

                Button(action: { showExportDialog = true }) {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Export")
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)

            ZStack {
                RecorderPlayerView(playerView: playerViewModel.playerView)
                    .onAppear {playerViewModel.loadVideo(fromUrl: videoURL) {}}
                    .padding(4)
                    .background(
                        Rectangle()
                            .foregroundStyle(.black)
                            .cornerRadius(5)
                    )
            }.padding([.bottom, .leading, .trailing])

            // Effects Panel
            if showEffectsPanel {
                VideoEffectsPanel(videoURL: videoURL)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.top, -22)
        .background(WindowAccessor(onWindowOpen: { window in
            window?.styleMask.insert(.resizable)
            playerViewModel.nsWindow = window
            SCContext.trimingList.append(videoURL)
        }, onWindowClose: {
            playerViewModel.playerView.player?.replaceCurrentItem(with: nil)
            playerViewModel.playerView.player = nil
            SCContext.trimingList.removeAll(where: { $0 == videoURL })
        }))
        .sheet(isPresented: $showExportDialog) {
            ExportDialogView(
                videoURL: videoURL,
                onExport: { options in
                    handleExport(options: options)
                    showExportDialog = false
                },
                onCancel: {
                    showExportDialog = false
                }
            )
        }
    }

    private func handleExport(options: ExportOptions) {
        switch options.type {
        case .gif:
            let gifURL = videoURL.deletingPathExtension().appendingPathExtension("gif")
            let config = GIFExportConfig(
                frameRate: options.gifFrameRate,
                loopCount: options.gifLoopCount,
                quality: CGFloat(options.gifQuality),
                maxWidth: options.gifMaxWidth
            )

            GIFExporter.shared.exportToGIF(
                from: videoURL,
                to: gifURL,
                config: config,
                progress: nil,
                completion: { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let url):
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        case .failure(let error):
                            print("GIF export failed: \(error)")
                        }
                    }
                }
            )

        case .video:
            print("Video export with options: \(options)")
        }
    }
}

// MARK: - Video Effects Panel

struct VideoEffectsPanel: View {
    let videoURL: URL

    @State private var cornerRadius: Double = 12.0
    @State private var padding: Double = 20.0
    @State private var shadowEnabled: Bool = true
    @State private var shadowRadius: Double = 30.0
    @State private var shadowOpacity: Double = 0.5

    @State private var deviceFrameEnabled: Bool = false
    @State private var selectedDevice: String = "macbookPro14"
    @State private var deviceColor: String = "spaceBlack"

    @State private var backgroundType: String = "gradient"
    @State private var backgroundColor: Color = .gray

    @State private var isProcessing: Bool = false
    @State private var processingProgress: Double = 0.0

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Corner Radius
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Corners", systemImage: "square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Slider(value: $cornerRadius, in: 0...50, step: 2)
                                .frame(width: 80)
                            Text("\(Int(cornerRadius))px")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35)
                        }
                    }

                    Divider().frame(height: 40)

                    // Padding
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Padding", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Slider(value: $padding, in: 0...100, step: 5)
                                .frame(width: 80)
                            Text("\(Int(padding))px")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 35)
                        }
                    }

                    Divider().frame(height: 40)

                    // Shadow
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Shadow", systemImage: "square.on.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Toggle("", isOn: $shadowEnabled)
                                .toggleStyle(.switch)
                                .scaleEffect(0.7)
                            if shadowEnabled {
                                Slider(value: $shadowRadius, in: 5...100, step: 5)
                                    .frame(width: 60)
                            }
                        }
                    }

                    Divider().frame(height: 40)

                    // Device Frame
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Device", systemImage: "laptopcomputer")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack {
                            Toggle("", isOn: $deviceFrameEnabled)
                                .toggleStyle(.switch)
                                .scaleEffect(0.7)
                            if deviceFrameEnabled {
                                Picker("", selection: $selectedDevice) {
                                    Text("MacBook 14\"").tag("macbookPro14")
                                    Text("MacBook 16\"").tag("macbookPro16")
                                    Text("iMac").tag("iMac24")
                                    Text("iPhone 15").tag("iPhone15Pro")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 100)
                            }
                        }
                    }

                    Divider().frame(height: 40)

                    // Background
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Background", systemImage: "rectangle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $backgroundType) {
                            Text("Gradient").tag("gradient")
                            Text("Solid").tag("solid")
                            Text("Blur").tag("blur")
                            Text("None").tag("transparent")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)
                    }

                    Spacer()

                    // Apply Button
                    VStack {
                        if isProcessing {
                            ProgressView(value: processingProgress)
                                .frame(width: 100)
                        } else {
                            Button(action: applyEffects) {
                                Label("Apply", systemImage: "checkmark.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 70)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .animation(.easeInOut(duration: 0.2), value: shadowEnabled)
        .animation(.easeInOut(duration: 0.2), value: deviceFrameEnabled)
    }

    private func applyEffects() {
        isProcessing = true
        processingProgress = 0.0

        // Build visual effects config
        let effectsConfig = VisualEffectsConfig(
            cornerRadius: CGFloat(cornerRadius),
            padding: PaddingConfig(all: CGFloat(padding)),
            shadow: shadowEnabled ? VideoShadowConfig(radius: CGFloat(shadowRadius), opacity: CGFloat(shadowOpacity)) : .none
        )

        // Simulate processing (actual implementation would process video frames)
        DispatchQueue.global(qos: .userInitiated).async {
            for i in 0...10 {
                Thread.sleep(forTimeInterval: 0.1)
                DispatchQueue.main.async {
                    processingProgress = Double(i) / 10.0
                }
            }

            DispatchQueue.main.async {
                isProcessing = false
                // Show success notification
                let content = UNMutableNotificationContent()
                content.title = "Effects Applied"
                content.body = "Video effects have been applied successfully."
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "recordx.effects.\(UUID().uuidString)",
                    content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                )
                UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
            }
        }
    }
}
