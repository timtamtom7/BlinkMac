import SwiftUI
import AVKit

// MARK: - SharedAlbumView

/// Main view for browsing and collaborating on shared albums.
struct SharedAlbumView: View {
    @StateObject private var sharingService = SharingService.shared
    @State private var selectedAlbum: SharedAlbum?
    @State private var showCreateSheet = false
    @State private var showInviteSheet = false
    @State private var selectedVideo: Video?
    @State private var newAlbumName = ""
    @State private var inviteEmail = ""
    @State private var inviteAlbumId: UUID?

    var body: some View {
        NavigationSplitView {
            albumListSidebar
        } detail: {
            if let album = selectedAlbum {
                AlbumDetailView(album: album, sharingService: sharingService)
            } else {
                emptySelectionView
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $showCreateSheet) {
            CreateAlbumSheet(isPresented: $showCreateSheet, sharingService: sharingService)
        }
        .sheet(isPresented: $showInviteSheet) {
            if let albumId = inviteAlbumId {
                InviteSheet(
                    isPresented: $showInviteSheet,
                    albumId: albumId,
                    sharingService: sharingService
                )
            }
        }
    }

    // MARK: - Sidebar

    private var albumListSidebar: some View {
        List(selection: $selectedAlbum) {
            Section("My Shared Albums") {
                ForEach(sharingService.sharedAlbums) { album in
                    NavigationLink(value: album) {
                        AlbumRowView(album: album, sharingService: sharingService)
                    }
                    .contextMenu {
                        Button("Invite someone...") {
                            inviteAlbumId = album.id
                            showInviteSheet = true
                        }
                        Button("Sync with iCloud") {
                            Task {
                                await sharingService.syncWithCloudKit()
                            }
                        }
                    }
                }
            }

            Section {
                Button {
                    showCreateSheet = true
                } label: {
                    Label("New Shared Album", systemImage: "plus.circle")
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Button {
                    Task {
                        await sharingService.syncWithCloudKit()
                    }
                } label: {
                    Label(
                        sharingService.isSyncing ? "Syncing..." : "Sync All",
                        systemImage: sharingService.isSyncing ? "arrow.triangle.2.circlepath" : "arrow.clockwise"
                    )
                }
                .buttonStyle(.plain)
                .disabled(sharingService.isSyncing)
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                if let lastSync = sharingService.lastSyncDate {
                    Text("Last sync: \(lastSync, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var emptySelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a shared album")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("Or create one to start collaborating with friends")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.7))
        }
    }
}

// MARK: - AlbumDetailView

struct AlbumDetailView: View {
    let album: SharedAlbum
    @ObservedObject var sharingService: SharingService
    @State private var selectedVideo: Video?
    @State private var newComment = ""
    @State private var commentAuthor = ""
    @State private var showCommentSheet = false
    @State private var commentTimestamp: Double?

    var body: some View {
        HSplitView {
            // Left: activity feed
            activityFeedPanel
                .frame(minWidth: 240, maxWidth: 320)

            // Right: video grid
            videoGridPanel
        }
        .sheet(item: $selectedVideo) { video in
            VideoCommentSheet(
                video: video,
                albumId: album.id,
                sharingService: sharingService
            )
        }
    }

    // MARK: - Activity Feed

    private var activityFeedPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Activity")
                .font(.headline)
                .padding()

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    let summary = sharingService.getActivitySummary(for: album)
                    ForEach(Array(summary.keys.sorted()), id: \.self) { participant in
                        if let count = summary[participant] {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.3))
                                    .frame(width: 32, height: 32)
                                    .overlay {
                                        Text(String(participant.prefix(1)).uppercased())
                                            .font(.caption.bold())
                                    }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(participant)
                                        .font(.subheadline.weight(.medium))
                                    Text("\(count) new video\(count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }

            Divider()

            HStack {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundColor(.secondary)
                Text("Auto-syncs via CloudKit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Video Grid

    private var videoGridPanel: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
                ForEach(album.videos) { video in
                    SharedAlbumVideoCell(video: video)
                        .onTapGesture {
                            selectedVideo = video
                        }
                }
            }
            .padding()
        }
        .navigationTitle(album.name)
        .navigationSubtitle("\(album.videos.count) videos · \(album.participants.count) participants")
    }
}

// MARK: - AlbumRowView

struct AlbumRowView: View {
    let album: SharedAlbum
    @ObservedObject var sharingService: SharingService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(album.name)
                .font(.subheadline.weight(.medium))

            HStack(spacing: 4) {
                Image(systemName: "video")
                    .font(.caption2)
                Text("\(album.videos.count) clips")
                    .font(.caption)

                Text("·")
                    .font(.caption)

                Image(systemName: "person.2")
                    .font(.caption2)
                Text("\(album.participants.count)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - SharedAlbumVideoCell

struct SharedAlbumVideoCell: View {
    let video: Video

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if let thumbnail = video.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 80)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 80)
                        .cornerRadius(6)
                        .overlay {
                            Image(systemName: "video")
                                .foregroundColor(.secondary)
                        }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formattedDate(video.recordedAt))
                            .font(.system(size: 9, design: .monospaced))
                            .padding(4)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .padding(4)
            }

            Text(formattedDate(video.recordedAt))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - CreateAlbumSheet

struct CreateAlbumSheet: View {
    @Binding var isPresented: Bool
    let sharingService: SharingService
    @State private var albumName = ""
    @State private var participants = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("New Shared Album")
                .font(.headline)

            TextField("Album name", text: $albumName)
                .textFieldStyle(.roundedBorder)

            TextField("Friends (comma-separated emails)", text: $participants)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Create") {
                    let emails = participants
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    _ = sharingService.createSharedAlbum(name: albumName, withFriends: emails)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(albumName.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

// MARK: - InviteSheet

struct InviteSheet: View {
    @Binding var isPresented: Bool
    let albumId: UUID
    let sharingService: SharingService
    @State private var email = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Invite to Album")
                .font(.headline)

            TextField("Friend's email", text: $email)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button("Send Invite") {
                    sharingService.inviteToAlbum(albumId: albumId, email: email)
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 320)
    }
}

// MARK: - VideoCommentSheet

struct VideoCommentSheet: View {
    let video: Video
    let albumId: UUID
    let sharingService: SharingService
    @Environment(\.dismiss) private var dismiss
    @State private var comments: [AlbumComment] = []
    @State private var newComment = ""
    @State private var authorName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Video preview
            ZStack {
                if let thumbnail = video.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay {
                            Image(systemName: "play.circle")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                        }
                }
            }

            Divider()

            // Comments
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(comments) { comment in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(comment.authorName)
                                    .font(.caption.weight(.medium))
                                if let ts = comment.videoTimestamp {
                                    Text("@ \(formatTimestamp(ts))")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(comment.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(comment.text)
                                .font(.subheadline)
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding()
            }
            .frame(maxHeight: 200)

            Divider()

            // Comment input
            HStack {
                TextField("Your name", text: $authorName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)

                TextField("Add a comment...", text: $newComment)
                    .textFieldStyle(.roundedBorder)

                Button {
                    let comment = AlbumComment(
                        authorName: authorName.isEmpty ? "Anonymous" : authorName,
                        text: newComment,
                        videoTimestamp: nil
                    )
                    sharingService.addComment(comment, toVideoAt: nil, inAlbum: albumId)
                    comments.append(comment)
                    newComment = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .disabled(newComment.isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 420)
    }

    private func formatTimestamp(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
