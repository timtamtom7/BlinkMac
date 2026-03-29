import SwiftUI
import AVFoundation
import AVKit

/// Monthly highlight reel view — "Your March 2026"
/// Shows AI-generated compilation of the month's best moments.
struct MonthlyReelView: View {
    @StateObject private var videoStore = VideoStore.shared
    @State private var selectedYear: Int
    @State private var selectedMonth: Int
    @State private var categories: [SmartCategory] = []
    @State private var isGenerating = false
    @State private var generatingProgress: Double = 0
    @State private var showingExportSheet = false
    @State private var selectedClip: HighlightClip?
    @State private var isPlayingReel = false

    private let calendar = Calendar.current

    init() {
        let now = Date()
        _selectedYear = State(initialValue: Calendar.current.component(.year, from: now))
        _selectedMonth = State(initialValue: Calendar.current.component(.month, from: now))
    }

    private var monthName: String {
        let components = DateComponents(year: selectedYear, month: selectedMonth)
        let date = calendar.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private var videosThisMonth: [URL] {
        videoStore.videosForMonth(year: selectedYear, month: selectedMonth)
    }

    private var hasVideosThisMonth: Bool {
        !videosThisMonth.isEmpty
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if hasVideosThisMonth {
                mainContent
            } else {
                emptyStateView
            }

            if isGenerating {
                generatingOverlay
            }
        }
        .onAppear {
            loadCategories()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            reelHeader
                .padding(.horizontal, 24)
                .padding(.top, 20)

            if isPlayingReel, let clip = selectedClip {
                reelPlayerView(clip: clip)
            } else {
                categoriesListView
            }
        }
    }

    private var reelHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    previousMonth()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous month")

                Spacer()

