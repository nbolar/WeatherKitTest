import SwiftUI
import AppKit
import Sparkle
import WeatherKit

// MARK: - App Entry Point

@main
struct WeatherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let sharedObjects = SharedAppObjects.shared

    var body: some Scene {
        Window("Weather", id: WeatherSceneIDs.mainWindow) {
            MainWeatherWindowView(viewModel: sharedObjects.weatherViewModel)
                .environmentObject(sharedObjects.appVisibility)
                .environmentObject(sharedObjects.shellState)
                .frame(
                    minWidth: WeatherDesignTokens.mainWindowMin.width,
                    minHeight: WeatherDesignTokens.mainWindowMin.height
                )
        }
        .defaultSize(
            width: WeatherDesignTokens.mainWindowDefault.width,
            height: WeatherDesignTokens.mainWindowDefault.height
        )
        .defaultLaunchBehavior(.suppressed)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .commands {
            WeatherAppCommands(
                shellState: sharedObjects.shellState,
                viewModel: sharedObjects.weatherViewModel
            )
        }

        Settings {
            InAppSettingsView(
                isPresented: .constant(true),
                viewModel: sharedObjects.weatherViewModel,
                showsPanelChrome: false,
                showsCloseButton: false
            )
                .environmentObject(sharedObjects.appVisibility)
                .environmentObject(sharedObjects.shellState)
                .frame(minWidth: 760, idealWidth: 860, minHeight: 560, idealHeight: 620)
        }
        .defaultSize(width: 860, height: 620)
    }
}

struct WeatherAppCommands: Commands {
    let shellState: AppShellState
    let viewModel: WeatherViewModel

    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("Weather") {
            Button("Show Full Forecast") {
                shellState.showMainWindow(destination: .overview) {
                    openWindow(id: WeatherSceneIDs.mainWindow)
                }
            }
            .keyboardShortcut(.return, modifiers: [.command])

            Button("Refresh Weather") {
                viewModel.manualRefresh()
            }
            .keyboardShortcut("r", modifiers: [.command])

            Button("Focus Search") {
                shellState.showMainWindow(focusSearch: true) {
                    openWindow(id: WeatherSceneIDs.mainWindow)
                }
            }
            .keyboardShortcut("l", modifiers: [.command])

            Divider()

            Button("Show Overview") {
                shellState.showMainWindow(destination: .overview) {
                    openWindow(id: WeatherSceneIDs.mainWindow)
                }
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Show Map") {
                shellState.showMainWindow(destination: .map) {
                    openWindow(id: WeatherSceneIDs.mainWindow)
                }
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Show Alerts") {
                shellState.showMainWindow(destination: .alerts) {
                    openWindow(id: WeatherSceneIDs.mainWindow)
                }
            }
            .keyboardShortcut("3", modifiers: [.command])
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private let sharedObjects = SharedAppObjects.shared
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var appActiveObservers: [NSObjectProtocol] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UpdateManager.shared.start()

        let nc = NotificationCenter.default
        let appVisibility = sharedObjects.appVisibility
        appVisibility.isAppActive = NSRunningApplication.current.isActive
        appActiveObservers.append(
            nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [self] _ in
                Task { @MainActor in
                    appVisibility.isAppActive = true
                }
                self.sharedObjects.weatherViewModel.refreshIfNeededAfterForeground()
            }
        )
        appActiveObservers.append(
            nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    appVisibility.isAppActive = false
                }
            }
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cloud.sun.fill", accessibilityDescription: "Weather")
            button.action = #selector(togglePopover)
            button.target = self
        }

        sharedObjects.weatherViewModel.onWeatherUpdate = { [weak self] weather in
            self?.updateMenuBar(with: weather)
        }

        Task {
            await WeatherNotificationManager.shared.requestAuthorization()
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(
            width: WeatherDesignTokens.popoverWidth,
            height: WeatherDesignTokens.popoverHeight
        )
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(
            rootView: QuickStatusPopoverView(viewModel: sharedObjects.weatherViewModel)
                .environmentObject(sharedObjects.appVisibility)
                .environmentObject(sharedObjects.shellState)
        )

        sharedObjects.weatherViewModel.fetchCurrentLocationWeather()
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }

        if popover?.isShown == true {
            sharedObjects.appVisibility.endPopoverPresentation()
            popover?.performClose(nil)
        } else {
            sharedObjects.appVisibility.beginPopoverPresentation()
            popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover?.contentViewController?.view.window?.makeKey()
        }
    }

    private func updateMenuBar(with weather: CurrentWeather) {
        guard let button = statusItem?.button else { return }

        let useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
        let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
        let temp = Int(weather.temperature.converted(to: unit).value.rounded())

        button.image = NSImage(systemSymbolName: weather.symbolName, accessibilityDescription: "Weather")
        button.imagePosition = .imageLeading
        button.title = " \(temp)°"
    }

    func applicationWillTerminate(_ notification: Notification) {
        let nc = NotificationCenter.default
        for token in appActiveObservers {
            nc.removeObserver(token)
        }
        appActiveObservers.removeAll()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        sharedObjects.appVisibility.isPopoverVisible = true
    }

    func popoverDidClose(_ notification: Notification) {
        sharedObjects.appVisibility.endPopoverPresentation()
    }
}

@MainActor
final class UpdateManager {
    static let shared = UpdateManager()
    private var updaterController: SPUStandardUpdaterController?

    private init() {}

    func start() {
        if updaterController == nil {
            updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        }
    }

    func checkForUpdates() {
        if let feedURL = updaterController?.updater.feedURL, feedURL.absoluteString.isEmpty == false {
            URLSession.shared.dataTask(with: feedURL) { [weak self] data, response, error in
                guard let self else { return }
                if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                    Task { @MainActor in
                        self.showFeedError(title: "Update Error", message: "Update feed not found. Make sure appcast.xml is attached to the latest GitHub release.")
                    }
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode == 401 {
                    Task { @MainActor in
                        self.showFeedError(title: "Update Error", message: "Update feed requires access. Ensure the GitHub release and assets are public.")
                    }
                    return
                }
                if error != nil {
                    Task { @MainActor in
                        self.showFeedError(title: "Update Error", message: "Unable to reach update feed. Check your internet connection.")
                    }
                    return
                }
                if data == nil {
                    Task { @MainActor in
                        self.showFeedError(title: "Update Error", message: "Update feed returned no data.")
                    }
                    return
                }
                DispatchQueue.main.async {
                    self.updaterController?.checkForUpdates(nil)
                }
            }.resume()
        } else {
            updaterController?.checkForUpdates(nil)
        }
    }

    private func showFeedError(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "OK")
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
