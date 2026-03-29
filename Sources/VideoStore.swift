import Foundation
import AVFoundation
import AppKit

final class VideoStore: ObservableObject, @unchecked Sendable {
    static let shared = VideoStore()

    private let fileManager = FileManager.default
    private let blinkDirectory: URL

    @Published var todaysVideoURL: URL?

    init() {
        let moviesURL = fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first!
        blinkDirectory = moviesURL.appendingPathComponent("Blink", isDirectory: true)

        if !fileManager.fileExists(atPath: blinkDirectory.path) {
            try? fileManager.createDirectory(at: blinkDirectory, withIntermediateDirectories: true)
        }

        refresh()
    }

    var directory: URL { blinkDirectory }

    func todaysVideo() -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let filename = "Blink_\(dateString).mov"
        let url = blinkDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func videoForDate(_ date: Date) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let filename = "Blink_\(dateString).mov"
        let url = blinkDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func videosForMonth(year: Int, month: Int) -> [URL] {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }

        var videos: [URL] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for day in range {
            components.day = day
            if let date = calendar.date(from: components) {
                let dateString = formatter.string(from: date)
                let filename = "Blink_\(dateString).mov"
                let url = blinkDirectory.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: url.path) {
                    videos.append(url)
                }
            }
        }
        return videos
    }

    func saveVideo(from tempURL: URL) throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        let filename = "Blink_\(dateString).mov"
        let destinationURL = blinkDirectory.appendingPathComponent(filename)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.moveItem(at: tempURL, to: destinationURL)
        refresh()
        return destinationURL
    }

    func refresh() {
        todaysVideoURL = todaysVideo()
    }

    func generateThumbnail(for url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 300, height: 300)

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } catch {
            return nil
        }
    }
}
