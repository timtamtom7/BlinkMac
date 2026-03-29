import SwiftUI
import AVFoundation
import AppKit

struct RecordView: View {
    @Binding var isRecording: Bool
    @StateObject private var videoStore = VideoStore.shared
    @State private var elapsedSeconds: Int = 0
    @State private var isPressed = false
    @State private var captureSession: AVCaptureSession?
    @State private var previewLayer: AVCaptureVideoPreviewLayer?
    @State private var movieOutput: AVCaptureMovieFileOutput?
    @State private var currentTempURL: URL?
    @State private var isSaving = false

    private let maxDuration: Int = 30
    private var progress: Double {
        min(Double(elapsedSeconds) / Double(maxDuration), 1.0)
    }

    private var timerDisplay: String {
        let current = String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60)
        let max = String(format: "%02d:%02d", maxDuration / 60, maxDuration % 60)
        return "\(current) / \(max)"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            cameraPreview
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer()

                HStack {
                    Text("REC")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.recordingRed)

                    Circle()
                        .fill(Theme.recordingRed)
                        .frame(width: 8, height: 8)

                    Text(timerDisplay)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Theme.background.opacity(0.8))
            }

            VStack {
                Spacer()

                recordButton
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            setupCamera()
            startRecording()
        }
        .onDisappear {
            stopCamera()
        }
    }

    private var cameraPreview: some View {
        GeometryReader { geometry in
            if let layer = previewLayer {
                CameraPreviewView(previewLayer: layer)
                    .frame(width: geometry.size.width, height: geometry.size.height)
            } else {
                Rectangle()
                    .fill(Theme.surface)
                    .overlay {
                        Text("Camera unavailable")
                            .foregroundColor(Theme.textSecondary)
                    }
            }
        }
    }

    private var recordButton: some View {
        ZStack {
            Circle()
                .stroke(Theme.recordingRed.opacity(0.3), lineWidth: 4)
                .frame(width: Theme.progressRingSize, height: Theme.progressRingSize)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.recordingRed, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: Theme.progressRingSize, height: Theme.progressRingSize)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(Theme.recordingRed)
                .frame(width: Theme.recordButtonSize, height: Theme.recordButtonSize)
                .scaleEffect(isPressed ? 0.9 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)

            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.textPrimary)
                .frame(width: 24, height: 24)
        }
        .accessibilityLabel("Record button")
        .accessibilityHint(isRecording ? "Tap to stop recording" : "Tap to start recording")
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in
                    isPressed = false
                    stopRecording()
                }
        )
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            return
        }
        session.addInput(input)

        let output = AVCaptureMovieFileOutput()
        output.maxRecordedDuration = CMTime(seconds: Double(maxDuration), preferredTimescale: 600)
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        captureSession = session
        movieOutput = output
        previewLayer = layer
    }

    private func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("Blink_temp_\(UUID().uuidString).mov")
        currentTempURL = tempURL
        movieOutput?.startRecording(to: tempURL, recordingDelegate: RecordingDelegate.shared)

        startTimer()
    }

    private func stopRecording() {
        movieOutput?.stopRecording()
        isRecording = false
    }

    private func startTimer() {
        elapsedSeconds = 0
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            elapsedSeconds += 1
            if elapsedSeconds >= maxDuration {
                timer.invalidate()
                stopRecording()
            }
        }
    }

    private func stopCamera() {
        captureSession?.stopRunning()
        captureSession = nil
    }
}

final class RecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    static let shared = RecordingDelegate()

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
            return
        }

        Task {
            do {
                _ = try VideoStore.shared.saveVideo(from: outputFileURL)
            } catch {
                print("Save error: \(error)")
            }
        }
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        previewLayer.frame = view.bounds
        view.layer = previewLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        previewLayer.frame = nsView.bounds
    }
}
