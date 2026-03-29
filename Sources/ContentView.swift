import SwiftUI

struct ContentView: View {
    @StateObject private var videoStore = VideoStore.shared
    @State private var selectedDate: Date = Date()
    @State private var isRecording = false
    @State private var showRecordView = false

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var selectedVideoURL: URL? {
        if isToday {
            return videoStore.todaysVideo()
        } else {
            return videoStore.videoForDate(selectedDate)
        }
    }

    var body: some View {
        NavigationSplitView {
            CalendarView(selectedDate: $selectedDate, videoStore: videoStore)
                .frame(minWidth: 280)
        } detail: {
            ZStack {
                Theme.background.ignoresSafeArea()

                if isToday && !isRecording && videoStore.todaysVideo() == nil {
                    recordPromptView
                } else if isRecording {
                    RecordView(isRecording: $isRecording)
                } else if let url = selectedVideoURL {
                    PlaybackView(url: url, date: selectedDate)
                } else {
                    emptyStateView
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }

    private var recordPromptView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("REC")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.recordingRed)

                Text("Tap to record today's moment")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
            }

            Button {
                isRecording = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Theme.recordingRed)
                        .frame(width: Theme.recordButtonSize, height: Theme.recordButtonSize)

                    Circle()
                        .stroke(Theme.recordingRed.opacity(0.3), lineWidth: 4)
                        .frame(width: Theme.recordButtonSize + 16, height: Theme.recordButtonSize + 16)

                    Circle()
                        .fill(Theme.textPrimary)
                        .frame(width: 24, height: 24)
                }
            }
            .buttonStyle(.plain)
            .scaleEffect(isRecording ? 0.95 : 1.0)
            .accessibilityLabel("Record today's moment")
            .accessibilityHint("Tap to start recording a 30-second video")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary)

            Text("No video recorded")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text(formattedDate(selectedDate))
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Theme.textSecondary.opacity(0.6))
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
}
