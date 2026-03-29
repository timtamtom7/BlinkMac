import Foundation
import CloudKit

/// Represents a shared album containing videos
struct Album: Identifiable, Codable {
    let id: UUID
    var name: String
    var ownerID: String
    var participantIDs: [String]
    var videoIDs: [UUID]
    let createdAt: Date

    init(id: UUID = UUID(), name: String, ownerID: String, participantIDs: [String] = [], videoIDs: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.ownerID = ownerID
        self.participantIDs = participantIDs
        self.videoIDs = videoIDs
        self.createdAt = createdAt
    }
}

/// Service for managing shared albums and CloudKit synchronization
final class SharingService {
    static let shared = SharingService()

    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let sharedDatabase: CKDatabase

    private let albumRecordType = "SharedAlbum"
    private let videoRecordType = "SharedVideo"

    private init() {
        container = CKContainer.default()
        privateDatabase = container.privateCloudDatabase
        sharedDatabase = container.sharedCloudDatabase
    }

    // MARK: - Shared Albums

    /// Creates a new shared album with specified friends
    /// - Parameters:
    ///   - name: The name/title of the album
    ///   - withFriends: Array of friend identifiers (email or phone numbers)
    /// - Returns: The created Album object
    func createSharedAlbum(name: String, withFriends friends: [String]) -> Album {
        let ownerID = currentUserID()
        let album = Album(
            name: name,
            ownerID: ownerID,
            participantIDs: friends
        )

        saveAlbumToCloud(album)
        return album
    }

    /// Adds a video to an existing shared album
    func addVideo(_ videoID: UUID, to albumID: UUID) async throws {
        guard let record = try await fetchAlbumRecord(albumID) else {
            throw SharingError.albumNotFound
        }

        var videoIDs = (record["videoIDs"] as? [UUID]) ?? []
        if !videoIDs.contains(videoID) {
            videoIDs.append(videoID)
            record["videoIDs"] = videoIDs

            try await privateDatabase.save(record)
        }
    }

    /// Removes a video from a shared album
    func removeVideo(_ videoID: UUID, from albumID: UUID) async throws {
        guard let record = try await fetchAlbumRecord(albumID) else {
            throw SharingError.albumNotFound
        }

        var videoIDs = (record["videoIDs"] as? [UUID]) ?? []
        videoIDs.removeAll { $0 == videoID }
        record["videoIDs"] = videoIDs

        try await privateDatabase.save(record)
    }

    /// Invites a friend to an album
    func inviteFriend(_ friendID: String, to albumID: UUID) async throws {
        guard let record = try await fetchAlbumRecord(albumID) else {
            throw SharingError.albumNotFound
        }

        var participantIDs = (record["participantIDs"] as? [String]) ?? []
        if !participantIDs.contains(friendID) {
            participantIDs.append(friendID)
            record["participantIDs"] = participantIDs

            try await privateDatabase.save(record)
        }
    }

    /// Fetches all shared albums for the current user
    func fetchSharedAlbums() async throws -> [Album] {
        let predicate = NSPredicate(format: "ownerID == %@ OR participantIDs CONTAINS %@", currentUserID(), currentUserID())
        let query = CKQuery(recordType: albumRecordType, predicate: predicate)

        let result = try await privateDatabase.records(matching: query)
        let records = result.matchResults.compactMap { try? $0.1.get() }

        return records.compactMap { albumFromRecord($0) }
    }

    // MARK: - CloudKit Video Sync

    /// Syncs a video to iCloud
    /// - Parameters:
    ///   - localURL: Local file URL of the video
    ///   - metadata: Optional metadata dictionary
    /// - Returns: The CloudKit record ID of the uploaded video
    func syncVideoToCloud(localURL: URL, metadata: [String: Any]? = nil) async throws -> CKRecord.ID {
        let recordID = CKRecord.ID(recordName: UUID().uuidString)
        let record = CKRecord(recordType: videoRecordType, recordID: recordID)

        // Load video data
        let videoData = try Data(contentsOf: localURL)
        let asset = CKAsset(fileURL: localURL)
        record["videoData"] = asset
        record["videoName"] = localURL.lastPathComponent
        record["uploadDate"] = Date()
        record["userID"] = currentUserID()

        if let metadata = metadata {
            record["metadata"] = metadata
        }

        try await privateDatabase.save(record)
        return recordID
    }

    /// Fetches all synced videos from iCloud
    func fetchSyncedVideos() async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "userID == %@", currentUserID())
        let query = CKQuery(recordType: videoRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "uploadDate", ascending: false)]

        let result = try await privateDatabase.records(matching: query)
        return result.matchResults.compactMap { try? $0.1.get() }
    }

    /// Deletes a video from iCloud
    func deleteVideoFromCloud(recordID: CKRecord.ID) async throws {
        try await privateDatabase.deleteRecord(withID: recordID)
    }

    /// Downloads a video from iCloud
    func downloadVideo(recordID: CKRecord.ID) async throws -> URL {
        let record = try await privateDatabase.record(for: recordID)

        guard let asset = record["videoData"] as? CKAsset,
              let fileURL = asset.fileURL else {
            throw SharingError.videoDataNotFound
        }

        // Return the file URL (file remains in CloudKit managed location)
        return fileURL
    }

    // MARK: - CloudKit Status

    /// Checks if iCloud is available and user is signed in
    func checkCloudKitAvailability() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func currentUserID() -> String {
        return CKCurrentUserDefaultName
    }

    private func saveAlbumToCloud(_ album: Album) {
        let recordID = CKRecord.ID(recordName: album.id.uuidString)
        let record = CKRecord(recordType: albumRecordType, recordID: recordID)

        record["name"] = album.name
        record["ownerID"] = album.ownerID
        record["participantIDs"] = album.participantIDs
        record["videoIDs"] = album.videoIDs
        record["createdAt"] = album.createdAt

        privateDatabase.save(record) { _, error in
            if let error = error {
                print("Failed to save album to CloudKit: \(error.localizedDescription)")
            }
        }
    }

    private func fetchAlbumRecord(_ albumID: UUID) async throws -> CKRecord? {
        let recordID = CKRecord.ID(recordName: albumID.uuidString)
        return try await privateDatabase.record(for: recordID)
    }

    private func albumFromRecord(_ record: CKRecord) -> Album? {
        guard let name = record["name"] as? String,
              let ownerID = record["ownerID"] as? String,
              let createdAt = record["createdAt"] as? Date else {
            return nil
        }

        return Album(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            ownerID: ownerID,
            participantIDs: record["participantIDs"] as? [String] ?? [],
            videoIDs: record["videoIDs"] as? [UUID] ?? [],
            createdAt: createdAt
        )
    }
}

// MARK: - Errors

enum SharingError: LocalizedError {
    case albumNotFound
    case videoDataNotFound
    case cloudKitUnavailable
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .albumNotFound:
            return "The requested album could not be found."
        case .videoDataNotFound:
            return "Video data could not be retrieved from iCloud."
        case .cloudKitUnavailable:
            return "iCloud is not available. Please sign in to iCloud."
        case .permissionDenied:
            return "Permission denied. Please check iCloud settings."
        }
    }
}
