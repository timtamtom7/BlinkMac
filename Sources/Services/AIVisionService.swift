import Foundation
import Vision
import AVFoundation
import CoreImage

/// AI-powered vision analysis service using Apple's Vision framework.
/// Detects faces, classifies scenes, identifies objects, and tags key moments.
@MainActor
final class AIVisionService {
    static let shared = AIVisionService()

    private lazy var sceneClassificationRequest: VNClassifyImageRequest? = {
        VNClassifyImageRequest()
    }()

    private init() {}

    // MARK: - Public API

    /// Analyzes a single video frame for scene understanding.
    /// - Parameter pixelBuffer: CVPixelBuffer from video frame
    /// - Returns: SceneAnalysis with scene label, face count, confidence, and key moment flag
    nonisolated func analyzeFrame(_ pixelBuffer: CVPixelBuffer) async -> SceneAnalysis {
        var detectedFaces = 0
        var sceneLabel = "Unknown"
        var confidence: Double = 0.0
        var keyMoment = false

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Detect faces
        do {
            let request = VNDetectFaceRectanglesRequest()
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([request])
            detectedFaces = request.results?.count ?? 0
        } catch {
            // Face detection failed, continue without it
        }

        // Classify scene using a local request each time
        do {
            let classificationRequest = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([classificationRequest])
            if let results = classificationRequest.results,
               let top = results.first {
                sceneLabel = top.identifier.capitalized
                confidence = Double(top.confidence)

                // Detect key moments based on scene labels
                keyMoment = Self.keyMomentLabels.contains { label in
                    top.identifier.localizedCaseInsensitiveContains(label)
                }
            }
        } catch {
            // Classification failed, use defaults
        }

        // Boost key moment detection when faces are present
        if detectedFaces > 0 && !keyMoment {
            keyMoment = detectedFaces >= 2
        }

        return SceneAnalysis(
            sceneLabel: sceneLabel,
            confidence: confidence,
            detectedFaces: detectedFaces,
            keyMoment: keyMoment
        )
    }

    /// Analyzes a video file and returns an aggregated analysis.
    /// Samples frames throughout the video for scene detection.
    nonisolated func analyzeVideo(at url: URL) async throws -> VideoAnalysis {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard durationSeconds > 0 else {
            return VideoAnalysis(scenes: [], keyMoments: [], faceCountBySecond: [:])
        }

        var scenes: [SceneAnalysis] = []
        var keyMoments: [KeyMoment] = []
        var faceCountBySecond: [Int: Int] = [:]

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // Sample up to 10 frames spread across the video
        let sampleCount = min(10, Int(durationSeconds))
        guard sampleCount > 0 else {
            return VideoAnalysis(scenes: [], keyMoments: [], faceCountBySecond: [:])
        }

        for i in 0..<sampleCount {
            let timeSeconds = (Double(i) / Double(sampleCount)) * durationSeconds
            let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)

            do {
                let (cgImage, _) = try await generator.image(at: time)
                let pixelBuffer = try PixelBufferFactory.make(from: cgImage)
                let analysis = await analyzeFrame(pixelBuffer)

                scenes.append(analysis)
                faceCountBySecond[Int(timeSeconds)] = analysis.detectedFaces

                if analysis.keyMoment {
                    keyMoments.append(KeyMoment(
                        timestamp: timeSeconds,
                        sceneLabel: analysis.sceneLabel,
                        faceCount: analysis.detectedFaces,
                        confidence: analysis.confidence
                    ))
                }
            } catch {
                // Skip failed frames
            }
        }

        return VideoAnalysis(
            scenes: scenes,
            keyMoments: keyMoments,
            faceCountBySecond: faceCountBySecond
        )
    }

    /// Returns a human-readable description of the scene.
    nonisolated func describeScene(_ analysis: SceneAnalysis) -> String {
        var description: String

        if analysis.detectedFaces == 0 {
            description = "Solo moment"
        } else if analysis.detectedFaces == 1 {
            description = "One person"
        } else {
            description = "\(analysis.detectedFaces) people"
        }

        if analysis.sceneLabel != "Unknown" {
            description += " — \(analysis.sceneLabel) scene"
        }

        if analysis.keyMoment {
            description += " ✦"
        }

        return description
    }

    // MARK: - Key Moment Labels

    private nonisolated(unsafe) static let keyMomentLabels: Set<String> = [
        "birthday", "celebday", "party", "wedding", "concert",
        "beach", "sunset", "sunrise", "dinner", "holiday",
        "christmas", "halloween", "thanksgiving", "graduation",
        "sport", "game", "festival", "outdoor", "park"
    ]
}

// MARK: - Models

struct SceneAnalysis: Sendable {
    let sceneLabel: String
    let confidence: Double
    let detectedFaces: Int
    let keyMoment: Bool
}

struct VideoAnalysis: Sendable {
    let scenes: [SceneAnalysis]
    let keyMoments: [KeyMoment]
    let faceCountBySecond: [Int: Int]

    var dominantScene: String {
        let counts = Dictionary(grouping: scenes, by: { $0.sceneLabel }).mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "Unknown"
    }

    var totalFacesDetected: Int {
        faceCountBySecond.values.reduce(0, +)
    }
}

struct KeyMoment: Sendable, Identifiable {
    let id = UUID()
    let timestamp: Double
    let sceneLabel: String
    let faceCount: Int
    let confidence: Double

    var formattedTimestamp: String {
        let minutes = Int(timestamp) / 60
        let seconds = Int(timestamp) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Pixel Buffer Factory

enum PixelBufferFactory {
    static func make(from cgImage: CGImage) throws -> CVPixelBuffer {
        let width = cgImage.width
        let height = cgImage.height

        let attributes: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw PixelBufferError.creationFailed
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}

enum PixelBufferError: Error {
    case creationFailed
}