                VStack(spacing: 4) {
                    Text("Your \(monthName)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(Theme.textPrimary)

                    Text("\(videosThisMonth.count) clips")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                }

                Spacer()

                Button {
                    nextMonth()
                } label: {
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next month")
            }

            HStack(spacing: 12) {
                Button {
                    generateReel()
                } label: {
                    Label("Generate Reel", systemImage: "wand.and.stars")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.recordingRed)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)
                .accessibilityLabel("Generate monthly reel")

                Button {
                    exportReel()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(categories.isEmpty)
                .accessibilityLabel("Export reel")
            }
        }
    }

    private var categoriesListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(categories) { category in
                    SmartCategoryRow(category: category)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
    }

    @ViewBuilder
    private func reelPlayerView(clip: HighlightClip) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    isPlayingReel = false
                    selectedClip = nil
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("Monthly Reel")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            VideoPreviewView(url: clip.videoURL)
                .frame(maxWidth: .infinity, maxHeight: 400)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

            VStack(spacing: 8) {
                Text(clip.sceneLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.textPrimary)

                Text(clip.reason)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)

                if let ts = clip.formattedTimestamp {
                    Text(ts)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary.opacity(0.6))
                }
            }
            .padding(.top, 16)

            Spacer()

            clipNavigationBar
        }
    }

    private var clipNavigationBar: some View {
        let allClips = categories.flatMap { $0.allVideos }
        let currentIdx = selectedClip.flatMap { c in
            allClips.firstIndex(where: { $0 == c.videoURL })
        } ?? 0

        return HStack {
            Button {
                navigateToPrevClip()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(currentIdx == 0)

            Spacer()

            Text("\(currentIdx + 1) / \(allClips.count)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Button {
                navigateToNextClip()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(currentIdx >= allClips.count - 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)
                .accessibilityLabel("No clips available")

            Text("No clips this month")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text("Record some moments to see your monthly reel")
                .font(.system(size: 14))
                .foregroundColor(Theme.textSecondary.opacity(0.7))

            monthNavigator
        }
        .accessibilityElement(children: .combine)
    }

    private var monthNavigator: some View {
        HStack(spacing: 16) {
            Button {
                previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Text(monthName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .frame(minWidth: 140)

            Button {
                nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
        .padding(.top, 8)
    }

    // MARK: - Generating Overlay

    private var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Generating your reel…")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                ProgressView(value: generatingProgress)
                    .frame(width: 200)
                    .tint(Theme.recordingRed)
            }
        }
    }

    // MARK: - Actions

    private func loadCategories() {
        guard hasVideosThisMonth else {
            categories = []
            return
        }

        Task {
            let cats = await SmartCategorizationService.shared.buildCategories(for: videosThisMonth)
            await MainActor.run {
                categories = cats
            }
        }
    }

    private func generateReel() {
        guard hasVideosThisMonth else { return }

        isGenerating = true
        generatingProgress = 0

        Task {
            let clips = await SmartCategorizationService.shared.selectHighlightClips(
                from: videosThisMonth,
                maxClips: 10
            )

            await MainActor.run {
                generatingProgress = 1.0

                if let first = clips.first {
                    selectedClip = first
                    isPlayingReel = true
                }

                isGenerating = false
            }
        }
    }

    private func exportReel() {
        showingExportSheet = true
    }

    private func previousMonth() {
        if let date = calendar.date(byAdding: .month, value: -1, to: DateComponents(year: selectedYear, month: selectedMonth, day: 1).date ?? Date()) {
            selectedYear = calendar.component(.year, from: date)
            selectedMonth = calendar.component(.month, from: date)
            isPlayingReel = false
            selectedClip = nil
            loadCategories()
        }
    }

    private func nextMonth() {
        if let date = calendar.date(byAdding: .month, value: 1, to: DateComponents(year: selectedYear, month: selectedMonth, day: 1).date ?? Date()) {
            selectedYear = calendar.component(.year, from: date)
            selectedMonth = calendar.component(.month, from: date)
            isPlayingReel = false
            selectedClip = nil
            loadCategories()
        }
    }

    private func navigateToPrevClip() {
        let allClips = categories.flatMap { $0.allVideos }
        guard let current = selectedClip,
              let idx = allClips.firstIndex(where: { $0 == current.videoURL }),
              idx > 0 else { return }
        selectedClip = HighlightClip(
            videoURL: allClips[idx - 1],
            reason: current.reason,
            sceneLabel: current.sceneLabel,
            timestamp: nil
        )
    }

    private func navigateToNextClip() {
        let allClips = categories.flatMap { $0.allVideos }
        guard let current = selectedClip,
              let idx = allClips.firstIndex(where: { $0 == current.videoURL }),
              idx < allClips.count - 1 else { return }
        selectedClip = HighlightClip(
            videoURL: allClips[idx + 1],
            reason: current.reason,
            sceneLabel: current.sceneLabel,
            timestamp: nil
        )
    }
}

// MARK: - Smart Category Row

struct SmartCategoryRow: View {
    let category: SmartCategory
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(Theme.recordingRed)
                        .frame(width: 24)

                    Text(category.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Text("\(category.totalVideos)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.surface)
                        .clipShape(Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 20)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.title), \(category.totalVideos) videos")
            .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")

            if isExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(category.items) { item in
                            ForEach(item.videos, id: \.absoluteString) { url in
                                VideoThumbnailView(url: url)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let image = thumbnail {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.background)
                    .frame(width: 100, height: 80)
                    .overlay {
                        ProgressView()
                            .tint(Theme.textSecondary)
                    }
            }
        }
        .accessibilityLabel("Video thumbnail")
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        thumbnail = VideoStore.shared.generateThumbnail(for: url)
    }
}

// MARK: - Video Preview View

struct VideoPreviewView: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .onAppear {
                        player.seek(to: .zero)
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                    }
            } else {
                Rectangle()
                    .fill(Theme.surface)
                    .overlay {
                        ProgressView()
                            .tint(Theme.textSecondary)
                    }
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
    }
}
