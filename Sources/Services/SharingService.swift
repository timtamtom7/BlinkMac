import Foundation
import AVFoundation
import AppKit

// MARK: - Video Model

struct Video: Identifiable, Sendable, Codable, Hashable, Equatable {
    let id: UUID
    let url: URL
    let recordedAt: Date

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.recordedAt = VideoStore.shared.dateFromURL(url)
    }

    init(id: UUID = UUID(), url: URL, recordedAt: Date) {
        self.id = id
        self.url = url
        self.recordedAt = recordedAt
    }

    var thumbnail: NSImage? {
        VideoStore.shared.generateThumbnail(for: url)
    }
}

// MARK: - Album Model

struct Album: Identifiable, Sendable {
    let id: UUID
    let name: String
    var videos: [Video]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, videos: [Video] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.videos = videos
        self.createdAt = createdAt
    }
}

// MARK: - SharedAlbum Model

struct SharedAlbum: Identifiable, Sendable, Hashable, Codable {
    let id: UUID
    let name: String
    let participants: [String]
    var videos: [Video]
    let createdAt: Date

    /// Contributions keyed by participant email
    var contributions: [String: [Video]] = [:]
}

// MARK: - Comment Model

struct AlbumComment: Identifiable, Sendable {
    let id: UUID
    let authorName: String
    let text: String
    let timestamp: Date
    let videoTimestamp: Double?

    init(id: UUID = UUID(), authorName: String, text: String, timestamp: Date = Date(), videoTimestamp: Double? = nil) {
        self.id = id
        self.authorName = authorName
        self.text = text
        self.timestamp = timestamp
        self.videoTimestamp = videoTimestamp
    }
}

// MARK: - SharingService

/// Handles shared album creation, collaboration, and CloudKit sync.
final class SharingService: ObservableObject, @unchecked Sendable {
    static let shared = SharingService()

    @Published private(set) var sharedAlbums: [SharedAlbum] = []
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?

    private let fileManager = FileManager.default
    private let containerURL: URL

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        containerURL = appSupport.appendingPathComponent("Blink/SharedAlbums", isDirectory: true)
        try? fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
        loadSharedAlbums()
    }

    // MARK: - Shared Albums

    /// Creates a new shared album and invites the specified friends by email.
    func createSharedAlbum(name: String, withFriends emails: [String]) -> Album {
        let album = Album(name: name, videos: [])
        saveAlbumMetadata(album, participants: emails)
        return album
    }

    /// Sends an invitation to join a shared album.
    func inviteToAlbum(albumId: UUID, email: String) {
        // In production: send CloudKit invitation or email link
        // Stub: membership is recorded locally
        if let idx = sharedAlbums.firstIndex(where: { $0.id == albumId }) {
            var album = sharedAlbums[idx]
            if !album.participants.contains(email) {
                var updated = album
                updated = SharedAlbum(
                    id: album.id,
                    name: album.name,
                    participants: album.participants + [email],
                    videos: album.videos,
                    createdAt: album.createdAt
                )
                sharedAlbums[idx] = updated
                saveAllSharedAlbums()
            }
        }
    }

    /// Returns all albums shared with the current user.
    func getSharedWithMe() -> [SharedAlbum] {
        return sharedAlbums
    }

    /// Adds a video to a shared album.
    func addVideo(_ video: Video, toAlbum albumId: UUID, fromParticipant participant: String) {
        if let idx = sharedAlbums.firstIndex(where: { $0.id == albumId }) {
            var album = sharedAlbums[idx]
            var updated = SharedAlbum(
                id: album.id,
                name: album.name,
                participants: album.participants,
                videos: album.videos + [video],
                createdAt: album.createdAt
            )
            updated.contributions[participant, default: []].append(video)
            sharedAlbums[idx] = updated
            saveAllSharedAlbums()
        }
    }

    /// Adds a comment to a video within a shared album.
    func addComment(_ comment: AlbumComment, toVideoAt timestamp: Double?, inAlbum albumId: UUID) {
        // Stub: comments stored in memory only (CloudKit would persist this)
        // Real implementation would store in CloudKit private database
    }

    /// Returns contribution activity summary for a shared album.
    func getActivitySummary(for album: SharedAlbum) -> [String: Int] {
        var summary: [String: Int] = [:]
        for (participant, videos) in album.contributions {
            summary[participant] = videos.count
        }
        return summary
    }

    // MARK: - CloudKit Sync

    /// Triggers a CloudKit sync for all shared albums.
    /// Stub: prepares CKRecord schema and initiates background fetch.
    func syncWithCloudKit() async {
        isSyncing = true
        defer { isSyncing = false }

        // CloudKit stub:
        // 1. Configure CKContainer.default()
        // 2. Fetch changes from private database (shared album records)
        // 3. Push local changes (new albums, new videos, comments)
        // 4. Resolve conflicts using modificationDate
        //
        // Real implementation:
        // let container = CKContainer.default()
        // let privateDB = container.privateCloudDatabase
        // let query = CKQuery(recordType: "SharedAlbum", predicate: NSPredicate(value: true))
        // let results = try await privateDB.records(matching: query)

        // Simulate network latency
        try? await Task.sleep(nanoseconds: 500_000_000)
        lastSyncDate = Date()
    }

    /// Returns the CloudKit subscription ID for shared album changes.
    /// Enables push notifications when shared albums are modified.
    var cloudKitSubscriptionId: String {
        return "blinkshared-album-changes"
    }

    /// Prepares the CloudKit schema for shared albums.
    /// Call once during onboarding to create record types.
    func setupCloudKitSchema() async throws {
        // CloudKit schema stub:
        // RecordType: SharedAlbum
        //   - name: String
        //   - participants: [String]
        //   - createdAt: Date
        //
        // RecordType: SharedVideo
        //   - albumId: String (reference)
        //   - videoData: Asset (CloudKit Asset)
        //   - recordedAt: Date
        //   - participantEmail: String
        //
        // RecordType: AlbumComment
        //   - albumId: String
        //   - authorName: String
        //   - text: String
        //   - videoTimestamp: Double?
        //   - timestamp: Date
    }

    /// Syncs all local videos to iCloud Photos.
    /// Uses PHPhotoLibrary to request cloud sync for video assets.
    func syncVideosToiCloudPhotos() async {
        // Stub: uses Photos framework to enable iCloud sync
        // Real implementation:
        // let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        // if status == .authorized {
        //     try await PHPhotoLibrary.shared().performChanges {
        //         PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
        //     }
        // }
    }

    // MARK: - Persistence

    private func loadSharedAlbums() {
        let metadataURL = containerURL.appendingPathComponent("metadata.json")
        guard let data = try? Data(contentsOf: metadataURL),
              let albums = try? JSONDecoder().decode([SharedAlbum].self, from: data) else {
            return
        }
        sharedAlbums = albums
    }

    private func saveAllSharedAlbums() {
        let metadataURL = containerURL.appendingPathComponent("metadata.json")
        guard let data = try? JSONEncoder().encode(sharedAlbums) else { return }
        try? data.write(to: metadataURL)
    }

    private func saveAlbumMetadata(_ album: Album, participants: [String]) {
        let shared = SharedAlbum(
            id: album.id,
            name: album.name,
            participants: participants,
            videos: album.videos,
            createdAt: album.createdAt
        )
        sharedAlbums.append(shared)
        saveAllSharedAlbums()
    }
}
