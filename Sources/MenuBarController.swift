import AppKit
import SwiftUI
import AVFoundation
import AVKit

@MainActor
final class MenuBarController: NSObject {
    static var shared: MenuBarController { _shared }
    private static var _shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    private override init() {
        super.init()
    }

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "video.circle.fill", accessibilityDescription: "Blink")
            button.action = #selector(togglePopover)
            button.target = self
        }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarPopoverView())
        self.popover = popover
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.popover?.performClose(nil)
            }
        }
    }

    func showPopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func hidePopover() {
        popover?.performClose(nil)
    }
}

struct MenuBarPopoverView: View {
    @StateObject private var videoStore = VideoStore.shared
    @State private var showFullApp = false
    @State private var selectedVideo: URL?
    @State private var selectedDate: Date = Date()

    private var recentVideos: [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: videoStore.directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .filter { $0.pathExtension.lowercased() == "mov" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
            .prefix(6)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .background(Theme.surface)

            if recentVideos.isEmpty {
                emptyState
            } else {
                videoGrid
            }

            Divider()
                .background(Theme.surface)

            footerView
        }
        .frame(width: 320, height: 420)
        .background(Theme.background)
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "video.circle.fill")
                .foregroundColor(Theme.recordingRed)

            Text("Blink")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Text("\(recentVideos.count) recent")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "video.slash")
                .font(.system(size: 32))
                .foregroundColor(Theme.textSecondary)

            Text("No videos yet")
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)

            Text("Record your first moment")
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var videoGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(recentVideos, id: \.self) { url in
                VideoThumbnailCell(url: url, videoStore: videoStore)
                    .onTapGesture {
                        selectedVideo = url
                        selectedDate = videoStore.dateFromURL(url)
                    }
            }
        }
        .padding(12)
        .sheet(item: $selectedVideo) { url in
            VideoPlaybackSheet(url: url, date: videoStore.dateFromURL(url))
        }
    }

    private var footerView: some View {
        HStack {
            Button {
                openMainApp()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.on.rectangle")
                        .font(.system(size: 11))
                    Text("Open Blink")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Theme.textPrimary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Spacer()

            if videoStore.todaysVideo() != nil {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.recordingRed)
                        .frame(width: 6, height: 6)
                    Text("Today recorded")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                Text("Today: not recorded")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func openMainApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

struct VideoThumbnailCell: View {
    let url: URL
    @ObservedObject var videoStore: VideoStore

    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.surface)
                    .frame(width: 140, height: 90)
                    .overlay {
                        Image(systemName: "video")
                            .foregroundColor(Theme.textSecondary)
                    }
            }

            VStack {
                Spacer()
                HStack {
                    Text(formattedDate)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Capsule())
                    Spacer()
                }
            }
            .padding(6)
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private var formattedDate: String {
        let date = videoStore.dateFromURL(url)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let thumb = videoStore.generateThumbnail(for: url)
            DispatchQueue.main.async {
                thumbnail = thumb
            }
        }
    }
}

struct VideoPlaybackSheet: View {
    let url: URL
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(12)
            }

            Text(formattedDate)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textPrimary)

            if let player = player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
        .frame(width: 480, height: 400)
        .background(Theme.background)
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
