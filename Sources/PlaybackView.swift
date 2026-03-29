import SwiftUI
import AVKit

struct PlaybackView: View {
    let url: URL
    let date: Date

    @State private var player: AVPlayer?

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                dateOverlay
                    .padding(.top, 16)

                videoPlayer
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding()

                Spacer()
            }
        }
        .onAppear {
            player = AVPlayer(url: url)
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private var dateOverlay: some View {
        HStack {
            Spacer()

            Text(formattedDate)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.surface.opacity(0.9))
                .clipShape(Capsule())

            Spacer()
        }
    }

    private var videoPlayer: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(Theme.surface)
                    .overlay {
                        ProgressView()
                            .tint(Theme.textSecondary)
                    }
            }
        }
    }
}
