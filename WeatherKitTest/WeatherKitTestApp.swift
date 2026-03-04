import SwiftUI
import WeatherKit
import CoreLocation
import Combine
import MapKit
import AppKit
import Sparkle

// MARK: - App Entry Point

@main
struct WeatherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - we're using a status bar app
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var weatherViewModel: WeatherViewModel?
    private let appVisibility = AppVisibility.shared
    private var appActiveObservers: [NSObjectProtocol] = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UpdateManager.shared.start()

        // Drive animation gating (and other UI work) off app focus + popover presentation.
        // This is important for a menu bar popover app because the SwiftUI view may stay alive
        // even when the popover is closed, which would otherwise keep animations/timers running.
        let nc = NotificationCenter.default
        appActiveObservers.append(
            nc.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.appVisibility.isAppActive = true
            }
        )
        appActiveObservers.append(
            nc.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                self?.appVisibility.isAppActive = false
            }
        )

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "cloud.sun.fill", accessibilityDescription: "Weather")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Initialize weather view model and fetch current location weather
        weatherViewModel = WeatherViewModel()
        weatherViewModel?.onWeatherUpdate = { [weak self] weather in
            self?.updateMenuBar(with: weather)
        }

        Task {
            await WeatherNotificationManager.shared.requestAuthorization()
        }
        
        // Create popover with shared view model
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 500, height: 700)
        popover?.behavior = .transient
        popover?.delegate = self
        popover?.contentViewController = NSHostingController(
            rootView: ContentView(viewModel: weatherViewModel!)
                .environmentObject(appVisibility)
        )
        
        weatherViewModel?.fetchCurrentLocationWeather()
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                appVisibility.isPopoverVisible = false
                popover?.performClose(nil)
            } else {
                appVisibility.isPopoverVisible = true
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover?.contentViewController?.view.window?.makeKey()
            }
        }
    }
    
    func updateMenuBar(with weather: CurrentWeather) {
        if let button = statusItem?.button {
            let useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
            let tempMeasurement = weather.temperature
            let temp : Int
            
            if useCelsius {
                temp = Int(tempMeasurement.converted(to: .celsius).value.rounded())
            } else {
                temp = Int(tempMeasurement.converted(to: .fahrenheit).value.rounded())
            }
            
            let symbol = weather.symbolName

            // Set image and title so the menubar shows icon + temperature
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Weather")
            button.imagePosition = .imageLeading
            button.title = " \(temp)°"
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        let nc = NotificationCenter.default
        for token in appActiveObservers {
            nc.removeObserver(token)
        }
        appActiveObservers.removeAll()
    }
}

extension AppDelegate: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        appVisibility.isPopoverVisible = true
    }

    func popoverDidClose(_ notification: Notification) {
        appVisibility.isPopoverVisible = false
    }
}

@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    private var updaterController: SPUStandardUpdaterController?

    private init() {}

    func start() {
        if updaterController == nil {
            // Let Sparkle present its own UI/errors. We only preflight the feed URL for clearer 404/401 messaging.
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
