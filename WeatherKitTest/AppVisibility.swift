import SwiftUI
import AppKit
import Combine

@MainActor
final class AppVisibility: ObservableObject {
    static let shared = AppVisibility()

    // `NSApp` is nil while the SwiftUI `App` is still bootstrapping.
    @Published var isAppActive: Bool = false
    @Published var isPopoverVisible: Bool = false
    @Published var isMainWindowVisible: Bool = false
    @Published var popoverPresentationID = UUID()

    // Keep weather motion alive only while a visible weather surface is on-screen.
    var hasVisibleWeatherSurface: Bool { isPopoverVisible || isMainWindowVisible }
    var effectsActive: Bool { hasVisibleWeatherSurface }
    var allowsLiveMainWindowRendering: Bool { isMainWindowVisible }

    private init() {}

    func beginPopoverPresentation() {
        popoverPresentationID = UUID()
        isPopoverVisible = true
    }

    func endPopoverPresentation() {
        isPopoverVisible = false
    }
}
