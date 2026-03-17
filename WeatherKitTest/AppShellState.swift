import SwiftUI
import Combine
import AppKit

struct OverviewAlertNavigationRequest: Equatable {
    let requestID: UUID
    let alertKey: String
    let alertIndex: Int

    init(
        requestID: UUID = UUID(),
        alertKey: String,
        alertIndex: Int
    ) {
        self.requestID = requestID
        self.alertKey = alertKey
        self.alertIndex = alertIndex
    }

    init(
        target: WeatherAlertNavigationTarget,
        requestID: UUID = UUID()
    ) {
        self.init(
            requestID: requestID,
            alertKey: target.key,
            alertIndex: target.index
        )
    }
}

@MainActor
enum AppDestination: String, CaseIterable, Identifiable {
    case overview
    case map
    case alerts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .map:
            return "Map"
        case .alerts:
            return "Alerts"
        }
    }

    var systemImage: String {
        switch self {
        case .overview:
            return "sun.max"
        case .map:
            return "map"
        case .alerts:
            return "bell.badge"
        }
    }
}

@MainActor
final class AppShellState: ObservableObject {
    static let shared = AppShellState()

    @Published var selectedDestination: AppDestination = .overview
    @Published var pendingOverviewAlertRequest: OverviewAlertNavigationRequest?
    @Published var searchFocusRequest: UUID?
    weak var mainWindow: NSWindow?
    weak var settingsWindow: NSWindow?
    private var shouldPresentSettingsWhenAvailable = false

    private init() {}

    func open(_ destination: AppDestination) {
        selectedDestination = destination
    }

    func focusSearch() {
        searchFocusRequest = UUID()
    }

    func registerMainWindow(_ window: NSWindow?) {
        mainWindow = window
    }

    func registerSettingsWindow(_ window: NSWindow?) {
        settingsWindow = window

        guard let window else { return }

        if shouldPresentSettingsWhenAvailable {
            shouldPresentSettingsWhenAvailable = false
        }

        surfaceSettingsWindow(window)
    }

    func presentMainWindow(openIfNeeded: () -> Void) {
        NSApp.activate(ignoringOtherApps: true)

        if let mainWindow {
            if mainWindow.isMiniaturized {
                mainWindow.deminiaturize(nil)
            }
            mainWindow.makeKeyAndOrderFront(nil)
            return
        }

        openIfNeeded()
    }

    func showMainWindow(
        destination: AppDestination? = nil,
        focusSearch: Bool = false,
        overviewAlertRequest: OverviewAlertNavigationRequest? = nil,
        openIfNeeded: () -> Void
    ) {
        if let destination {
            open(destination)
        }

        if let overviewAlertRequest {
            pendingOverviewAlertRequest = overviewAlertRequest
        }

        if focusSearch {
            self.focusSearch()
        }

        presentMainWindow(openIfNeeded: openIfNeeded)
    }

    func prepareForSettingsPresentation() {
        NSApp.activate(ignoringOtherApps: true)

        if let settingsWindow {
            surfaceSettingsWindow(settingsWindow)
            return
        }

        shouldPresentSettingsWhenAvailable = true
    }

    func consumePendingOverviewAlertRequest(_ request: OverviewAlertNavigationRequest) {
        guard pendingOverviewAlertRequest?.requestID == request.requestID else { return }
        pendingOverviewAlertRequest = nil
    }

    private func surfaceSettingsWindow(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}

@MainActor
final class SharedAppObjects {
    static let shared = SharedAppObjects()

    let weatherViewModel = WeatherViewModel()
    let appVisibility = AppVisibility.shared
    let shellState = AppShellState.shared

    private init() {}
}

enum WeatherSceneIDs {
    static let mainWindow = "main-weather-window"
}
