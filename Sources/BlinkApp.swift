import SwiftUI

@main
struct BlinkApp: App {
    init() {
        NSApp.appearance = NSAppearance(named: .darkAqua)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
