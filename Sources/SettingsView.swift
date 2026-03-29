import SwiftUI

struct SettingsView: View {
    @StateObject private var videoStore = VideoStore.shared
    @State private var showDeleteConfirmation = false

    private var storageUsed: String {
        let videos = videosList.count
        return "\(videos) video\(videos == 1 ? "" : "s")"
    }

    private var videosList: [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: videoStore.directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "mov" }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
                return date1 > date2
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Storage")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)

                HStack {
                    Text("Videos stored")
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Text(storageUsed)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding()
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    Text("Location")
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Text(videoStore.directory.path)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(1)
                }
                .padding()
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.background)
    }
}
