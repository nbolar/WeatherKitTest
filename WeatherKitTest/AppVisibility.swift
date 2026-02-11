import SwiftUI
import AppKit
import Combine

@MainActor
final class AppVisibility: ObservableObject {
    static let shared = AppVisibility()

    @Published var isAppActive: Bool = NSApp.isActive
    @Published var isPopoverVisible: Bool = false

    // Menu bar popovers can be visible while NSApp reports inactive.
    // Keep effects running whenever the popover is shown.
    var effectsActive: Bool { isPopoverVisible || isAppActive }

    private init() {}
}
