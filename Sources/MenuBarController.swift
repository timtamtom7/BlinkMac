import Foundation
import SwiftUI

// iOS stub: no menu bar on iOS
@MainActor
final class MenuBarController: ObservableObject {
    static var shared: MenuBarController { _shared }
    private static var _shared = MenuBarController()

    private init() {}

    func setup() {
        // No-op on iOS
    }
}
