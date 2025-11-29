//
//  PreviewView.swift
//  RecordX
//
//  Created by apple on 2024/12/10.
//

import SwiftUI
import Combine

struct PreviewView: View {
    let frame: NSImage
    let filePath: String
    private let sharingDelegate = SharingServicePickerDelegate()
    @State private var isHovered: Bool = false
    @State private var isHovered2: Bool = false
    @State private var isSharing: Bool = false
    @State private var nsWindow: NSWindow?
    @State private var opacity: Double = 0.0
    @State private var showExportDialog: Bool = false
    @State private var isExportingGIF: Bool = false
    @State private var exportProgress: Double = 0.0
    @AppStorage("trimAfterRecord")  private var trimAfterRecord: Bool = false
    
    var body: some View {
        ZStack(alignment: Alignment(horizontal: .leading, vertical: .top)) {
            ZStack {
                Color.clear
                    .background(.ultraThickMaterial)
                    .environment(\.controlActiveState, .active)
                    .cornerRadius(6)
                ZStack {
                    Image(nsImage: frame)
                        .resizable().scaledToFit()
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1.5)
                    if isHovered2 {
                        Button(action: {
                            if fd.fileExists(atPath: filePath) {
                                NSWorkspace.shared.open(filePath.url)
                                closeWindow()
                            }
                        }, label: {
                            ZStack {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 49))
                                    .foregroundStyle(.black)
                                    .opacity(0.5)
                                Image(systemName: "play.circle")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 4)
                            }
                        }).buttonStyle(.plain)
                    }
                }
                .onHover(perform: { isHovered2 = $0 })
                .padding(8)
            }
            if isHovered {
                HoverButton(color: .buttonRed, secondaryColor: .buttonRedDark,
                            action: { closeWindow() }, label: {
                    ZStack {
                        Image(systemName: "circle.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                        Image(systemName: "circle.fill")
                            .font(.title2)
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .black))
                            .foregroundStyle(.white)
                    }
                }).padding(4)
            }
        }
        .opacity(opacity)
        .onHover(perform: { isHovered = $0 })
        .background(WindowAccessor(onWindowOpen: { w in nsWindow = w }))
        .onAppear {
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1.0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                if !isHovered && !isSharing { closeWindow() }
            }
        }
        .onChange(of: isHovered) { newValue in
            if !newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                    if !isHovered && !isSharing { closeWindow() }
                }
            }
        }
        .contextMenu {
            Button("Show in Finder") {
                if fd.fileExists(atPath: filePath) {
                    NSWorkspace.shared.activateFileViewerSelecting([filePath.url])
                }
                closeWindow()
            }
            Button("Delete") {
                do {
                    try fd.removeItem(atPath: filePath)
                } catch {
                    print("Failed to delete file: \(error.localizedDescription)")
                }
                closeWindow()
            }
            Divider()
            Button("Copy") {
                if fd.fileExists(atPath: filePath) {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.writeObjects([filePath.url as NSURL])
                }
                closeWindow()
            }
            Button("共享...") { showSharingServicePicker(for: filePath.url) }
            Divider()
            if !trimAfterRecord {
                Button("Trim") {
                    if fd.fileExists(atPath: filePath) {
                        AppDelegate.shared.createNewWindow(view: VideoTrimmerView(videoURL: filePath.url), title: filePath.lastPathComponent, only: false)
                    }
                    closeWindow()
                }
            }
            if ["mp4", "mov"].contains(filePath.pathExtension) {
                Divider()
                Button("Export...") {
                    if fd.fileExists(atPath: filePath) {
                        openExportDialog()
                    }
                }
                Button("Quick Export as GIF") {
                    if fd.fileExists(atPath: filePath) {
                        exportAsGIF()
                    }
                }
                Divider()
            }
            Button("Close") { closeWindow() }
        }
    }
    
    func openURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func closeWindow() {
        withAnimation(.easeIn(duration: 0.2)) { opacity = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            nsWindow?.close()
        }
    }
    
    private func isAppInstalled(id: String) -> Bool {
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
    }

    private func openExportDialog() {
        let exportView = ExportDialogView(
            videoURL: filePath.url,
            onExport: { options in
                performExport(options: options)
            },
            onCancel: {
                // Dialog cancelled
            }
        )
        AppDelegate.shared.createNewWindow(view: exportView, title: "Export - \(filePath.lastPathComponent)", only: false)
        closeWindow()
    }

    private func exportAsGIF() {
        let videoURL = filePath.url
        let gifURL = videoURL.deletingPathExtension().appendingPathExtension("gif")

        // Get GIF settings from AppStorage
        let config = GIFExportConfig(
            frameRate: UserDefaults.standard.integer(forKey: "gifFrameRate") == 0 ? 15 : UserDefaults.standard.integer(forKey: "gifFrameRate"),
            loopCount: UserDefaults.standard.integer(forKey: "gifLoopCount"),
            quality: UserDefaults.standard.double(forKey: "gifQuality") == 0 ? 0.8 : UserDefaults.standard.double(forKey: "gifQuality"),
            maxWidth: UserDefaults.standard.integer(forKey: "gifMaxWidth") == 0 ? 640 : UserDefaults.standard.integer(forKey: "gifMaxWidth")
        )

        isExportingGIF = true

        GIFExporter.shared.exportToGIF(
            from: videoURL,
            to: gifURL,
            config: config,
            progress: { progress in
                DispatchQueue.main.async {
                    self.exportProgress = progress
                }
            },
            completion: { result in
                DispatchQueue.main.async {
                    self.isExportingGIF = false
                    switch result {
                    case .success(let url):
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    case .failure(let error):
                        print("GIF export failed: \(error.localizedDescription)")
                        let alert = NSAlert()
                        alert.messageText = "GIF Export Failed"
                        alert.informativeText = error.localizedDescription
                        alert.alertStyle = .warning
                        alert.runModal()
                    }
                }
            }
        )

        closeWindow()
    }

    private func performExport(options: ExportOptions) {
        let videoURL = filePath.url

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
            // Video export with effects will be handled by the export service
            print("Video export with options: \(options)")
        }
    }
    
    private func showSharingServicePicker(for url: URL) {
        if let window = nsWindow {
            isSharing = true
            sharingDelegate.onDidChooseService = { service in
                isSharing = false
                if service != nil {
                    DispatchQueue.main.async { closeWindow() }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        if !isHovered && !isSharing { closeWindow() }
                    }
                }
            }
            let sharingPicker = NSSharingServicePicker(items: [url])
            sharingPicker.delegate = sharingDelegate
            sharingPicker.show(relativeTo: .zero, of: window.contentView!, preferredEdge: .minY)
        }
    }
}

// 自定义 NSSharingServicePickerDelegate
class SharingServicePickerDelegate: NSObject, NSSharingServicePickerDelegate {
    var onDidChooseService: ((NSSharingService?) -> Void)?
    
    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        onDidChooseService?(service)
    }
}
