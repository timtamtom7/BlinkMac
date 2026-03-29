import Foundation
import AVFoundation
import CoreMedia

/// Smart auto-categorization service for Blink videos.
/// Categorizes videos by people, places, events, and identifies "best moments".
@MainActor
final class SmartCategorizationService {
    static let shared = SmartCategorizationService()

    private let visionService = AIVisionService.shared

    private init() {}

    // MARK: - Public API

    /// Returns all smart categories with their associated videos.
    func buildCategories(for videos: [URL]) async -> [SmartCategory] {
        var categories: [SmartCategory] = []

        // Best moments first
        let bestMoments = await findBestMoments(videos: videos)
        if !bestMoments.allVideos.isEmpty {
            categories.append(bestMoments)
        }

        // Group by people
        let peopleCategory = await categorizeByPeople(videos: videos)
        if !peopleCategory.allVideos.isEmpty {
            categories.append(peopleCategory)
        }

        // Group by scene type
        let sceneCategories = await categorizeByScene(videos: videos)
        categories.append(contentsOf: sceneCategories)

        // Group by event (month)
        let eventCategories = await categorizeByEvent(videos: videos)
        categories.append(contentsOf: eventCategories)

        return categories
    }

    /// Returns "best moments" highlight clips from the given videos.
    func selectHighlightClips(from videos: [URL], maxClips: Int = 10) async -> [HighlightClip] {
        var clips: [HighlightClip] = []

        for videoURL in videos {
            if clips.count >= maxClips { break }

            do {
                let analysis = try await visionService.analyzeVideo(at: videoURL)
                if analysis.keyMoments.isEmpty {
                    let hasFaces = analysis.scenes.contains { $0.detectedFaces > 0 }
                    if hasFaces {
                        clips.append(HighlightClip(
                            videoURL: videoURL,
                            reason: "People together",
                            sceneLabel: analysis.dominantScene,
                            timestamp: nil
                        ))
                    }
                } else if let best = analysis.keyMoments.max(by: { $0.confidence < $1.confidence }) {
                    clips.append(HighlightClip(
                        videoURL: videoURL,
                        reason: best.sceneLabel,
                        sceneLabel: best.sceneLabel,
                        timestamp: best.timestamp
                    ))
                }
            } catch {
                // Skip failed videos
            }
        }

        return clips
    }

    // MARK: - Private Categorization

    private func categorizeByPeople(videos: [URL]) async -> SmartCategory {
        var alone: [URL] = []
        var duo: [URL] = []
        var group: [URL] = []

        for videoURL in videos {
            do {
                let analysis = try await visionService.analyzeVideo(at: videoURL)
                let avgFaces = analysis.scenes.isEmpty ? 0
                    : analysis.scenes.map { $0.detectedFaces }.reduce(0, +) / analysis.scenes.count

                if avgFaces == 0 {
                    alone.append(videoURL)
                } else if avgFaces <= 2 {
                    duo.append(videoURL)
                } else {
                    group.append(videoURL)
                }
            } catch {
                // Skip failed videos
            }
        }

        var items: [SmartCategory.Item] = []
        if !alone.isEmpty { items.append(SmartCategory.Item(label: "Solo", videos: alone)) }
        if !duo.isEmpty { items.append(SmartCategory.Item(label: "Pair", videos: duo)) }
        if !group.isEmpty { items.append(SmartCategory.Item(label: "Group", videos: group)) }

        return SmartCategory(
            id: UUID(),
            title: "People",
            icon: "person.2",
            items: items
        )
    }

    private func categorizeByScene(videos: [URL]) async -> [SmartCategory] {
        var sceneMap: [String: [URL]] = [:]

        for videoURL in videos {
            do {
                let analysis = try await visionService.analyzeVideo(at: videoURL)
                let dominant = analysis.dominantScene
                sceneMap[dominant, default: []].append(videoURL)
            } catch {
                // Skip
            }
        }

        return sceneMap.compactMap { scene, urls in
            guard !scene.contains("Unknown"), !urls.isEmpty else { return nil }
            return SmartCategory(
                id: UUID(),
                title: scene,
                icon: iconForScene(scene),
                items: [SmartCategory.Item(label: scene, videos: urls)]
            )
        }
    }

    private func categorizeByEvent(videos: [URL]) async -> [SmartCategory] {
        let cal = Calendar.current
        var monthMap: [String: [URL]] = [:]

        for videoURL in videos {
            let date = VideoStore.shared.dateFromURL(videoURL)
            let monthName = monthName(for: date, calendar: cal)
            monthMap[monthName, default: []].append(videoURL)
        }

        let order = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]

        return monthMap.compactMap { month, urls in
            guard !urls.isEmpty else { return nil }
            return SmartCategory(
                id: UUID(),
                title: month,
                icon: "calendar",
                items: [SmartCategory.Item(label: month, videos: urls)]
            )
        }.sorted { cat1, cat2 in
            let i1 = order.firstIndex(of: cat1.title) ?? 12
            let i2 = order.firstIndex(of: cat2.title) ?? 12
            return i1 > i2
        }
    }

    private func findBestMoments(videos: [URL]) async -> SmartCategory {
        var clips: [URL] = []

        for videoURL in videos {
            do {
                let analysis = try await visionService.analyzeVideo(at: videoURL)
                let hasKeyMoment = analysis.keyMoments.contains { $0.confidence > 0.6 }
                let hasMultipleFaces = analysis.scenes.contains { $0.detectedFaces >= 2 }

                if hasKeyMoment || hasMultipleFaces {
                    clips.append(videoURL)
                }
            } catch {
                // Skip
            }
        }

        return SmartCategory(
            id: UUID(),
            title: "Best Moments",
            icon: "star.fill",
            items: [SmartCategory.Item(label: "Highlights", videos: clips)]
        )
    }

    // MARK: - Helpers

    private func monthName(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date)
    }

    private func iconForScene(_ scene: String) -> String {
        let lower = scene.lowercased()
        if lower.contains("beach") || lower.contains("water") || lower.contains("ocean") {
            return "water.waves"
        } else if lower.contains("mountain") || lower.contains("outdoor") || lower.contains("park") {
            return "leaf"
        } else if lower.contains("home") || lower.contains("indoor") || lower.contains("room") {
            return "house"
        } else if lower.contains("city") || lower.contains("street") || lower.contains("urban") {
            return "building.2"
        } else if lower.contains("food") || lower.contains("restaurant") || lower.contains("dinner") {
            return "fork.knife"
        }
        return "photo"
    }
}

// MARK: - Models

struct SmartCategory: Identifiable, Sendable {
    let id: UUID
    let title: String
    let icon: String
    let items: [Item]

    var totalVideos: Int {
        items.reduce(0) { $0 + $1.videos.count }
    }

    var allVideos: [URL] {
        items.flatMap { $0.videos }
    }

    struct Item: Identifiable, Sendable {
        let id = UUID()
        let label: String
        let videos: [URL]
    }
}

struct HighlightClip: Identifiable, Sendable {
    let id = UUID()
    let videoURL: URL
    let reason: String
    let sceneLabel: String
    let timestamp: Double?

    var formattedTimestamp: String? {
        guard let ts = timestamp else { return nil }
        let minutes = Int(ts) / 60
        let seconds = Int(ts) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct PeopleGroup: Identifiable, Sendable {
    let id = UUID()
    let description: String
    let videos: [URL]
}
