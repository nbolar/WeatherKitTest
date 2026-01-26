import SwiftUI
import WeatherKit
import CoreLocation
import Combine
import MapKit
import AppKit
import WebKit
import Charts
import ServiceManagement

@inline(__always)
private func quitApp() {
    NSApplication.shared.terminate(nil) // no confirmation
}


@main
struct WeatherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
//        ContentView()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var weatherViewModel: WeatherViewModel?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
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
        
        // Create popover with shared view model
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 500, height: 700)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView(viewModel: weatherViewModel!))
        
        weatherViewModel?.fetchCurrentLocationWeather()
    }
    
    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown == true {
                popover?.performClose(nil)
            } else {
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
                temp = Int(tempMeasurement.converted(to: .celsius).value)
            } else {
                temp = Int(tempMeasurement.converted(to: .fahrenheit).value)
            }
            
            let symbol = weather.symbolName

            // Set image and title so the menubar shows icon + temperature
            button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Weather")
            button.imagePosition = .imageLeading
            button.title = " \(temp)°"
        }
    }
}

// MARK: - Launch at Login Manager
@available(macOS 13.0, *)
class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()
    
    @Published var isEnabled: Bool = false
    
    private init() {
        updateStatus()
    }
    
    func updateStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }
    
    func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            updateStatus()
        } catch {
            print("Failed to \(isEnabled ? "unregister" : "register") launch at login: \(error.localizedDescription)")
        }
    }
    
    func enable() {
        guard !isEnabled else { return }
        toggle()
    }
    
    func disable() {
        guard isEnabled else { return }
        toggle()
    }
}

// MARK: - Liquid Glass (macOS Tahoe 26) styling helpers
private enum LiquidGlassTokens {
    static let panelCorner: CGFloat = 26
    static let cardCorner: CGFloat = 18
    static let strokeOpacity: Double = 0.16
    static let innerGlowOpacity: Double = 0.10
    static let panelWidth: CGFloat = 340
    static let panelHeight: CGFloat = 600
}

private struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = LiquidGlassTokens.cardCorner

    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                content
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(LiquidGlassTokens.strokeOpacity), lineWidth: 0.75)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(LiquidGlassTokens.innerGlowOpacity),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(0.9)
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}

private extension View {
    func liquidGlassCard(cornerRadius: CGFloat = LiquidGlassTokens.cardCorner) -> some View {
        self.modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
}

private struct LiquidGlassPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(macOS 26.0, *) {
                content
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous))
            } else {
                content
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 26, x: -8, y: 14)
    }
}

private extension View {
    func liquidGlassPanel() -> some View {
        self.modifier(LiquidGlassPanelBackground())
    }
}

private struct LiquidGlassSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .liquidGlassCard()
    }
}


// MARK: - In-app Settings Panel (Liquid Glass redesign)
struct InAppSettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: WeatherViewModel

    @AppStorage("refreshIntervalMinutes") private var refreshIntervalMinutes: Int = 30
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    private let options = [5, 10, 15, 30, 60, 120, 180]
    
    @StateObject private var launchManager: LaunchAtLoginManager
    
    init(isPresented: Binding<Bool>, viewModel: WeatherViewModel) {
        self._isPresented = isPresented
        self.viewModel = viewModel
        if #available(macOS 13.0, *) {
            _launchManager = StateObject(wrappedValue: LaunchAtLoginManager.shared)
        } else {
            _launchManager = StateObject(wrappedValue: LaunchAtLoginManager.shared)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
        ZStack(alignment: .topTrailing) {
            // Panel content
            VStack(alignment: .leading, spacing: 14) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    LiquidGlassSection("Temperature", subtitle: "Choose your preferred unit.") {
                        Picker("", selection: $useCelsius) {
                            Text("Fahrenheit (°F)").tag(false)
                            Text("Celsius (°C)").tag(true)
                        }
                        .padding(.horizontal, -8)
                        .pickerStyle(.segmented)
                        .onChange(of: useCelsius) { _ in
                            viewModel.refreshCurrentWeather()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                    }
                    

                    LiquidGlassSection("Auto‑Refresh", subtitle: "Refresh weather data automatically.") {
                        Picker("Refresh every", selection: $refreshIntervalMinutes) {
                            ForEach(options, id: \.self) { minutes in
                                if minutes < 60 {
                                    Text("\(minutes) minutes").tag(minutes)
                                } else {
                                    let hours = minutes / 60
                                    Text("\(hours) \(hours == 1 ? "hour" : "hours")").tag(minutes)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    LiquidGlassSection("Manual Refresh", subtitle: "Fetch the latest weather data immediately.") {
                        Button {
                            viewModel.manualRefresh()
                            dismiss()
                        } label: {
                            Label("Refresh Now", systemImage: "arrow.clockwise")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.20))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack() {
                        if #available(macOS 13.0, *) {
                            LiquidGlassSection("Launch at Login", subtitle: "Automatically start the app when you log in.") {
                                Toggle(isOn: Binding(
                                    get: { launchManager.isEnabled },
                                    set: { _ in launchManager.toggle() }
                                )) {
                                    Text("Open at login")
                                }
                                .toggleStyle(.switch)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Spacer()
                        LiquidGlassSection("Quit App", subtitle: "Close WeatherKitTest.") {
                            Button {
                                quitApp()
                            } label: {
                                Label("Quit", systemImage: "xmark.circle")
                                    .labelStyle(.titleOnly)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white.opacity(0.20))
                            .frame(maxWidth: .infinity, maxHeight: 115, alignment: .center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 115,alignment: .leading)
                    }
                    }
                .padding(.top, 6)
                .padding(.horizontal, 14)
                .padding(.bottom, 14)

            }
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(width: LiquidGlassTokens.panelWidth, alignment: .topLeading)
            .liquidGlassPanel()
            .overlay(panelChromeOverlay)
            .contentShape(RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous))
            .onTapGesture {}
            // Close button floats slightly above, like Tahoe sheets/panels.
            closeButton
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 12)
        .padding(.trailing, 12)
        .onAppear {
            if #available(macOS 13.0, *) {
                launchManager.updateStatus()
            }
        }
        }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary.opacity(0.92))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.title3.weight(.semibold))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }

    private var closeButton: some View {
        
        Button {
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 28, height: 28)

                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary.opacity(0.92))
            }
            .accessibilityHidden(true)

        }
        .buttonStyle(.plain)
        .padding(.horizontal, 7)
        .padding(.top, 5)
    }


    private var panelChromeOverlay: some View {
        // A subtle top highlight to separate the panel from busy backgrounds.
        RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.14),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private func dismiss() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.86)) {
            isPresented = false
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var escapeMonitor: Any?
    @FocusState private var searchFocused: Bool
    @State private var hoveredSuggestionIndex: Int? = nil
    @State private var selectedSuggestionIndex: Int? = nil
    
    // Convenience initializer for previews/testing
    init(viewModel: WeatherViewModel? = nil) {
        self.viewModel = viewModel ?? WeatherViewModel()
    }
    
    private var suggestionsToShow: [MKLocalSearchCompletion] {
        Array(viewModel.searchSuggestions.prefix(8))
    }

    var body: some View {
        ZStack {
            weatherBackdrop
                .onTapGesture {
                    if viewModel.isShowingSuggestions {
                        searchFocused = false
                        viewModel.dismissSuggestions()
                    }
                }
            
            // Content layer (above background)
            mainContentView
                .zIndex(1)
            
            // Settings overlay (top layer)
            if showSettings {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .zIndex(2)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showSettings = false
                        }
                    }
                
                InAppSettingsView(isPresented: $showSettings, viewModel: viewModel)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(3)
            }
        }
        .onChange(of: searchFocused) { focused in
            if !focused {
                viewModel.dismissSuggestions()
            }
        }
        .onChange(of: viewModel.isShowingSuggestions) { showing in
            if showing && !viewModel.searchSuggestions.isEmpty {
                selectedSuggestionIndex = 0
            } else {
                selectedSuggestionIndex = nil
            }
        }
        .onChange(of: viewModel.searchSuggestions) { newList in
            if newList.isEmpty {
                selectedSuggestionIndex = nil
            } else if let idx = selectedSuggestionIndex, idx >= newList.count {
                selectedSuggestionIndex = max(0, newList.count - 1)
            } else if selectedSuggestionIndex == nil {
                selectedSuggestionIndex = 0
            }
        }
        .onAppear {
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Handle keyboard navigation only when suggestions are visible
                if viewModel.isShowingSuggestions && !viewModel.searchSuggestions.isEmpty {
                    switch event.keyCode {
                    case 125: // Down Arrow
                        if let current = selectedSuggestionIndex {
                            let next = (current + 1) % viewModel.searchSuggestions.count
                            selectedSuggestionIndex = next
                        } else {
                            selectedSuggestionIndex = 0
                        }
                        return nil // consume
                    case 126: // Up Arrow
                        if let current = selectedSuggestionIndex {
                            let next = (current - 1 + viewModel.searchSuggestions.count) % viewModel.searchSuggestions.count
                            selectedSuggestionIndex = next
                        } else {
                            selectedSuggestionIndex = viewModel.searchSuggestions.count - 1
                        }
                        return nil // consume
                    case 36, 76: // Return or Enter (keypad)
                        if let idx = selectedSuggestionIndex, idx < viewModel.searchSuggestions.count {
                            let suggestion = viewModel.searchSuggestions[idx]
                            searchFocused = false
                            viewModel.dismissSuggestions()
                            viewModel.selectSuggestion(suggestion)
                            return nil // consume
                        }
                    case 53: // Escape
                        viewModel.dismissSuggestions()
                        return nil // consume
                    default:
                        break
                    }
                } else if event.keyCode == 53 { // Escape when no suggestions
                    if viewModel.isShowingSuggestions {
                        viewModel.dismissSuggestions()
                        return nil
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = escapeMonitor {
                NSEvent.removeMonitor(monitor)
                escapeMonitor = nil
            }
        }
        .frame(width: 500, height: 700)
    }
    
    var mainContentView: some View {
        VStack(spacing: 20) {
            settingsButtonRow
            
            // Saved locations carousel
            if !viewModel.savedLocations.isEmpty {
                savedLocationsCarousel
            }
            
            searchBarSection
            currentLocationButton
            tabPickerView
            scrollArea
                .frame(maxHeight: .infinity)
            lastUpdatedFooter
        }
        .padding(25)
        .background(Color.clear)
    }
    
    @ViewBuilder
    private var savedLocationsCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(viewModel.savedLocations.enumerated()), id: \.element.id) { index, location in
                    SavedLocationCard(
                        location: location,
                        isSelected: viewModel.currentLocationIndex == index,
                        cachedWeather: viewModel.getCachedWeather(for: location.id),
                        onSelect: {
                            viewModel.selectLocation(at: index)
                        },
                        onRemove: {
                            if let idx = viewModel.savedLocations.firstIndex(where: { $0.id == location.id }) {
                                viewModel.removeSavedLocation(at: IndexSet(integer: idx))
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 5)
        }
        .frame(height: 62)
    }
    
    @ViewBuilder
    private var settingsButtonRow: some View {
        HStack {
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSettings = true
                }
            } label: {
                Image(systemName: "gearshape")
                    .foregroundColor(.white.opacity(0.9))
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
    }
    
    @ViewBuilder
    private var searchBarSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.7))
                TextField("Enter city name", text: $viewModel.cityName)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .foregroundColor(.white)
                    .onSubmit {
                        searchFocused = false
                        viewModel.searchCity()
                    }
                    .onChange(of: viewModel.cityName) { newValue in
                        viewModel.updateSearchCompletions(for: newValue)
                    }
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 16, height: 16, alignment: .center)
                        .tint(.white)
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.15))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            
            if viewModel.isShowingSuggestions {
                suggestionsList
            }
        }
    }
    
    @ViewBuilder
    private var suggestionsList: some View {
        if !suggestionsToShow.isEmpty {
            VStack(spacing: 0) {
                ForEach(suggestionsToShow.indices, id: \.self) { index in
                    let suggestion = suggestionsToShow[index]
                    SuggestionRow(
                        suggestion: suggestion,
                        isHighlighted: (hoveredSuggestionIndex == index || selectedSuggestionIndex == index),
                        onTap: {
                            searchFocused = false
                            viewModel.dismissSuggestions()
                            viewModel.selectSuggestion(suggestion)
                        },
                        onHoverChange: { hovering in
                            hoveredSuggestionIndex = hovering ? index : nil
                        }
                    )

                    if index < suggestionsToShow.count - 1 {
                        Divider()
                            .background(Color.white.opacity(0.12))
                            .padding(.leading, 44)
                    }
                }
            }
            .padding(.top, 4)
            .background(Color.black.opacity(0.06))
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: viewModel.searchSuggestions.count)
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: viewModel.isShowingSuggestions)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(5)
        }
    }
    
    @ViewBuilder
    private var currentLocationButton: some View {
        Button(action: {
            viewModel.fetchCurrentLocationWeather()
        }) {
            HStack {
                Image(systemName: "location.fill")
                Text("Use Current Location")
            }
            .foregroundColor(.white)
        }
        .buttonStyle(.bordered)
        .tint(.white.opacity(0.2))
    }
    
    @ViewBuilder
    private var tabPickerView: some View {
        if viewModel.currentWeather != nil {
            Picker("", selection: $selectedTab) {
                Text("Current").tag(0)
                Text("Charts").tag(1)
                Text("Hourly").tag(2)
                Text("10-Day").tag(3)
                Text("Map").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var scrollArea: some View {
        ScrollView {
            if let weather = viewModel.currentWeather {
                if selectedTab == 0 {
                    CurrentWeatherView(
                        weather: weather,
                        locationName: viewModel.locationName,
                        dailyForecast: viewModel.dailyForecast.first,
                        alerts: viewModel.weatherAlerts,
                        locationTimeZone: viewModel.locationTimeZone
                    )
                } else if selectedTab == 1 {
                    WeatherChartsView(
                        hourlyForecast: viewModel.hourlyForecast,
                        minuteForecast: viewModel.minuteForecast
                    )
                    .padding(.top, 16)
                } else if selectedTab == 2 {
                    HourlyForecastView(hourlyForecast: viewModel.hourlyForecast)
                } else if selectedTab == 3 {
                    DailyForecastView(dailyForecast: viewModel.dailyForecast)
                } else if selectedTab == 4 {
                    WeatherMapView(location: viewModel.lastLocation, viewModel: viewModel)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.9))
                    Text(error)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "cloud.sun")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.9))
                        .symbolRenderingMode(.hierarchical)
                    Text("Enter a city name or use your current location")
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 40)
            }
        }
        .scrollDisabledWhenChartsVisible(selectedTab == 1)
    }
    
    @ViewBuilder
    var weatherBackdrop: some View {
        if let weather = viewModel.currentWeather {
            WeatherBackdropView(weather: weather)
        } else {
            // Default gradient when no weather data
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private var lastUpdatedFooter: some View {
        if let updated = viewModel.lastUpdated {
            HStack {
                Spacer()
                Label {
                    Text("Last updated " + updated.formatted(date: .omitted, time: .shortened))
                } icon: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct SuggestionRow: View {
    let suggestion: MKLocalSearchCompletion
    let isHighlighted: Bool
    let onTap: () -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .foregroundColor(.white)
                        .font(.subheadline)
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .foregroundColor(.white.opacity(0.75))
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHighlighted ? Color.white.opacity(0.12) : Color.clear)
        .onHover { hovering in
            onHoverChange(hovering)
        }
    }
}

struct WeatherBackdropView: View {
    let weather: CurrentWeather
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = 0

    private var styleKey: String {
        let condition = weather.condition.description.lowercased()
        let tempBucket = Int(weather.temperature.value.rounded())
        return "\(condition)|\(weather.isDaylight ? "day" : "night")|\(tempBucket)"
    }

    var body: some View {
        ZStack {
            // Base gradient (animated subtly) based on time-of-day + conditions
            LinearGradient(
                colors: gradientColors,
                startPoint: UnitPoint(x: 0.15 + drift, y: 0.10),
                endPoint: UnitPoint(x: 0.85 - drift, y: 0.90)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.0), value: styleKey)

            // A second, softer layer to add depth like the macOS Weather popover
            LinearGradient(
                colors: depthColors,
                startPoint: UnitPoint(x: 0.85 - drift, y: 0.15),
                endPoint: UnitPoint(x: 0.10 + drift, y: 0.95)
            )
            .blendMode(.overlay)
            .opacity(weather.isDaylight ? 0.35 : 0.45)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.0), value: styleKey)

            // Atmospheric effects (always behind the main content)
            weatherEffects
                .allowsHitTesting(false)

            // Subtle vignette for contrast + readability (keeps accessibility strong)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(weather.isDaylight ? 0.05 : 0.28),
                            Color.black.opacity(weather.isDaylight ? 0.15 : 0.40)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            // Gentle parallax drift so the background feels alive without being distracting.
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                drift = 0.08
            }
        }
    }

    private var depthColors: [Color] {
        if weather.isDaylight {
            // Enhanced depth colors for sunny days with more vibrant overlays
            return [
                Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.22),
                Color(red: 0.90, green: 0.85, blue: 0.95).opacity(0.18),
                Color(red: 1.0, green: 0.92, blue: 0.80).opacity(0.15)
            ]
        } else {
            return [Color.white.opacity(0.10), Color.purple.opacity(0.12), Color.white.opacity(0.06)]
        }
    }

    private var gradientColors: [Color] {
        let temp = weather.temperature.value
        let condition = weather.condition.description.lowercased()
        let isDay = weather.isDaylight

        // Night palette first — we keep it calm, deep, and contrast-friendly.
        if !isDay {
            if condition.contains("clear") || condition.contains("sunny") {
                // Clear night
                return [Color(red: 0.08, green: 0.12, blue: 0.25).opacity(0.95),
                        Color(red: 0.22, green: 0.12, blue: 0.35).opacity(0.85),
                        Color(red: 0.05, green: 0.08, blue: 0.18).opacity(0.95)]
            } else if condition.contains("cloud") {
                return [Color(red: 0.10, green: 0.12, blue: 0.20).opacity(0.95),
                        Color(red: 0.18, green: 0.18, blue: 0.26).opacity(0.90),
                        Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.95)]
            } else if condition.contains("rain") || condition.contains("drizzle") {
                return [Color(red: 0.06, green: 0.10, blue: 0.18).opacity(0.95),
                        Color(red: 0.10, green: 0.14, blue: 0.22).opacity(0.92),
                        Color(red: 0.05, green: 0.08, blue: 0.14).opacity(0.95)]
            } else if condition.contains("snow") || condition.contains("flurries") {
                return [Color(red: 0.12, green: 0.14, blue: 0.22).opacity(0.95),
                        Color(red: 0.18, green: 0.20, blue: 0.30).opacity(0.90),
                        Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.95)]
            } else if condition.contains("storm") || condition.contains("thunder") {
                return [Color(red: 0.06, green: 0.07, blue: 0.14).opacity(0.95),
                        Color(red: 0.14, green: 0.10, blue: 0.20).opacity(0.92),
                        Color(red: 0.05, green: 0.06, blue: 0.12).opacity(0.95)]
            } else if condition.contains("fog") || condition.contains("haze") {
                return [Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.95),
                        Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.90),
                        Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.95)]
            } else {
                return [Color(red: 0.08, green: 0.12, blue: 0.22).opacity(0.95),
                        Color(red: 0.16, green: 0.14, blue: 0.28).opacity(0.90),
                        Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.95)]
            }
        }

        // Day palette - VIBRANT sunny skies with dramatic, noticeable colors
        if condition.contains("clear") || condition.contains("sunny") {
            if temp > 85 {
                // Hot sunny day - INTENSE warm golden/orange sky
                return [
                    Color(red: 1.0, green: 0.60, blue: 0.15),  // Deep warm orange top
                    Color(red: 1.0, green: 0.82, blue: 0.35),  // Bright golden middle
                    Color(red: 0.98, green: 0.92, blue: 0.60)  // Soft golden-cream bottom
                ]
            } else if temp > 70 {
                // Pleasant sunny day - VIBRANT azure blue with golden horizon
                return [
                    Color(red: 0.20, green: 0.55, blue: 0.98),  // Deep azure blue top
                    Color(red: 0.40, green: 0.75, blue: 1.0),   // Bright sky blue middle
                    Color(red: 0.95, green: 0.88, blue: 0.50)   // Golden-yellow horizon
                ]
            } else if temp > 50 {
                // Mild sunny day - CRISP bright blue sky
                return [
                    Color(red: 0.15, green: 0.50, blue: 0.95),  // Rich sky blue top
                    Color(red: 0.35, green: 0.70, blue: 1.0),   // Brilliant cyan middle
                    Color(red: 0.60, green: 0.85, blue: 0.98)   // Light cyan-blue horizon
                ]
            } else {
                // Cool sunny day - VIVID cool blue with purple accents
                return [
                    Color(red: 0.25, green: 0.45, blue: 0.90),  // Deep cool blue top
                    Color(red: 0.45, green: 0.60, blue: 0.95),  // Bright periwinkle middle
                    Color(red: 0.55, green: 0.75, blue: 0.98)   // Cool cyan-blue bottom
                ]
            }
        } else if condition.contains("cloud") {
            if temp > 70 {
                return [Color.gray.opacity(0.48), Color.blue.opacity(0.36), Color.gray.opacity(0.36)]
            } else {
                return [Color.gray.opacity(0.56), Color.blue.opacity(0.46), Color.gray.opacity(0.48)]
            }
        } else if condition.contains("rain") || condition.contains("drizzle") {
            return [Color.blue.opacity(0.68), Color.gray.opacity(0.56), Color.blue.opacity(0.56)]
        } else if condition.contains("snow") || condition.contains("flurries") {
            return [Color.white.opacity(0.52), Color.blue.opacity(0.44), Color.white.opacity(0.44)]
        } else if condition.contains("storm") || condition.contains("thunder") {
            return [Color.purple.opacity(0.62), Color.gray.opacity(0.78), Color.blue.opacity(0.56)]
        } else if condition.contains("fog") || condition.contains("haze") {
            return [Color.gray.opacity(0.56), Color.white.opacity(0.44), Color.gray.opacity(0.46)]
        } else {
            return [Color.blue.opacity(0.50), Color.cyan.opacity(0.36), Color.blue.opacity(0.40)]
        }
    }

    @ViewBuilder
    private var weatherEffects: some View {
        let condition = weather.condition.description.lowercased()
        let isDay = weather.isDaylight

        // Night gets stars + either moon (clear) or subtle glow (other conditions)
        if !isDay {
            StarsEffect()
            ShootingStarsEffect()
            // Show moon with rays on clear nights, otherwise just a subtle glow
            if condition.contains("clear") || condition.contains("sunny") {
                MoonRaysEffect()
            } else {
                NightGlowEffect()
            }
        }

        if condition.contains("storm") || condition.contains("thunder") {
            // Lightning + optional rain gives the right drama.
            LightningEffect(intensity: isDay ? 0.9 : 1.0)
            RainEffect()
        } else if condition.contains("drizzle") {
            DrizzleEffect()
        } else if condition.contains("rain") {
            RainEffect()
        } else if condition.contains("snow") {
            SnowEffect()
        } else if condition.contains("fog") || condition.contains("haze") {
            FogEffect()
        } else if condition.contains("cloud") {
            CloudEffect()
        } else if (condition.contains("clear") || condition.contains("sunny")) && isDay {
            SunRaysEffect()
        }
    }
}


struct StarsEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let baseOpacity: Double
        let twinkleSpeed: Double
        let delay: Double
    }

    @State private var stars: [Star] = []
    @State private var twinklePhase: Double = 0

    var body: some View {
        ZStack {
            ForEach(stars) { star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .opacity(calculateTwinkle(for: star))
                    .blur(radius: star.size > 2.2 ? 0.3 : 0.2)
                    .offset(x: star.x, y: star.y)
            }
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
        .onAppear {
            if stars.isEmpty {
                // Concentrate stars toward the upper half like the system Weather backgrounds.
                stars = (0..<80).map { i in
                    Star(
                        id: i,
                        x: CGFloat.random(in: -260...260),
                        y: CGFloat.random(in: -420...50),
                        size: CGFloat.random(in: 1.0...2.8),
                        baseOpacity: Double.random(in: 0.20...0.50),
                        twinkleSpeed: Double.random(in: 1.0...2.5),
                        delay: Double.random(in: 0...10)
                    )
                }
            }

            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                twinklePhase = 100
            }
        }
    }
    
    private func calculateTwinkle(for star: Star) -> Double {
        if reduceMotion {
            return star.baseOpacity
        }
        
        // Create a more pronounced twinkling effect with sine wave
        let sineValue = sin((twinklePhase / star.twinkleSpeed) + star.delay)
        let twinkleAmount = 0.55 * sineValue // Increased from 0.25 for more visible twinkling
        
        // Ensure opacity stays within valid range
        return min(max(star.baseOpacity + twinkleAmount, 0.1), 1.0)
    }
}

struct NightGlowEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse: CGFloat = 0.35

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.22),
                        Color.blue.opacity(0.12),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 220
                )
            )
            .frame(width: 420, height: 420)
            .offset(x: 180, y: -260)
            .opacity(pulse)
            .blur(radius: 40)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                    pulse = 0.55
                }
            }
    }
}

struct ShootingStarsEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shootingStars: [ShootingStar] = []
    
    fileprivate struct ShootingStar: Identifiable {
        let id: UUID
        var x: CGFloat
        var y: CGFloat
        let angle: Double
        let length: CGFloat
        let speed: Double
        var opacity: Double
        var isActive: Bool
    }
    
    var body: some View {
        ZStack {
            ForEach(shootingStars) { star in
                if star.isActive {
                    ShootingStarView(star: star)
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            scheduleShootingStar()
        }
    }
    
    private func scheduleShootingStar() {
        guard !reduceMotion else { return }
        
        // Random delay between shooting stars (5-15 seconds)
        let delay = Double.random(in: 5...15)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            createShootingStar()
            scheduleShootingStar() // Schedule the next one
        }
    }
    
    private func createShootingStar() {
        let newStar = ShootingStar(
            id: UUID(),
            x: CGFloat.random(in: -200...100),
            y: CGFloat.random(in: -350...(-200)),
            angle: Double.random(in: 25...65), // Diagonal angle
            length: CGFloat.random(in: 40...80),
            speed: Double.random(in: 0.6...1.2),
            opacity: 1.0,
            isActive: true
        )
        
        shootingStars.append(newStar)
        
        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + newStar.speed + 0.5) {
            shootingStars.removeAll { $0.id == newStar.id }
        }
    }
}

fileprivate struct ShootingStarView: View {
    let star: ShootingStarsEffect.ShootingStar
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Tail
            LinearGradient(
                colors: [
                    Color.white.opacity(0.8),
                    Color.white.opacity(0.4),
                    Color.white.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: star.length, height: 1.5)
            .blur(radius: 0.8)
            
            // Bright head
            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .blur(radius: 0.5)
        }
        .rotationEffect(.degrees(-star.angle))
        .opacity(opacity)
        .offset(x: star.x + offset * cos(star.angle * .pi / 180),
                y: star.y + offset * sin(star.angle * .pi / 180))
        .blendMode(.screen)
        .onAppear {
            // Fade in quickly
            withAnimation(.easeIn(duration: 0.1)) {
                opacity = 1.0
            }
            
            // Move across the sky
            withAnimation(.linear(duration: star.speed)) {
                offset = 400
            }
            
            // Fade out toward the end
            DispatchQueue.main.asyncAfter(deadline: .now() + star.speed * 0.7) {
                withAnimation(.easeOut(duration: star.speed * 0.3)) {
                    opacity = 0
                }
            }
        }
    }
}

struct LightningEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let intensity: Double

    @State private var flashOpacity: Double = 0
    @State private var timer: Timer?

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .opacity(flashOpacity)
            .blendMode(.screen)
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                scheduleNextFlash()
            }
            .onDisappear {
                timer?.invalidate()
                timer = nil
            }
    }

    private func scheduleNextFlash() {
        let next = Double.random(in: 3.5...10.0)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: next, repeats: false) { _ in
            flash()
            scheduleNextFlash()
        }
    }

    private func flash() {
        // A quick double-flash feels most natural.
        withAnimation(.easeOut(duration: 0.08)) { flashOpacity = 0.18 * intensity }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeIn(duration: 0.20)) { flashOpacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.40) {
            withAnimation(.easeOut(duration: 0.06)) { flashOpacity = 0.12 * intensity }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeIn(duration: 0.20)) { flashOpacity = 0 }
            }
        }
    }
}

struct FogEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = -0.15

    var body: some View {
        ZStack {
            fogLayer(opacity: 0.08, blur: 40, y: -120, scale: 1.2, speed: 26, delay: 0)
            fogLayer(opacity: 0.06, blur: 55, y: -20,  scale: 1.45, speed: 32, delay: 3)
            fogLayer(opacity: 0.05, blur: 70, y: 120,  scale: 1.65, speed: 38, delay: 6)
        }
        .clipped() // Clip to prevent overflow affecting layout
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) {
                drift = 0.15
            }
        }
    }

    private func fogLayer(opacity: Double, blur: CGFloat, y: CGFloat, scale: CGFloat, speed: Double, delay: Double) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [
                        Color.white.opacity(opacity),
                        Color.white.opacity(opacity * 0.5),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 50,
                    endRadius: 250
                )
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(scale)
            .offset(x: drift * 180, y: y)
            .blur(radius: blur)
            .animation(reduceMotion ? nil : .linear(duration: speed).repeatForever(autoreverses: true).delay(delay), value: drift)
    }
}


struct SunRaysEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var shimmer: Double = 0
    @State private var pulsePhase: Double = 0
    @State private var secondaryRotation: Double = 0

    var body: some View {
        ZStack {
            // Sun core with enhanced realistic glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.92).opacity(0.85), // Bright warm white
                            Color(red: 1.0, green: 0.92, blue: 0.65).opacity(0.65), // Soft yellow
                            Color(red: 1.0, green: 0.78, blue: 0.45).opacity(0.48), // Golden
                            Color(red: 1.0, green: 0.65, blue: 0.35).opacity(0.28), // Warm orange
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 240
                    )
                )
                .frame(width: 460, height: 460)
                .offset(x: 140, y: -260)
                .blur(radius: 12)
                .opacity(0.92 + pulsePhase * 0.08)

            // Inner corona - intense bright ring
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.75),
                            Color(red: 1.0, green: 0.85, blue: 0.50).opacity(0.45),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 100,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 140, y: -260)
                .blur(radius: 8)
                .opacity(0.85)
                .blendMode(.screen)

            // Primary rays - longer, more defined
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        RayShape(tapering: 0.6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.95, blue: 0.75).opacity(0.45),
                                        Color(red: 1.0, green: 0.85, blue: 0.55).opacity(0.32),
                                        Color(red: 1.0, green: 0.75, blue: 0.45).opacity(0.18),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 700, height: 14)
                            .blur(radius: 12)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(rotation))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.6),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 140,
                        endRadius: 580
                    )
                )
                .opacity(0.75)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Secondary rays - offset rotation for depth
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<16, id: \.self) { index in
                        RayShape(tapering: 0.75)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.90, blue: 0.70).opacity(0.28),
                                        Color(red: 1.0, green: 0.80, blue: 0.55).opacity(0.18),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 650, height: 9)
                            .blur(radius: 16)
                            .rotationEffect(.degrees(Double(index) * 22.5))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(secondaryRotation))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.85),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 160,
                        endRadius: 520
                    )
                )
                .opacity(0.55)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // God rays / volumetric light beams
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.92, blue: 0.70).opacity(0.20),
                                        Color(red: 1.0, green: 0.85, blue: 0.60).opacity(0.12),
                                        Color(red: 1.0, green: 0.75, blue: 0.50).opacity(0.06),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 800, height: 28)
                            .blur(radius: 25)
                            .rotationEffect(.degrees(Double(index) * 45))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(rotation * 0.3))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.7),
                            Color.white.opacity(0.4),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 180,
                        endRadius: 600
                    )
                )
                .opacity(0.45)
                .blendMode(.screen)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Enhanced sunlit motes with depth
            if !reduceMotion {
                SunnyMotesEffect()
                    .opacity(0.55)
                    .blendMode(.screen)
            }

            // Improved warm shimmer with realistic light dispersion
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color(red: 1.0, green: 0.90, blue: 0.65).opacity(0.15),
                            Color(red: 1.0, green: 0.80, blue: 0.50).opacity(0.10),
                            Color(red: 1.0, green: 0.70, blue: 0.40).opacity(0.05),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.75, y: 0.15),
                        startRadius: 50,
                        endRadius: 550
                    )
                )
                .opacity(0.28 + shimmer * 0.15)
                .blendMode(.overlay)

            // Subtle atmospheric scattering effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.0),
                            Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.08),
                            Color(red: 0.85, green: 0.75, blue: 0.90).opacity(0.06),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(0.45)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            
            // Slow, continuous ray rotation
            withAnimation(.linear(duration: 200).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Counter-rotation for depth effect
            withAnimation(.linear(duration: 280).repeatForever(autoreverses: false)) {
                secondaryRotation = -360
            }
            
            // Gentle pulsing shimmer
            withAnimation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true)) {
                shimmer = 1
            }
            
            // Subtle pulse for sun core
            withAnimation(.easeInOut(duration: 3.8).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }
}

// Custom ray shape with natural tapering
struct RayShape: Shape {
    var tapering: Double = 0.7
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let height = rect.height
        let width = rect.width
        let taperPoint = width * tapering
        
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: taperPoint, y: 0))
        path.addLine(to: CGPoint(x: width, y: height / 2))
        path.addLine(to: CGPoint(x: taperPoint, y: height))
        path.closeSubpath()
        
        return path
    }
}

struct SunnyMotesEffect: View {
    @State private var motes: [(id: Int, x: CGFloat, y: CGFloat, size: CGFloat, speed: Double, delay: Double, horizontalDrift: CGFloat)] = []

    var body: some View {
        ZStack {
            ForEach(motes, id: \.id) { mote in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.95),
                                Color(red: 1.0, green: 0.90, blue: 0.70).opacity(0.65),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: mote.size / 2
                        )
                    )
                    .frame(width: mote.size, height: mote.size)
                    .blur(radius: 0.8)
                    .offset(x: mote.x, y: mote.y)
                    .modifier(EnhancedDriftUpModifier(
                        speed: mote.speed,
                        delay: mote.delay,
                        horizontalDrift: mote.horizontalDrift
                    ))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            motes = (0..<75).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -280...280),
                    y: CGFloat.random(in: -140...340),
                    size: CGFloat.random(in: 1.5...3.2),
                    speed: Double.random(in: 8.5...15.0),
                    delay: Double.random(in: 0...3.5),
                    horizontalDrift: CGFloat.random(in: -35...35)
                )
            }
        }
    }
}

private struct EnhancedDriftUpModifier: ViewModifier {
    let speed: Double
    let delay: Double
    let horizontalDrift: CGFloat
    @State private var verticalOffset: CGFloat = 0
    @State private var horizontalOffset: CGFloat = 0
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.6

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(x: horizontalOffset, y: verticalOffset)
            .onAppear {
                // Fade in and scale up
                withAnimation(.easeOut(duration: 1.5).delay(delay)) {
                    opacity = 1.0
                    scale = 1.0
                }
                
                // Vertical drift upward with fade out near the end
                withAnimation(.linear(duration: speed).delay(delay)) {
                    verticalOffset = -280
                }
                
                // Horizontal gentle sway
                withAnimation(
                    .easeInOut(duration: speed * 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    horizontalOffset = horizontalDrift
                }
                
                // Fade out as it reaches the top
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + speed * 0.75) {
                    withAnimation(.easeIn(duration: speed * 0.25)) {
                        opacity = 0.0
                    }
                }
            }
    }
}

// MARK: - Moon Effects for Night Time

struct MoonRaysEffect: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0
    @State private var shimmer: Double = 0
    @State private var pulsePhase: Double = 0
    @State private var secondaryRotation: Double = 0

    var body: some View {
        ZStack {
            // Moon core with soft silvery glow (reduced size)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.95, green: 0.98, blue: 1.0).opacity(0.85), // Soft bluish-white
                            Color(red: 0.85, green: 0.90, blue: 0.98).opacity(0.65), // Cool silver
                            Color(red: 0.75, green: 0.82, blue: 0.95).opacity(0.48), // Pale blue
                            Color(red: 0.65, green: 0.75, blue: 0.92).opacity(0.28), // Deeper blue
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 140
                    )
                )
                .frame(width: 280, height: 280)
                .offset(x: 140, y: -260)
                .blur(radius: 10)
                .opacity(0.75 + pulsePhase * 0.08)

            // Inner corona - soft moonlight ring (reduced size)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.92, green: 0.95, blue: 1.0).opacity(0.65),
                            Color(red: 0.80, green: 0.88, blue: 0.98).opacity(0.40),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 60,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .offset(x: 140, y: -260)
                .blur(radius: 8)
                .opacity(0.75)
                .blendMode(.screen)

            // Primary moonlight rays - softer and more ethereal than sun rays
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<12, id: \.self) { index in
                        RayShape(tapering: 0.6)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.85, green: 0.92, blue: 1.0).opacity(0.35),
                                        Color(red: 0.75, green: 0.85, blue: 0.98).opacity(0.25),
                                        Color(red: 0.65, green: 0.78, blue: 0.95).opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 700, height: 12)
                            .blur(radius: 14)
                            .rotationEffect(.degrees(Double(index) * 30))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(rotation))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.25),
                            Color.white.opacity(0.85),
                            Color.white.opacity(0.5),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 140,
                        endRadius: 580
                    )
                )
                .opacity(0.65)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Secondary rays - offset rotation for depth
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<16, id: \.self) { index in
                        RayShape(tapering: 0.75)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.80, green: 0.88, blue: 1.0).opacity(0.22),
                                        Color(red: 0.70, green: 0.80, blue: 0.98).opacity(0.14),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 650, height: 8)
                            .blur(radius: 18)
                            .rotationEffect(.degrees(Double(index) * 22.5))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(secondaryRotation))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.75),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 160,
                        endRadius: 520
                    )
                )
                .opacity(0.45)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Moonbeams - mystical light beams
            GeometryReader { geometry in
                ZStack {
                    ForEach(0..<8, id: \.self) { index in
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.88, green: 0.92, blue: 1.0).opacity(0.18),
                                        Color(red: 0.78, green: 0.85, blue: 0.98).opacity(0.12),
                                        Color(red: 0.68, green: 0.78, blue: 0.95).opacity(0.06),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 800, height: 24)
                            .blur(radius: 28)
                            .rotationEffect(.degrees(Double(index) * 45))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .position(x: geometry.size.width / 2 + 140, y: -260 + geometry.size.height / 2)
                .rotationEffect(.degrees(rotation * 0.3))
                .mask(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color.white.opacity(0.6),
                            Color.white.opacity(0.35),
                            Color.clear
                        ],
                        center: UnitPoint(x: (geometry.size.width / 2 + 140) / geometry.size.width,
                                        y: (-260 + geometry.size.height / 2) / geometry.size.height),
                        startRadius: 180,
                        endRadius: 600
                    )
                )
                .opacity(0.4)
                .blendMode(.screen)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            // Enhanced moonlight motes with depth
            if !reduceMotion {
                MoonlightMotesEffect()
                    .opacity(0.65)
                    .blendMode(.screen)
            }

            // Cool moonlight shimmer
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clear,
                            Color(red: 0.85, green: 0.90, blue: 1.0).opacity(0.12),
                            Color(red: 0.75, green: 0.85, blue: 0.98).opacity(0.08),
                            Color(red: 0.65, green: 0.80, blue: 0.95).opacity(0.04),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.75, y: 0.15),
                        startRadius: 50,
                        endRadius: 550
                    )
                )
                .opacity(0.25 + shimmer * 0.15)
                .blendMode(.overlay)

            // Atmospheric moonlight scattering effect
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.0),
                            Color(red: 0.80, green: 0.88, blue: 0.98).opacity(0.06),
                            Color(red: 0.70, green: 0.82, blue: 0.95).opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .opacity(0.35)
                .blendMode(.screen)
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            
            // Slower rotation for mysterious moon effect
            withAnimation(.linear(duration: 280).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            
            // Counter-rotation for depth effect
            withAnimation(.linear(duration: 380).repeatForever(autoreverses: false)) {
                secondaryRotation = -360
            }
            
            // Gentle pulsing shimmer
            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                shimmer = 1
            }
            
            // Subtle pulse for moon core
            withAnimation(.easeInOut(duration: 5.2).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }
}

struct MoonlightMotesEffect: View {
    @State private var motes: [(id: Int, x: CGFloat, y: CGFloat, size: CGFloat, speed: Double, delay: Double, horizontalDrift: CGFloat)] = []

    var body: some View {
        ZStack {
            ForEach(motes, id: \.id) { mote in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.90),
                                Color(red: 0.80, green: 0.88, blue: 0.98).opacity(0.60),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: mote.size / 2
                        )
                    )
                    .frame(width: mote.size, height: mote.size)
                    .blur(radius: 1.0)
                    .offset(x: mote.x, y: mote.y)
                    .modifier(MoonlightDriftModifier(
                        speed: mote.speed,
                        delay: mote.delay,
                        horizontalDrift: mote.horizontalDrift
                    ))
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            motes = (0..<60).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -280...280),
                    y: CGFloat.random(in: -140...340),
                    size: CGFloat.random(in: 1.2...2.8),
                    speed: Double.random(in: 10.0...18.0),
                    delay: Double.random(in: 0...4.0),
                    horizontalDrift: CGFloat.random(in: -30...30)
                )
            }
        }
    }
}

private struct MoonlightDriftModifier: ViewModifier {
    let speed: Double
    let delay: Double
    let horizontalDrift: CGFloat
    @State private var verticalOffset: CGFloat = 0
    @State private var horizontalOffset: CGFloat = 0
    @State private var opacity: Double = 0.0
    @State private var scale: CGFloat = 0.5

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .offset(x: horizontalOffset, y: verticalOffset)
            .onAppear {
                // Fade in and scale up
                withAnimation(.easeOut(duration: 2.0).delay(delay)) {
                    opacity = 1.0
                    scale = 1.0
                }
                
                // Vertical drift upward with fade out near the end
                withAnimation(.linear(duration: speed).delay(delay)) {
                    verticalOffset = -280
                }
                
                // Horizontal gentle sway - more pronounced for moon
                withAnimation(
                    .easeInOut(duration: speed * 0.7)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    horizontalOffset = horizontalDrift
                }
                
                // Fade out as it reaches the top
                DispatchQueue.main.asyncAfter(deadline: .now() + delay + speed * 0.75) {
                    withAnimation(.easeIn(duration: speed * 0.25)) {
                        opacity = 0.0
                    }
                }
            }
    }
}

struct RainEffect: View {
    @State private var drops: [(id: Int, x: CGFloat, delay: Double, speed: Double)] = []
    
    var body: some View {
        ZStack {
            // Rain drops with individual animations
            ForEach(drops, id: \.id) { drop in
                RainDrop(delay: drop.delay, speed: drop.speed)
                    .offset(x: drop.x)
            }
            
            // Subtle water ripple effect at bottom
            WaterRippleEffect()
        }
        .allowsHitTesting(false)
        .onAppear {
            drops = (0..<50).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -300...300),
                    delay: Double(i) * 0.05,
                    speed: Double.random(in: 0.6...1.0)
                )
            }
        }
    }
}

struct RainDrop: View {
    let delay: Double
    let speed: Double
    @State private var yOffset: CGFloat = -400
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 2, height: CGFloat.random(in: 25...45))
            .offset(y: yOffset)
            .blur(radius: 0.5)
            .onAppear {
                withAnimation(
                    .linear(duration: speed)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    yOffset = 700
                }
            }
    }
}

struct WaterRippleEffect: View {
    @State private var rippleScale: CGFloat = 0.5
    @State private var rippleOpacity: Double = 0.3
    
    var body: some View {
        Circle()
            .stroke(Color.white.opacity(rippleOpacity), lineWidth: 2)
            .frame(width: 200, height: 200)
            .scaleEffect(rippleScale)
            .offset(y: 300)
            .blur(radius: 3)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2)
                    .repeatForever(autoreverses: false)
                ) {
                    rippleScale = 1.5
                    rippleOpacity = 0
                }
            }
    }
}

struct DrizzleEffect: View {
    @State private var drops: [(id: Int, x: CGFloat, delay: Double, speed: Double)] = []
    
    var body: some View {
        ZStack {
            // Drizzle drops with individual animations - fewer and lighter than rain
            ForEach(drops, id: \.id) { drop in
                DrizzleDrop(delay: drop.delay, speed: drop.speed)
                    .offset(x: drop.x)
            }
            
            // Very subtle mist effect at bottom
            DrizzleMistEffect()
        }
        .allowsHitTesting(false)
        .onAppear {
            // Fewer drops than rain (30 vs 50) for lighter effect
            drops = (0..<30).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -300...300),
                    delay: Double(i) * 0.08, // Slightly more spaced out
                    speed: Double.random(in: 0.8...1.4) // Slower than rain
                )
            }
        }
    }
}

struct DrizzleDrop: View {
    let delay: Double
    let speed: Double
    @State private var yOffset: CGFloat = -400
    @State private var opacity: Double = 0.3
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.4),
                        Color.white.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 1.5, height: CGFloat.random(in: 15...30)) // Smaller than rain
            .offset(y: yOffset)
            .blur(radius: 0.8) // More blur for softer appearance
            .opacity(opacity)
            .onAppear {
                withAnimation(
                    .linear(duration: speed)
                    .repeatForever(autoreverses: false)
                    .delay(delay)
                ) {
                    yOffset = 700
                }
                
                // Subtle opacity variation to simulate lighter rain
                withAnimation(
                    .easeInOut(duration: speed * 0.6)
                    .repeatForever(autoreverses: true)
                    .delay(delay)
                ) {
                    opacity = Double.random(in: 0.2...0.5)
                }
            }
    }
}

struct DrizzleMistEffect: View {
    @State private var mistOpacity: Double = 0.0
    @State private var mistOffset: CGFloat = 0
    
    var body: some View {
        VStack {
            Spacer()
            
            // Subtle mist effect at the bottom
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(mistOpacity * 0.08),
                            Color.white.opacity(mistOpacity * 0.12),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 150)
                .blur(radius: 20)
                .offset(y: mistOffset)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 4)
                .repeatForever(autoreverses: true)
            ) {
                mistOpacity = 1.0
            }
            
            withAnimation(
                .easeInOut(duration: 6)
                .repeatForever(autoreverses: true)
            ) {
                mistOffset = -20
            }
        }
    }
}

struct SnowEffect: View {
    @State private var snowflakes: [(id: Int, x: CGFloat, size: CGFloat, delay: Double, speed: Double, drift: CGFloat)] = []
    
    var body: some View {
        ZStack {
            ForEach(snowflakes, id: \.id) { flake in
                Snowflake(
                    size: flake.size,
                    delay: flake.delay,
                    speed: flake.speed,
                    drift: flake.drift
                )
                .offset(x: flake.x)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            snowflakes = (0..<120).map { i in
                (
                    id: i,
                    x: CGFloat.random(in: -300...300),
                    size: CGFloat.random(in: 3...10),
                    delay: Double(i) * 0.05,
                    speed: Double.random(in: 4...8),
                    drift: CGFloat.random(in: -30...30)
                )
            }
        }
    }
}

struct Snowflake: View {
    let size: CGFloat
    let delay: Double
    let speed: Double
    let drift: CGFloat
    @State private var yOffset: CGFloat = -400
    @State private var xDrift: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // Snowflake shape
            Circle()
                .fill(Color.white.opacity(0.8))
            
            // Add sparkle effect for larger flakes
            if size > 7 {
                Circle()
                    .fill(Color.white)
                    .frame(width: size * 0.3, height: size * 0.3)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .white.opacity(0.4), radius: size * 0.5)
        .rotationEffect(.degrees(rotation))
        .offset(x: xDrift, y: yOffset)
        .onAppear {
            startSnowfallAnimation()
            
            withAnimation(
                .easeInOut(duration: speed / 2)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                xDrift = drift
            }
            
            withAnimation(
                .linear(duration: speed * 0.7)
                .repeatForever(autoreverses: false)
                .delay(delay)
            ) {
                rotation = 360
            }
        }
    }
    
    private func startSnowfallAnimation() {
        // Reset to top
        yOffset = -400
        
        // Animate down after initial delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateSnowfall()
        }
    }
    
    private func animateSnowfall() {
        withAnimation(.linear(duration: speed)) {
            yOffset = 700
        }
        
        // After animation completes, reset and start again
        DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
            startSnowfallAnimation()
        }
    }
}

struct CloudEffect: View {
    @State private var clouds: [(id: Int, yPos: CGFloat, width: CGFloat, height: CGFloat, delay: Double, speed: Double)] = []
    
    var body: some View {
        ZStack {
            ForEach(clouds, id: \.id) { cloud in
                AnimatedCloud(
                    width: cloud.width,
                    height: cloud.height,
                    delay: cloud.delay,
                    speed: cloud.speed
                )
                .offset(y: cloud.yPos)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            clouds = (0..<8).map { i in
                (
                    id: i,
                    yPos: CGFloat.random(in: -250...150),
                    width: CGFloat.random(in: 100...180),
                    height: CGFloat.random(in: 50...80),
                    delay: Double(i) * 3,
                    speed: Double.random(in: 40...70)
                )
            }
        }
    }
}

struct AnimatedCloud: View {
    let width: CGFloat
    let height: CGFloat
    let delay: Double
    let speed: Double
    @State private var xOffset: CGFloat = -400
    @State private var scaleEffect: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Main cloud body
            Ellipse()
                .fill(Color.white.opacity(0.25))
                .frame(width: width, height: height)
            
            // Cloud puffs for more realistic shape
            Ellipse()
                .fill(Color.white.opacity(0.2))
                .frame(width: width * 0.6, height: height * 0.7)
                .offset(x: -width * 0.2, y: -height * 0.1)
            
            Ellipse()
                .fill(Color.white.opacity(0.2))
                .frame(width: width * 0.5, height: height * 0.6)
                .offset(x: width * 0.25, y: height * 0.1)
        }
        .blur(radius: 20)
        .scaleEffect(scaleEffect)
        .offset(x: xOffset)
        .onAppear {
            withAnimation(
                .linear(duration: speed)
                .repeatForever(autoreverses: false)
                .delay(delay)
            ) {
                xOffset = 900
            }
            
            withAnimation(
                .easeInOut(duration: 5)
                .repeatForever(autoreverses: true)
                .delay(delay)
            ) {
                scaleEffect = 1.1
            }
        }
    }
}


struct CurrentWeatherView: View {
    let weather: CurrentWeather
    let locationName: String?
    let dailyForecast: DayWeather?
    let alerts: [WeatherAlert]
    let locationTimeZone: TimeZone?
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    var body: some View {
        VStack(spacing: 12) {
            // Weather Alerts
            if !alerts.isEmpty {
                ForEach(Array(alerts.enumerated()), id: \.offset) { _, alert in
                    WeatherAlertBanner(alert: alert)
                }
            }

            mainTemperatureCard

            // Weather Metrics
            compactMetricsStack

            // Sun & Moon Info
            if dailyForecast != nil {
                sunMoonCard
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    // MARK: - Main Temperature Card
    private var mainTemperatureCard: some View {
        VStack(spacing: 4) {
            if let locationName = locationName {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text(locationName)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            
            // Large weather icon
            Image(systemName: weather.symbolName)
                .font(.system(size: 60))
                .foregroundColor(.white)
                .symbolRenderingMode(.hierarchical)
                .padding(.vertical, 4)
            
            // Temperature
            Text("\(formattedTemperature(weather.temperature))°")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.white)
            
            // Condition description
            Text(weather.condition.description)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            
            // High/Low if available
            if let high = dailyForecast?.highTemperature,
               let low = dailyForecast?.lowTemperature {
                HStack(spacing: 10) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up")
                            .font(.caption2)
                        Text("\(formattedTemperature(high))°")
                    }
                    Text("•")
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.caption2)
                        Text("\(formattedTemperature(low))°")
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(GlassMorphicBackground())
        .cornerRadius(16)
    }
    
    // MARK: - Weather Metrics Grid
    private var weatherMetricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            // Wind Status
            WeatherMetricCard(
                title: "Wind Status",
                value: weather.wind.speed.formatted(),
                icon: "wind",
                accentColor: .cyan,
                subtitle: "Wind speed"
            )
            
            // UV Index
            WeatherMetricCard(
                title: "UV Index",
                value: "\(Int(weather.uvIndex.value))",
                icon: uvIndexIcon(for: weather.uvIndex.value),
                accentColor: uvIndexColor(for: weather.uvIndex.value),
                subtitle: weather.uvIndex.category.description,
                showGauge: true,
                gaugeValue: Double(weather.uvIndex.value) / 11.0
            )
            
            // Humidity
            WeatherMetricCard(
                title: "Humidity",
                value: "\(Int(weather.humidity * 100))%",
                icon: "humidity.fill",
                accentColor: .blue,
                subtitle: "Moisture level",
                showGauge: true,
                gaugeValue: weather.humidity
            )
            
            // Visibility
            WeatherMetricCard(
                title: "Visibility",
                value: formatVisibility(weather.visibility),
                icon: "eye.fill",
                accentColor: .purple,
                subtitle: "Current visibility"
            )
            
            // Feels Like
            WeatherMetricCard(
                title: "Feels Like",
                value: "\(formattedTemperature(weather.apparentTemperature))°",
                icon: "thermometer.medium",
                accentColor: .orange,
                subtitle: "Apparent temp"
            )
            
            // Pressure
            WeatherMetricCard(
                title: "Pressure",
                value: formatPressure(weather.pressure),
                icon: "gauge.with.dots.needle.33percent",
                accentColor: .green,
                subtitle: "Air pressure"
            )
        }
    }

// MARK: - Prototype Option 1: Compact Stack
private var compactMetricsStack: some View {
    VStack(spacing: 8) {
        MetricRow(icon: "wind", label: "Wind", value: weather.wind.speed.formatted())
        MetricRow(icon: "thermometer.medium", label: "Feels Like", value: "\(formattedTemperature(weather.apparentTemperature))°")
        MetricRow(icon: "humidity.fill", label: "Humidity", value: "\(Int(weather.humidity * 100))%")
        MetricRow(icon: "sun.max.fill", label: "UV Index", value: weather.uvIndex.category.description)
        MetricRow(icon: "eye.fill", label: "Visibility", value: formatVisibility(weather.visibility))
        MetricRow(icon: "gauge.with.dots.needle.33percent", label: "Pressure", value: formatPressure(weather.pressure))
    }
    .padding(12)
    .background(GlassMorphicBackground())
    .cornerRadius(16)
}


    
    // MARK: - Sun & Moon Card
    private var sunMoonCard: some View {
        VStack(spacing: 12) {
            if let sun = dailyForecast?.sun {
                HStack(spacing: 12) {
                    // Sunrise
                    if let sunrise = sun.sunrise {
                        VStack(spacing: 6) {
                            Image(systemName: "sunrise.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                                .symbolRenderingMode(.hierarchical)
                            
                            Text("Sunrise")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(formatTime(sunrise))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .frame(height: 50)
                    
                    // Sunset
                    if let sunset = sun.sunset {
                        VStack(spacing: 6) {
                            Image(systemName: "sunset.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                                .symbolRenderingMode(.hierarchical)
                            
                            Text("Sunset")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Text(formatTime(sunset))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            
            // Moon Phase
            if let moonPhase = dailyForecast?.moon.phase {
                Divider()
                    .background(Color.white.opacity(0.2))
                
                HStack(spacing: 10) {
                    Image(systemName: moonPhaseIcon(for: moonPhase))
                        .font(.title3)
                        .foregroundColor(.yellow)
                        .symbolRenderingMode(.hierarchical)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moon Phase")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(moonPhase.description)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(GlassMorphicBackground())
        .cornerRadius(16)
        
    }
    
    // MARK: - Helper Functions
    private func formattedTemperature(_ temp: Measurement<UnitTemperature>) -> Int {
        if useCelsius {
            return Int(temp.converted(to: .celsius).value)
        } else {
            return Int(temp.converted(to: .fahrenheit).value)
        }
    }
    
    private func formatVisibility(_ visibility: Measurement<UnitLength>) -> String {
        let km = visibility.converted(to: .kilometers).value
        if km >= 10 {
            return String(format: "%.0f km", km)
        } else {
            return String(format: "%.1f km", km)
        }
    }
    
    private func formatPressure(_ pressure: Measurement<UnitPressure>) -> String {
        let hPa = pressure.converted(to: .hectopascals).value
        return String(format: "%.0f hPa", hPa)
    }
    
    private func uvIndexIcon(for value: Int) -> String {
        switch value {
        case 0...2: return "sun.min.fill"
        case 3...5: return "sun.max.fill"
        case 6...7: return "sun.max.fill"
        case 8...10: return "exclamationmark.triangle.fill"
        default: return "exclamationmark.octagon.fill"
        }
    }
    
    private func uvIndexColor(for value: Int) -> Color {
        switch value {
        case 0...2: return .green
        case 3...5: return .yellow
        case 6...7: return .orange
        case 8...10: return .red
        default: return .purple
        }
    }
    
    private func moonPhaseIcon(for phase: MoonPhase) -> String {
        switch phase {
        case .new: return "moonphase.new.moon"
        case .waxingCrescent: return "moonphase.waxing.crescent"
        case .firstQuarter: return "moonphase.first.quarter"
        case .waxingGibbous: return "moonphase.waxing.gibbous"
        case .full: return "moonphase.full.moon"
        case .waningGibbous: return "moonphase.waning.gibbous"
        case .lastQuarter: return "moonphase.last.quarter"
        case .waningCrescent: return "moonphase.waning.crescent"
        @unknown default: return "moon.fill"
        }
    }
    
    // Helper method to format time with location's timezone
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = locationTimeZone ?? .current
        return formatter.string(from: date)
    }
}

// MARK: - Glassmorphic Background
struct GlassMorphicBackground: View {
    var body: some View {
        ZStack {
            Color.white.opacity(0.08)
            
            // Blur effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Weather Metric Card
struct WeatherMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let accentColor: Color
    var subtitle: String = ""
    var showGauge: Bool = false
    var gaugeValue: Double = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(accentColor)
                    .symbolRenderingMode(.hierarchical)
                
                Spacer()
            }
            
            Spacer()
            
            // Value
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Optional gauge
            if showGauge {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        // Progress
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentColor)
                            .frame(width: geometry.size.width * min(gaugeValue, 1.0), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding()
        .frame(height: showGauge ? 140 : 130)
        .background(GlassMorphicBackground())
        .cornerRadius(16)
    }
}


// MARK: - Compact metric components (Current view prototypes)
struct MetricRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .frame(width: 20, alignment: .center)
                .foregroundColor(.white.opacity(0.92))
                .symbolRenderingMode(.hierarchical)
                .font(.caption)

            Text(label)
                .foregroundColor(.white.opacity(0.75))

            Spacer(minLength: 8)

            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .font(.subheadline)
    }
}

struct CompactMetricTile: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.92))
                .symbolRenderingMode(.hierarchical)

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Text(value)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(GlassMorphicBackground())
        .cornerRadius(14)
    }
}


struct HourlyForecastView: View {
    let hourlyForecast: [HourWeather]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Hourly Forecast")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            if hourlyForecast.isEmpty {
                Text("No hourly forecast available")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            } else {
                VStack(spacing: 10) {
                    ForEach(hourlyForecast.prefix(24), id: \.date) { hour in
                        HourlyWeatherRow(hourWeather: hour)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct HourlyWeatherRow: View {
    let hourWeather: HourWeather
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    var body: some View {
        HStack {
            Text(hourWeather.date, style: .time)
                .frame(width: 80, alignment: .leading)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Image(systemName: hourWeather.symbolName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
                .frame(width: 40)
            
            Text(hourWeather.condition.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 15) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(Int(hourWeather.precipitationChance * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                Text("\(formattedTemperature(hourWeather.temperature))°")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formattedTemperature(_ temp: Measurement<UnitTemperature>) -> Int {
        if useCelsius {
            return Int(temp.converted(to: .celsius).value)
        } else {
            return Int(temp.converted(to: .fahrenheit).value)
        }
    }
}

struct DailyForecastView: View {
    let dailyForecast: [DayWeather]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("10-Day Forecast")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            if dailyForecast.isEmpty {
                Text("No daily forecast available")
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
            } else {
                VStack(spacing: 10) {
                    ForEach(dailyForecast.prefix(10), id: \.date) { day in
                        DailyWeatherRow(dayWeather: day)
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DailyWeatherRow: View {
    let dayWeather: DayWeather
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    var body: some View {
        HStack {
            Text(dayWeather.date, format: .dateTime.weekday(.wide))
                .frame(width: 100, alignment: .leading)
                .font(.subheadline)
                .foregroundColor(.white)
            
            Image(systemName: dayWeather.symbolName)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundColor(.white)
                .frame(width: 40)
            
            Text(dayWeather.condition.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 15) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(Int(dayWeather.precipitationChance * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 8) {
                    Text("\(formattedTemperature(dayWeather.lowTemperature))°")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Text("/")
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(formattedTemperature(dayWeather.highTemperature))°")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(width: 100, alignment: .trailing)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func formattedTemperature(_ temp: Measurement<UnitTemperature>) -> Int {
        if useCelsius {
            return Int(temp.converted(to: .celsius).value)
        } else {
            return Int(temp.converted(to: .fahrenheit).value)
        }
    }
}

struct WeatherDetail: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String? = nil
    
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// MARK: - New Feature Views

struct WeatherAlertBanner: View {
    let alert: WeatherAlert
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: severityIcon)
                    .foregroundColor(severityColor)
                    .font(.title2)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.summary)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    Text(alert.source)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .foregroundColor(.white.opacity(0.6))
                    .font(.title3)
                    .imageScale(.medium)
            }
            .padding(14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            }
            
            if isExpanded {
                VStack(spacing: 12) {
                    AlertDetailView(title: alert.summary, url: alert.detailsURL)
                        .frame(height: 320)

                    HStack(spacing: 12) {
                        Button {
                            NSWorkspace.shared.open(alert.detailsURL)
                        } label: {
                            Label("Open in Browser", systemImage: "safari")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue.opacity(0.7))
                        .controlSize(.regular)

                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            ZStack {
                // Base glassmorphic layer
                RoundedRectangle(cornerRadius: 12)
                    .fill(severityColor.opacity(0.15))
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                severityColor.opacity(0.2),
                                severityColor.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            severityColor.opacity(0.6),
                            severityColor.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: severityColor.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var severityIcon: String {
        switch alert.severity {
        case .extreme, .severe:
            return "exclamationmark.triangle.fill"
        case .moderate:
            return "exclamationmark.circle.fill"
        case .minor, .unknown:
            return "info.circle.fill"
        @unknown default:
            return "info.circle.fill"
        }
    }
    
    private var severityColor: Color {
        switch alert.severity {
        case .extreme:
            return .red
        case .severe:
            return .orange
        case .moderate:
            return .yellow
        case .minor, .unknown:
            return .blue
        @unknown default:
            return .blue
        }
    }
}

struct AlertDetailView: View {
    let title: String
    let url: URL
    @State private var isLoading = true
    @State private var parsedBlocks: [AlertBlock] = []

    var body: some View {
        ZStack {
            if !parsedBlocks.isEmpty {
                ParsedAlertView(blocks: parsedBlocks)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // While loading or if parsing fails, show the WebView temporarily
                AlertWebView(url: url, isLoading: $isLoading, onParsedBlocks: { blocks in
                    print("📦 AlertDetailView received \(blocks.count) parsed blocks")
                    self.parsedBlocks = blocks
                    if !blocks.isEmpty {
                        self.isLoading = false
                    }
                })
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if isLoading && parsedBlocks.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                    Text("Loading alert details…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.25))
                )
            }
        }
        .frame(maxHeight: 340)
    }
}

// MARK: - Alert Parsing Models

struct AlertLink: Codable {
    let href: String
    let text: String
}

struct AlertBlock: Codable, Identifiable {
    var id = UUID()
    let type: String
    let level: Int?
    let text: String?
    let links: [AlertLink]?
    let items: [String]?
    let label: String?  // For labeled sections like "Severity:", "Description", etc.
    let value: String?  // The value for the labeled section

    private enum CodingKeys: String, CodingKey {
        case type, level, text, links, items, label, value
    }
}


struct ParsedAlertView: View {
    let blocks: [AlertBlock]

    // Slightly more compact typography/padding so the whole alert card typically
    // fits without scrolling (while staying consistent with the rest of the UI).
    fileprivate enum Metrics {
        static let cardCorner: CGFloat = 16
        static let cardOuterHPadding: CGFloat = 12
        static let cardOuterVPadding: CGFloat = 8

        static let headerHPadding: CGFloat = 16
        static let headerVPadding: CGFloat = 12
        static let headerFontSize: CGFloat = 15
        static let chevronSize: CGFloat = 14

        static let rowHPadding: CGFloat = 10
        static let rowVPadding: CGFloat = 6
        static let sectionTitleSize: CGFloat = 13
        static let bodySize: CGFloat = 12
        static let lineSpacing: CGFloat = 2
        static let descriptionItemSpacing: CGFloat = 12
        static let dividerOpacity: Double = 0.14
    }

    // MARK: - Derived content

    private var alertTitle: String {
        // Prefer top-level heading if present
        if let h1 = blocks.first(where: { $0.type == "heading" && ($0.level ?? 1) == 1 })?.text, !h1.isEmpty {
            return h1
        }
        if let anyHeading = blocks.first(where: { $0.type == "heading" })?.text, !anyHeading.isEmpty {
            return anyHeading
        }
        return "Weather Alert"
    }

    private var allLinks: [AlertLink] {
        blocks.flatMap { $0.links ?? [] }
    }

    private var primarySourceLink: AlertLink? {
        // Prefer the "View Alert Source" link, otherwise first link
        if let explicit = allLinks.first(where: { $0.text.lowercased().contains("view alert source") }) {
            return explicit
        }
        return allLinks.first
    }

    private var rawParagraphText: String {
        blocks.first(where: { $0.type == "paragraph" })?.text ?? ""
    }

    private var labeledSectionsFromParser: [(String, String)] {
        var result: [(String, String)] = []
        for block in blocks {
            if block.type == "labeledSection", let label = block.label, let value = block.value {
                let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanLabel.isEmpty, !cleanValue.isEmpty {
                    result.append((cleanLabel, cleanValue))
                }
            }
        }
        return result
    }

    private var sections: [AlertSection] {
        // If the parser yielded labeled sections, use them.
        if !labeledSectionsFromParser.isEmpty {
            return buildSectionsFromLabeledPairs(labeledSectionsFromParser)
        }

        // Fallback: parse the single blob paragraph into sections.
        let normalized = normalizeRawAlertText(rawParagraphText)
        let pairs = splitIntoSections(normalized)
        if !pairs.isEmpty {
            return buildSectionsFromLabeledPairs(pairs)
        }

        // Last resort: just show the paragraph as Description.
        if !rawParagraphText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [AlertSection(kind: .description, title: "Description", lines: descriptionLines(from: normalizeRawAlertText(rawParagraphText)))]
        }

        return []
    }

    // MARK: - UI

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    Text(alertTitle)
                        .font(.system(size: Metrics.headerFontSize, weight: .semibold))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .padding(.horizontal, Metrics.headerHPadding)
                .padding(.vertical, Metrics.headerVPadding)

                Divider()
                    .background(Color.white.opacity(Metrics.dividerOpacity))

                // Sections
                VStack(spacing: 0) {
                    ForEach(sections.indices, id: \.self) { idx in
                        let section = sections[idx]
                        AlertSectionRow(section: section, sourceLink: section.kind == .issuedBy ? primarySourceLink : nil)

                        if idx < sections.count - 1 {
                            Divider()
                                .background(Color.white.opacity(Metrics.dividerOpacity))
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: Metrics.cardCorner, style: .continuous)
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardCorner, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
            .padding(.horizontal, Metrics.cardOuterHPadding)
            .padding(.vertical, Metrics.cardOuterVPadding)
        }
        .background(Color.clear)
    }

    // MARK: - Section building

    private func buildSectionsFromLabeledPairs(_ pairs: [(String, String)]) -> [AlertSection] {
        // Preserve the canonical order from the system alert UI.
        let preferredOrder: [AlertSection.Kind] = [
            .severity,
            .onset,
            .description,
            .actionRecommended,
            .urgency,
            .affectedArea,
            .issuedBy
        ]

        var mapped: [AlertSection] = []

        for (rawLabel, rawValue) in pairs {
            let kind = kindForLabel(rawLabel)
            let title = displayTitle(for: rawLabel, kind: kind)

            if kind == .description {
                mapped.append(AlertSection(kind: .description, title: title, lines: descriptionLines(from: normalizeRawAlertText(rawValue))))
            } else if kind == .severity {
                // Severity often includes an extra explanatory line in the blob; keep it as secondary.
                let normalized = normalizeRawAlertText(rawValue)
                let (first, rest) = splitFirstLine(normalized)
                var lines: [String] = []
                if !first.isEmpty { lines.append(first) }
                if !rest.isEmpty { lines.append(rest) }
                mapped.append(AlertSection(kind: .severity, title: title, lines: lines))
            } else {
                let normalized = normalizeRawAlertText(rawValue)
                let (first, rest) = splitFirstLine(normalized)
                var lines: [String] = []
                if !first.isEmpty { lines.append(first) }
                if !rest.isEmpty { lines.append(rest) }
                mapped.append(AlertSection(kind: kind, title: title, lines: lines))
            }
        }

        // Sort into preferred order when possible, otherwise keep original order.
        let orderIndex: [AlertSection.Kind: Int] = Dictionary(uniqueKeysWithValues: preferredOrder.enumerated().map { ($0.element, $0.offset) })
        mapped.sort {
            (orderIndex[$0.kind] ?? 999) < (orderIndex[$1.kind] ?? 999)
        }

        // De-duplicate by kind (some pages repeat headings)
        var seen = Set<AlertSection.Kind>()
        let deduped = mapped.filter { section in
            if seen.contains(section.kind) { return false }
            seen.insert(section.kind)
            return true
        }

        return deduped
    }

    private func kindForLabel(_ label: String) -> AlertSection.Kind {
        let l = label.lowercased()
        if l.contains("severity") { return .severity }
        if l.contains("onset") { return .onset }
        if l.contains("description") || l.contains("details") { return .description }
        if l.contains("action") { return .actionRecommended }
        if l.contains("urgency") { return .urgency }
        if l.contains("affected area") || l.contains("affected") { return .affectedArea }
        if l.contains("issued by") || l.contains("issuer") { return .issuedBy }
        return .generic
    }

    private func displayTitle(for rawLabel: String, kind: AlertSection.Kind) -> String {
        // Normalize titles to match the system card.
        switch kind {
        case .severity: return "Severity:"
        case .onset: return "Weather Event Onset"
        case .description: return "Description"
        case .actionRecommended: return "Action Recommended"
        case .urgency: return "Urgency"
        case .affectedArea: return "Affected Area"
        case .issuedBy: return "Issued By"
        default:
            // Remove trailing colon if present
            return rawLabel.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ":", with: "")
        }
    }

    // MARK: - Fallback parsing (single blob -> sections)

    private func splitIntoSections(_ text: String) -> [(String, String)] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { return [] }

        // Patterns as they tend to appear in the NWS pages / Weather app UI
        let labels: [(key: String, pattern: String)] = [
            ("Severity:", "Severity:"),
            ("Weather Event Onset", "Weather Event Onset"),
            ("Description", "Description"),
            ("Action Recommended", "Action Recommended"),
            ("Urgency", "Urgency"),
            ("Affected Area", "Affected Area"),
            ("Issued By", "Issued By")
        ]

        // Find the first occurrence of each label
        var hits: [(label: String, range: Range<String.Index>)] = []
        for item in labels {
            if let r = normalized.range(of: item.pattern, options: [.caseInsensitive]) {
                hits.append((label: item.key, range: r))
            }
        }
        hits.sort { $0.range.lowerBound < $1.range.lowerBound }

        // If we couldn't find any labels, treat as Description
        if hits.isEmpty {
            return [("Description", normalized)]
        }

        var result: [(String, String)] = []
        for i in 0..<hits.count {
            let current = hits[i]
            let start = current.range.upperBound
            let end = (i + 1 < hits.count) ? hits[i + 1].range.lowerBound : normalized.endIndex
            let value = String(normalized[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            result.append((current.label, value))
        }

        return result
    }

    // MARK: - Text normalization & formatting

    private func normalizeRawAlertText(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }

        // Some sources arrive as a single run-on string; fix the common concatenations first.
        s = regexReplace(s, pattern: #"([a-z])([A-Z])"#, replacement: "$1 $2")      // SevereSignificant -> Severe Significant
        s = regexReplace(s, pattern: #"([A-Za-z])([0-9])"#, replacement: "$1 $2")   // Onset7:00 -> Onset 7:00
        s = regexReplace(s, pattern: #"([0-9])([A-Z])"#, replacement: "$1 $2")      // 25Description -> 25 Description
        s = regexReplace(s, pattern: #"([.!?])([A-Z])"#, replacement: "$1 $2")      // difficult.Action -> difficult. Action

        // Ensure "Description*" becomes "Description\n*"
        s = s.replacingOccurrences(of: "Description*", with: "Description\n*", options: [.caseInsensitive])

        // Make sure bullets start on their own lines when they appear as "* WHAT..."
        s = regexReplace(s, pattern: #"\s*\*\s*"#, replacement: "\n* ")

        // Keep single spaces within lines
        s = s.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)

        // Clean up too many newlines
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func descriptionLines(from text: String) -> [String] {
        let s = normalizeRawAlertText(text)
        if s.isEmpty { return [] }

        // If it contains bullets, split on them but keep the "*" prefix.
        if s.contains("*") {
            let parts = s
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return parts
        }

        // Otherwise, fall back to sentence-ish chunks with breathing room.
        let collapsed = s.replacingOccurrences(of: "\n", with: " ")
        let spaced = regexReplace(collapsed, pattern: #"([.!?])\s+"#, replacement: "$1\n")
        return spaced
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func splitFirstLine(_ text: String) -> (String, String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return ("", "") }
        if let r = t.range(of: "\n") {
            let first = String(t[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = String(t[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (first, rest)
        }
        return (t, "")
    }

    private func regexReplace(_ input: String, pattern: String, replacement: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        let range = NSRange(location: 0, length: (input as NSString).length)
        return re.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
    }
}

// MARK: - Alert Section UI Models

struct AlertSection: Identifiable {
    enum Kind: Hashable {
        case severity
        case onset
        case description
        case actionRecommended
        case urgency
        case affectedArea
        case issuedBy
        case generic
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let lines: [String]
}

struct AlertSectionRow: View {
    let section: AlertSection
    let sourceLink: AlertLink?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch section.kind {
            case .severity:
                severityHeader
                if section.lines.count > 1 {
                    Text(section.lines[1])
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                }
            case .description:
                Text(section.title)
                    .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: ParsedAlertView.Metrics.descriptionItemSpacing) {
                    ForEach(section.lines.indices, id: \.self) { idx in
                        Text(section.lines[idx])
                            .font(.system(size: ParsedAlertView.Metrics.bodySize))
                            .foregroundColor(.white.opacity(0.60))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                    }
                }
                .padding(.top, 2)

            case .issuedBy:
                Text(section.title)
                    .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .semibold))
                    .foregroundColor(.white)

                if let first = section.lines.first {
                    Text(first)
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                }

                if let link = sourceLink, let url = URL(string: link.href) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text(link.text)
                            .font(.system(size: ParsedAlertView.Metrics.bodySize))
                            .foregroundColor(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

            default:
                Text(section.title)
                    .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .semibold))
                    .foregroundColor(.white)

                if let first = section.lines.first {
                    Text(first)
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                }
                if section.lines.count > 1 {
                    Text(section.lines[1])
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ParsedAlertView.Metrics.rowHPadding)
        .padding(.vertical, ParsedAlertView.Metrics.rowVPadding)
    }

    private var severityHeader: Text {
        let value = section.lines.first ?? ""
        // Match: "Severity: Moderate"
        return Text("Severity: ")
            .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .semibold))
            .foregroundColor(.white)
        + Text(value.isEmpty ? "" : value)
            .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .regular))
            .foregroundColor(.white)
    }
}

// A minimal WKWebView that loads the alert URL and parses content for native rendering
struct AlertWebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onParsedBlocks: (([AlertBlock]) -> Void)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Enable developer extras for inspecting content
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        if #available(macOS 11.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        let controller = WKUserContentController()
        
        // Add script message handler for alert parsing
        controller.add(context.coordinator, name: "alertsParser")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        // Make the WebView invisible since we only use it for parsing
        webView.alphaValue = 0
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false

        // Start loading
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        webView.load(request)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // No dynamic updates needed
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: AlertWebView
        init(_ parent: AlertWebView) { self.parent = parent }
        
        private func isAppleDomain(_ host: String?) -> Bool {
            guard let host = host else { return false }
            return host == "apple.com" || host.hasSuffix(".apple.com")
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
            
            // Inject JS to parse alert content and post message to native
            let parseScript = """
            (function(){
                try {
                    console.log('Starting alert parsing...');
                    
                    // First, expand all collapsible sections by clicking buttons
                    const expandButtons = document.querySelectorAll('button[aria-expanded="false"]');
                    console.log('Found ' + expandButtons.length + ' collapsed buttons');
                    expandButtons.forEach(btn => {
                        try {
                            btn.click();
                        } catch(e) {
                            console.log('Failed to click button:', e);
                        }
                    });
                    
                    // Wait a moment for content to expand, then parse
                    setTimeout(function() {
                        try {
                            const blocks = [];
                            
                            // Try to find the main content area with various selectors
                            let container = document.querySelector('.card .contents');
                            if (!container) {
                                container = document.querySelector('[class*="content"]');
                            }
                            if (!container) {
                                container = document.querySelector('main');
                            }
                            if (!container) {
                                container = document.body;
                            }
                            
                            console.log('Using container:', container.className || container.tagName);
                            
                            // Helper function to get text from a DD element, handling nested structure
                            function getDDText(dd) {
                                // Look for list items
                                const listItems = dd.querySelectorAll('li');
                                if (listItems.length > 0) {
                                    return Array.from(listItems).map(li => li.textContent.trim()).join(' * ');
                                }
                                // Otherwise get all text
                                return dd.textContent.trim();
                            }
                            
                            // Look for definition lists (DL) first - they contain the structured info
                            const definitionLists = container.querySelectorAll('dl');
                            definitionLists.forEach(dl => {
                                const dts = dl.querySelectorAll('dt');
                                const dds = dl.querySelectorAll('dd');
                                
                                for (let i = 0; i < dts.length; i++) {
                                    const label = dts[i].textContent.trim().replace(/\\*$/, '');
                                    const value = dds[i] ? getDDText(dds[i]) : '';
                                    
                                    if (label && value) {
                                        blocks.push({
                                            type: 'labeledSection',
                                            label: label,
                                            value: value
                                        });
                                    }
                                }
                            });
                            
                            console.log('Parsed ' + blocks.length + ' blocks from definition lists');
                            
                            // If we got some blocks, send them
                            if (blocks.length > 0) {
                                window.webkit.messageHandlers.alertsParser.postMessage({ ok: true, blocks: blocks });
                            } else {
                                // Fallback: parse the raw text and try to identify sections
                                const allText = container.textContent;
                                
                                // Try to split by known section markers
                                const sections = [];
                                
                                // Match patterns like "Label: value" or "Label * value"
                                const lines = allText.split('\\n').filter(l => l.trim());
                                let currentLabel = null;
                                let currentValue = [];
                                
                                for (let line of lines) {
                                    line = line.trim();
                                    
                                    // Check if this is a label line (ends with : or *)
                                    if (line.match(/^[A-Z][^:*]+[:\\*]\\s*$/)) {
                                        // Save previous section if exists
                                        if (currentLabel && currentValue.length > 0) {
                                            blocks.push({
                                                type: 'labeledSection',
                                                label: currentLabel,
                                                value: currentValue.join(' ').trim()
                                            });
                                        }
                                        // Start new section
                                        currentLabel = line.replace(/[:\\*]\\s*$/, '').trim();
                                        currentValue = [];
                                    } else if (currentLabel && line) {
                                        // Continue current section
                                        currentValue.push(line);
                                    }
                                }
                                
                                // Save last section
                                if (currentLabel && currentValue.length > 0) {
                                    blocks.push({
                                        type: 'labeledSection',
                                        label: currentLabel,
                                        value: currentValue.join(' ').trim()
                                    });
                                }
                                
                                console.log('Parsed ' + blocks.length + ' blocks using line parsing');
                                
                                if (blocks.length === 0) {
                                    // Ultimate fallback - just show the text
                                    blocks.push({
                                        type: 'paragraph',
                                        text: allText.trim()
                                    });
                                }
                                
                                window.webkit.messageHandlers.alertsParser.postMessage({ ok: true, blocks: blocks });
                            }
                        } catch(e) {
                            console.log('Parsing error:', e);
                            window.webkit.messageHandlers.alertsParser.postMessage({ ok: false, error: e.message });
                        }
                    }, 200); // Wait 200ms for content to expand
                    
                } catch(e) {
                    console.log('Outer error:', e);
                    window.webkit.messageHandlers.alertsParser.postMessage({ ok: false, error: e.message });
                }
            })();
            """
            webView.evaluateJavaScript(parseScript, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        // Keep the embedded view focused on the original alert content; open new links externally.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let targetURL = navigationAction.request.url {
                // Allow javascript: URLs to execute inline for in-page controls
                if targetURL.scheme == "javascript" {
                    decisionHandler(.allow)
                    return
                }
                
                // Allow same-document fragment navigation explicitly
                if let current = webView.url,
                   targetURL.scheme == current.scheme,
                   targetURL.host == current.host,
                   targetURL.path == current.path,
                   targetURL.fragment != nil {
                    decisionHandler(.allow)
                    return
                }

                // Allow in-page fragment changes and same-origin navigations (enable interactive toggles)
                if let currentURL = webView.url,
                   currentURL.scheme?.hasPrefix("http") == true,
                   targetURL.scheme?.hasPrefix("http") == true {
                    if currentURL.host == targetURL.host {
                        decisionHandler(.allow)
                        return
                    }
                }

                // Handle target=_blank: allow same-origin inline, external in browser
                if navigationAction.targetFrame == nil {
                    if let current = webView.url {
                        // Allow about:blank new windows inline (used by some expanders)
                        if targetURL.scheme == "about" && targetURL.absoluteString == "about:blank" {
                            decisionHandler(.allow)
                            return
                        }
                        // Allow inline for same-origin or Apple-owned hosts
                        if current.host == targetURL.host || isAppleDomain(targetURL.host) {
                            webView.load(URLRequest(url: targetURL))
                            decisionHandler(.cancel)
                            return
                        }
                    }
                    // Fallback: open externally
                    NSWorkspace.shared.open(targetURL)
                    decisionHandler(.cancel)
                    return
                }

                // Non-http(s) schemes open externally
                if targetURL.scheme != "http" && targetURL.scheme != "https" {
                    NSWorkspace.shared.open(targetURL)
                    decisionHandler(.cancel)
                    return
                }

                // External domains open in default browser, unless Apple domain
                if targetURL.host != parent.url.host && !isAppleDomain(targetURL.host) {
                    NSWorkspace.shared.open(targetURL)
                    decisionHandler(.cancel)
                    return
                }
            }

            // Default allow
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // If the site attempts to open a new window (target=_blank), keep same-origin and Apple domains inside, and allow about:blank
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                if url.scheme == "about" && url.absoluteString == "about:blank" {
                    return nil // let WebKit handle about:blank inline
                }
                if let current = webView.url {
                    if current.host == url.host || isAppleDomain(url.host) {
                        webView.load(URLRequest(url: url))
                        return nil
                    }
                }
            }
            return nil
        }

        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "alertsParser" {
                guard let dict = message.body as? [String: Any] else {
                    print("❌ Failed to parse message body")
                    return
                }
                
                if let ok = dict["ok"] as? Bool, ok, let blocksArray = dict["blocks"] as? [[String: Any]] {
                    print("✅ Received \(blocksArray.count) blocks from JavaScript")
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: blocksArray, options: [])
                        let blocks = try JSONDecoder().decode([AlertBlock].self, from: jsonData)
                        print("✅ Successfully decoded \(blocks.count) alert blocks")
                        DispatchQueue.main.async {
                            self.parent.onParsedBlocks(blocks)
                        }
                    } catch {
                        print("❌ Failed to decode blocks: \(error.localizedDescription)")
                    }
                } else if let error = dict["error"] as? String {
                    print("❌ JavaScript parsing error: \(error)")
                } else {
                    print("❌ Unexpected message format")
                }
            }
        }
    }
}

struct WeatherChartsView: View {
    let hourlyForecast: [HourWeather]
    let minuteForecast: Forecast<MinuteWeather>?
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Weather Charts")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            // Temperature Chart
            TemperatureChartView(hourlyForecast: hourlyForecast, useCelsius: useCelsius)
            
            // Feels Like Temperature Chart
            FeelsLikeChartView(hourlyForecast: hourlyForecast, useCelsius: useCelsius)
            
            // Precipitation Chart
            PrecipitationChartView(hourlyForecast: hourlyForecast)
            
            // Minute-by-minute precipitation
            if let minuteForecast = minuteForecast {
                MinutePrecipitationView(minuteForecast: minuteForecast)
            }
            
            // Wind Speed Chart
            WindSpeedChartView(hourlyForecast: hourlyForecast)
        }
        .padding(.bottom)
    }
}

// MARK: - Temperature Chart View
struct TemperatureChartView: View {
    let hourlyForecast: [HourWeather]
    let useCelsius: Bool
    @State private var selectedDate: Date? = nil
    @State private var selectedElement: Date? = nil
    
    private var selectedHour: HourWeather? {
        guard let date = selectedElement ?? selectedDate else { return nil }
        return hourlyForecast.prefix(24).min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temperature (24 Hours)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            Chart {
                ForEach(hourlyForecast.prefix(24), id: \.date) { hour in
                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Temperature", formattedTemp(hour.temperature))
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Time", hour.date),
                        y: .value("Temperature", formattedTemp(hour.temperature))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.orange.opacity(0.4), Color.orange.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    if let selected = selectedHour, selected.date == hour.date {
                        RuleMark(x: .value("Time", hour.date))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .top, spacing: 20, overflowResolution: .init(x: .fit, y: .fit)) {
                                ChartPopover {
                                    VStack(spacing: 6) {
                                        HStack(spacing: 8) {
                                            Image(systemName: selected.symbolName)
                                                .font(.title3)
                                                .foregroundColor(.orange)
                                                .symbolRenderingMode(.hierarchical)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(selected.date.formatted(date: .omitted, time: .shortened))
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.8))
                                                Text("\(Int(formattedTemp(selected.temperature)))°")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.orange)
                                            }
                                        }
                                        
                                        Divider()
                                            .background(Color.white.opacity(0.3))
                                        
                                        Text(selected.condition.description)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                    .frame(width: 140)
                                }
                            }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel(format: .dateTime.hour())
                        .foregroundStyle(Color.white)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                }
            }
            .chartXSelection(value: $selectedElement)
            .frame(height: 220)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal)
            .padding(.top, selectedHour == nil ? 0 : 20)
            
            if selectedHour == nil {
                Text("Hover over the chart to see details")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal)
            }
        }
    }
    
    private func formattedTemp(_ temp: Measurement<UnitTemperature>) -> Double {
        if useCelsius {
            return temp.converted(to: .celsius).value
        } else {
            return temp.converted(to: .fahrenheit).value
        }
    }
}

// MARK: - Chart Popover Component
struct ChartPopover<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.85
    
    var body: some View {
        content
            .padding(10)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .fixedSize()
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    opacity = 1
                    scale = 1
                }
            }
    }
}

// MARK: - Feels Like Chart View
struct FeelsLikeChartView: View {
    let hourlyForecast: [HourWeather]
    let useCelsius: Bool
    @State private var selectedDate: Date? = nil
    @State private var selectedElement: Date? = nil
    
    private var selectedHour: HourWeather? {
        guard let date = selectedElement ?? selectedDate else { return nil }
        return hourlyForecast.prefix(24).min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feels Like Temperature")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            Chart {
                ForEach(hourlyForecast.prefix(24), id: \.date) { hour in
                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Feels Like", formattedTemp(hour.apparentTemperature)),
                        series: .value("Type", "Feels Like")
                    )
                    .foregroundStyle(Color.purple)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Actual", formattedTemp(hour.temperature)),
                        series: .value("Type", "Actual")
                    )
                    .foregroundStyle(Color.orange)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    if let selected = selectedHour, selected.date == hour.date {
                        RuleMark(x: .value("Time", hour.date))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .top, spacing: 20, overflowResolution: .init(x: .fit, y: .fit)) {
                                ChartPopover {
                                    VStack(spacing: 6) {
                                        HStack(spacing: 10) {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Actual")
                                                    .font(.caption2)
                                                    .foregroundColor(.orange.opacity(0.9))
                                                Text("\(Int(formattedTemp(selected.temperature)))°")
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.orange)
                                            }
                                            
                                            Divider()
                                                .frame(height: 36)
                                                .background(Color.white.opacity(0.3))
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Feels")
                                                    .font(.caption2)
                                                    .foregroundColor(.purple.opacity(0.9))
                                                Text("\(Int(formattedTemp(selected.apparentTemperature)))°")
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.purple)
                                            }
                                        }
                                        
                                        Divider()
                                            .background(Color.white.opacity(0.3))
                                        
                                        HStack {
                                            Text(selected.date.formatted(date: .omitted, time: .shortened))
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                            Spacer()
                                            let diff = Int(formattedTemp(selected.apparentTemperature) - formattedTemp(selected.temperature))
                                            if diff != 0 {
                                                Text("Feels \(diff > 0 ? "\(diff)° warmer" : "\(abs(diff))° cooler")")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white.opacity(0.8))
                                            } else {
                                                Text("Feels same")
                                                    .font(.caption2)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(.white.opacity(0.8))
                                            }
                                        }
                                    }
                                    .frame(width: 160)
                                }
                            }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel(format: .dateTime.hour())
                        .foregroundStyle(Color.white)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                }
            }
            .chartForegroundStyleScale([
                "Feels Like": Color.purple,
                "Actual": Color.orange
            ])
            .chartXSelection(value: $selectedElement)
            .frame(height: 220)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal)
            .padding(.top, selectedHour == nil ? 0 : 20)
            
            if selectedHour == nil {
                Text("Hover over the chart to see details")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal)
            }
        }
    }
    
    private func formattedTemp(_ temp: Measurement<UnitTemperature>) -> Double {
        if useCelsius {
            return temp.converted(to: .celsius).value
        } else {
            return temp.converted(to: .fahrenheit).value
        }
    }
}

// MARK: - Precipitation Chart View
struct PrecipitationChartView: View {
    let hourlyForecast: [HourWeather]
    @State private var selectedDate: Date? = nil
    @State private var selectedElement: Date? = nil
    
    private var selectedHour: HourWeather? {
        guard let date = selectedElement ?? selectedDate else { return nil }
        return hourlyForecast.prefix(24).min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Precipitation Chance")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            Chart {
                ForEach(hourlyForecast.prefix(24), id: \.date) { hour in
                    BarMark(
                        x: .value("Time", hour.date),
                        y: .value("Chance", hour.precipitationChance * 100)
                    )
                    .foregroundStyle(
                        selectedHour?.date == hour.date ?
                        Color.cyan.gradient : Color.blue.gradient
                    )
                    
                    if let selected = selectedHour, selected.date == hour.date {
                        RuleMark(x: .value("Time", hour.date))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .top, spacing: 20, overflowResolution: .init(x: .fit, y: .fit)) {
                                ChartPopover {
                                    VStack(spacing: 6) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "drop.fill")
                                                .font(.title3)
                                                .foregroundColor(.cyan)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Precipitation")
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.8))
                                                Text("\(Int(selected.precipitationChance * 100))%")
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.cyan)
                                            }
                                        }
                                        
                                        Divider()
                                            .background(Color.white.opacity(0.3))
                                        
                                        VStack(spacing: 4) {
                                            HStack {
                                                Text(selected.date.formatted(date: .omitted, time: .shortened))
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.8))
                                                Spacer()
                                            }
                                            
                                            HStack(spacing: 4) {
                                                Image(systemName: selected.symbolName)
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.9))
                                                Text(selected.condition.description)
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                Spacer()
                                            }
                                        }
                                    }
                                    .frame(width: 150)
                                }
                            }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel(format: .dateTime.hour())
                        .foregroundStyle(Color.white)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                }
            }
            .chartXSelection(value: $selectedElement)
            .frame(height: 220)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal)
            .padding(.top, selectedHour == nil ? 0 : 20)
            
            if selectedHour == nil {
                Text("Tap on the chart to see details")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Minute Precipitation View
struct MinutePrecipitationView: View {
    let minuteForecast: Forecast<MinuteWeather>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Precipitation (Next Hour)")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            Chart {
                ForEach(Array(minuteForecast), id: \.date) { minute in
                    BarMark(
                        x: .value("Time", minute.date),
                        y: .value("Intensity", minute.precipitationIntensity.value)
                    )
                    .foregroundStyle(intensityColor(for: minute.precipitationIntensity.value))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .foregroundStyle(Color.white)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                }
            }
            .frame(height: 180)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal)
            
            Text("Minute-by-minute precipitation forecast")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal)
        }
    }
    
    private func intensityColor(for intensity: Double) -> Color {
        switch intensity {
        case 0...0.1:
            return Color.blue.opacity(0.3)
        case 0.1...0.5:
            return Color.blue.opacity(0.6)
        case 0.5...1.0:
            return Color.blue.opacity(0.8)
        default:
            return Color.blue
        }
    }
}

// MARK: - Wind Speed Chart View
struct WindSpeedChartView: View {
    let hourlyForecast: [HourWeather]
    @State private var selectedDate: Date? = nil
    @State private var selectedElement: Date? = nil
    
    private var selectedHour: HourWeather? {
        guard let date = selectedElement ?? selectedDate else { return nil }
        return hourlyForecast.prefix(24).min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Wind Speed")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            Chart {
                ForEach(hourlyForecast.prefix(24), id: \.date) { hour in
                    LineMark(
                        x: .value("Time", hour.date),
                        y: .value("Speed", hour.wind.speed.value)
                    )
                    .foregroundStyle(Color.cyan.gradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    AreaMark(
                        x: .value("Time", hour.date),
                        y: .value("Speed", hour.wind.speed.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.4), Color.cyan.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                    
                    if let selected = selectedHour, selected.date == hour.date {
                        RuleMark(x: .value("Time", hour.date))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .top, spacing: 20, overflowResolution: .init(x: .fit, y: .fit)) {
                                ChartPopover {
                                    VStack(spacing: 6) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "wind")
                                                .font(.title3)
                                                .foregroundColor(.cyan)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Wind")
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.8))
                                                Text(hour.wind.speed.formatted())
                                                    .font(.title3)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.cyan)
                                                    .lineLimit(1)
                                            }
                                        }
                                        
                                        Divider()
                                            .background(Color.white.opacity(0.3))
                                        
                                        VStack(spacing: 3) {
                                            HStack {
                                                Text(hour.date.formatted(date: .omitted, time: .shortened))
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.8))
                                                Spacer()
                                            }
                                            
                                            HStack {
                                                Text("Gust:")
                                                    .font(.caption2)
                                                    .foregroundColor(.white.opacity(0.7))
                                                if let gust = hour.wind.gust {
                                                    Text(gust.formatted())
                                                        .font(.caption2)
                                                        .foregroundColor(.white)
                                                } else {
                                                    Text("N/A")
                                                        .font(.caption2)
                                                        .foregroundColor(.white.opacity(0.6))
                                                }
                                                Spacer()
                                            }
                                            
                                            HStack(spacing: 4) {
                                                Image(systemName: "location.north.fill")
                                                    .rotationEffect(.degrees(hour.wind.direction.value))
                                                    .font(.caption2)
                                                    .foregroundColor(.cyan)
                                                Text("\(Int(hour.wind.direction.value))°")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                Spacer()
                                            }
                                        }
                                    }
                                    .frame(width: 140)
                                }
                            }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel(format: .dateTime.hour())
                        .foregroundStyle(Color.white)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.white.opacity(0.2))
                    AxisValueLabel()
                        .foregroundStyle(Color.white)
                }
            }
            .chartXSelection(value: $selectedElement)
            .frame(height: 220)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            .padding(.horizontal)
            .padding(.top, selectedHour == nil ? 0 : 20)
            
            if selectedHour == nil {
                Text("Hover over the chart to see details")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Weather Map View
struct WeatherMapView: View {
    let location: CLLocation?
    @ObservedObject var viewModel: WeatherViewModel
    @State private var region: MKCoordinateRegion
    @State private var mapType: MKMapType = .standard
    @State private var showControls = true
    
    init(location: CLLocation?, viewModel: WeatherViewModel) {
        self.location = location
        self.viewModel = viewModel
        
        if let location = location {
            _region = State(initialValue: MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            ))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weather Map")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("Map Type", selection: $mapType) {
                    Text("Standard").tag(MKMapType.standard)
                    Text("Satellite").tag(MKMapType.satellite)
                    Text("Hybrid").tag(MKMapType.hybrid)
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
            .padding(.horizontal)
            
            ZStack(alignment: .topTrailing) {
                WeatherMapRepresentable(
                    region: $region,
                    mapType: $mapType,
                    location: location,
                    weather: viewModel.currentWeather,
                    locationName: viewModel.locationName
                )
                .frame(height: 400)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .onChange(of: location) { oldValue, newValue in
                    if let newLocation = newValue {
                        region = MKCoordinateRegion(
                            center: newLocation.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                        )
                    }
                }
                
                if showControls {
                    VStack(spacing: 8) {
                        Button(action: {
                            if let location = location {
                                region = MKCoordinateRegion(
                                    center: location.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                                )
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Center on location")
                        
                        Button(action: {
                            var newSpan = region.span
                            newSpan.latitudeDelta *= 0.5
                            newSpan.longitudeDelta *= 0.5
                            region.span = newSpan
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Zoom in")
                        
                        Button(action: {
                            var newSpan = region.span
                            newSpan.latitudeDelta *= 2.0
                            newSpan.longitudeDelta *= 2.0
                            region.span = newSpan
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Zoom out")
                    }
                    .padding(12)
                }
            }
            .padding(.horizontal)
            
            if let weather = viewModel.currentWeather {
                WeatherMapInfoPanel(weather: weather, location: location)
                    .padding(.horizontal)
            } else {
                Text("No weather data available")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal)
            }
        }
    }
}

struct WeatherMapInfoPanel: View {
    let weather: CurrentWeather
    let location: CLLocation?
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: weather.symbolName)
                        .font(.title3)
                        .foregroundColor(.white)
                        .symbolRenderingMode(.hierarchical)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.condition.description)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("\(formattedTemperature(weather.temperature))°")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Image(systemName: "wind")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(weather.wind.speed.formatted())
                            .font(.caption2)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    VStack(spacing: 2) {
                        Image(systemName: "humidity.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(Int(weather.humidity * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 2) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(weather.visibility.formatted())
                            .font(.caption2)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            
            if let location = location {
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text("Lat:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(String(format: "%.4f°", location.coordinate.latitude))
                            .font(.caption)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 4) {
                        Text("Long:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(String(format: "%.4f°", location.coordinate.longitude))
                            .font(.caption)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func formattedTemperature(_ temp: Measurement<UnitTemperature>) -> Int {
        if useCelsius {
            return Int(temp.converted(to: .celsius).value)
        } else {
            return Int(temp.converted(to: .fahrenheit).value)
        }
    }
}

// MARK: - Non-Scrolling MapView
class NonScrollingMapView: MKMapView {
    override func scrollWheel(with event: NSEvent) {
        // Pass scroll events to the next responder (the SwiftUI ScrollView)
        // instead of letting the map zoom
        nextResponder?.scrollWheel(with: event)
    }
}

// MARK: - Custom MapKit Representable
struct WeatherMapRepresentable: NSViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    let location: CLLocation?
    let weather: CurrentWeather?
    let locationName: String?
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = NonScrollingMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = mapType
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsZoomControls = false
        
        if let location = location {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
            mapView.setRegion(region, animated: false)
            
            let annotation = WeatherAnnotation(
                coordinate: location.coordinate,
                weather: weather,
                locationName: locationName
            )
            mapView.addAnnotation(annotation)
            
            let circle = MKCircle(center: location.coordinate, radius: 50000)
            mapView.addOverlay(circle)
        }
        
        return mapView
    }
    
    func updateNSView(_ nsView: MKMapView, context: Context) {
        nsView.mapType = mapType
        nsView.setRegion(region, animated: true)
        
        nsView.removeAnnotations(nsView.annotations)
        nsView.removeOverlays(nsView.overlays)
        
        if let location = location {
            let annotation = WeatherAnnotation(
                coordinate: location.coordinate,
                weather: weather,
                locationName: locationName
            )
            nsView.addAnnotation(annotation)
            
            let circle = MKCircle(center: location.coordinate, radius: 50000)
            nsView.addOverlay(circle)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: WeatherMapRepresentable
        
        init(_ parent: WeatherMapRepresentable) { self.parent = parent }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async { self.parent.region = mapView.region }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "WeatherLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                if let markerView = annotationView as? MKMarkerAnnotationView,
                   let weatherAnnotation = annotation as? WeatherAnnotation {
                    if let weather = weatherAnnotation.weather {
                        let color = colorForWeather(weather)
                        markerView.markerTintColor = color
                        markerView.glyphImage = NSImage(systemSymbolName: weather.symbolName, accessibilityDescription: "Weather")
                        let detailView = createWeatherDetailView(weather: weather)
                        markerView.detailCalloutAccessoryView = detailView
                    } else {
                        markerView.markerTintColor = .systemBlue
                        markerView.glyphImage = NSImage(systemSymbolName: "cloud.sun.fill", accessibilityDescription: "Weather Location")
                    }
                    markerView.titleVisibility = .visible
                    markerView.subtitleVisibility = .visible
                }
            } else {
                annotationView?.annotation = annotation
                if let markerView = annotationView as? MKMarkerAnnotationView,
                   let weatherAnnotation = annotation as? WeatherAnnotation {
                    if let weather = weatherAnnotation.weather {
                        let color = colorForWeather(weather)
                        markerView.markerTintColor = color
                        markerView.glyphImage = NSImage(systemSymbolName: weather.symbolName, accessibilityDescription: "Weather")
                        let detailView = createWeatherDetailView(weather: weather)
                        markerView.detailCalloutAccessoryView = detailView
                    }
                }
            }
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                if let weather = parent.weather {
                    let weatherColor = colorForWeather(weather)
                    renderer.fillColor = weatherColor.withAlphaComponent(0.15)
                    renderer.strokeColor = weatherColor.withAlphaComponent(0.4)
                } else {
                    renderer.fillColor = NSColor.systemBlue.withAlphaComponent(0.1)
                    renderer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.3)
                }
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        private func colorForWeather(_ weather: CurrentWeather) -> NSColor {
            let temp = weather.temperature.value
            let condition = weather.condition.description.lowercased()
            if condition.contains("clear") || condition.contains("sunny") {
                return temp > 75 ? .systemOrange : .systemYellow
            } else if condition.contains("rain") || condition.contains("drizzle") {
                return .systemBlue
            } else if condition.contains("snow") {
                return .systemCyan
            } else if condition.contains("storm") || condition.contains("thunder") {
                return .systemPurple
            } else if condition.contains("cloud") {
                return .systemGray
            } else {
                return .systemBlue
            }
        }
        
        private func createWeatherDetailView(weather: CurrentWeather) -> NSView {
            let useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
            let temp = useCelsius ? Int(weather.temperature.converted(to: .celsius).value) : Int(weather.temperature.converted(to: .fahrenheit).value)
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
            let tempLabel = NSTextField(labelWithString: "\(temp)°")
            tempLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
            tempLabel.frame = NSRect(x: 10, y: 50, width: 180, height: 30)
            view.addSubview(tempLabel)
            let conditionLabel = NSTextField(labelWithString: weather.condition.description)
            conditionLabel.font = NSFont.systemFont(ofSize: 12)
            conditionLabel.frame = NSRect(x: 10, y: 35, width: 180, height: 15)
            view.addSubview(conditionLabel)
            let infoLabel = NSTextField(labelWithString: "💨 \(weather.wind.speed.formatted())  💧 \(Int(weather.humidity * 100))%")
            infoLabel.font = NSFont.systemFont(ofSize: 11)
            infoLabel.frame = NSRect(x: 10, y: 15, width: 180, height: 15)
            view.addSubview(infoLabel)
            return view
        }
    }
}

// Custom annotation class with weather data
class WeatherAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    let weather: CurrentWeather?
    
    init(coordinate: CLLocationCoordinate2D, weather: CurrentWeather? = nil, locationName: String? = nil) {
        self.coordinate = coordinate
        self.weather = weather
        if let locationName = locationName {
            self.title = locationName
        } else {
            self.title = "Weather Location"
        }
        if let weather = weather {
            let useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
            let temp = useCelsius ? Int(weather.temperature.converted(to: .celsius).value) : Int(weather.temperature.converted(to: .fahrenheit).value)
            self.subtitle = "\(temp)° • \(weather.condition.description)"
        } else {
            self.subtitle = "Current forecast area"
        }
        super.init()
    }
}

extension CLLocation: Identifiable {
    public var id: String { "\(coordinate.latitude),\(coordinate.longitude)" }
}

// MARK: - View Extensions
extension View {
    func scrollDisabledWhenChartsVisible(_ isChartsTab: Bool) -> some View { self }
}

// MARK: - Models
struct SavedLocation: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let latitude: Double
    let longitude: Double
    var isCurrentLocation: Bool
    
    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, isCurrentLocation: Bool = false) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.isCurrentLocation = isCurrentLocation
    }
    
    var clLocation: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
}

// MARK: - Cached Weather Data for Locations
struct CachedLocationWeather: Codable, Equatable {
    let locationId: UUID
    let temperature: Double // Store in Celsius for consistency
    let condition: String
    let symbolName: String
    let lastUpdated: Date
    
    init(locationId: UUID, weather: CurrentWeather, lastUpdated: Date = Date()) {
        self.locationId = locationId
        self.temperature = weather.temperature.converted(to: .celsius).value
        self.condition = weather.condition.description
        self.symbolName = weather.symbolName
        self.lastUpdated = lastUpdated
    }
}

// MARK: - Saved Location Card View
struct SavedLocationCard: View {
    let location: SavedLocation
    let isSelected: Bool
    let cachedWeather: CachedLocationWeather?
    let onSelect: () -> Void
    let onRemove: () -> Void
    
    @State private var currentTime = Date()
    @State private var timeZone: TimeZone?
    @State private var weatherIcon: String?
    @State private var temperature: Double?
    @State private var isLoadingWeather = false
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let weatherService = WeatherService.shared
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let weatherIcon = displayWeatherIcon {
                        Image(systemName: weatherIcon)
                            .font(.system(size: 11, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                    } else if isLoadingWeather {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 11, height: 11)
                    } else {
                        Image(systemName: location.isCurrentLocation ? "location.fill" : "mappin.circle.fill")
                            .font(.system(size: 11, weight: .medium))
                    }
                    
                    Text(location.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    
                    Spacer(minLength: 0)
                    
                    if let temp = displayTemperature {
                        Text("\(formattedTemperature(temp))°")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                    }
                }
                
                Text(formattedTime)
                    .font(.system(size: 10, weight: .semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minWidth: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.25),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
            .foregroundColor(.white)
            .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onAppear {
            fetchTimeZone()
            // Only fetch if we don't have cached data
            if cachedWeather == nil {
                fetchWeatherIcon()
            }
        }
        .onChange(of: cachedWeather) { oldValue, newValue in
            // Update local state when cached weather changes
            if let cached = newValue {
                weatherIcon = cached.symbolName
                temperature = cached.temperature
            }
        }
    }
    
    // Prefer cached weather data over local state
    private var displayWeatherIcon: String? {
        cachedWeather?.symbolName ?? weatherIcon
    }
    
    private var displayTemperature: Double? {
        cachedWeather?.temperature ?? temperature
    }
    
    private func formattedTemperature(_ temp: Double) -> Int {
        let tempMeasurement = Measurement(value: temp, unit: UnitTemperature.celsius)
        if useCelsius {
            return Int(tempMeasurement.value)
        } else {
            return Int(tempMeasurement.converted(to: .fahrenheit).value)
        }
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        
        if let timeZone = timeZone {
            formatter.timeZone = timeZone
        } else {
            // Fallback to local time while loading
            formatter.timeZone = .current
        }
        
        return formatter.string(from: currentTime)
    }
    
    private func fetchTimeZone() {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, error in
            if let placemark = placemarks?.first {
                self.timeZone = placemark.timeZone
            } else {
                // Fallback to current timezone if we can't determine
                self.timeZone = .current
            }
        }
    }
    
    private func fetchWeatherIcon() {
        isLoadingWeather = true
        
        Task {
            do {
                let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let weather = try await weatherService.weather(for: clLocation)
                
                DispatchQueue.main.async {
                    self.weatherIcon = weather.currentWeather.symbolName
                    self.temperature = weather.currentWeather.temperature.converted(to: .celsius).value
                    self.isLoadingWeather = false
                }
            } catch {
                // If weather fetch fails, fall back to location icon
                DispatchQueue.main.async {
                    self.weatherIcon = nil
                    self.temperature = nil
                    self.isLoadingWeather = false
                }
            }
        }
    }
}

// MARK: - View Model
class WeatherViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, MKLocalSearchCompleterDelegate {
    @Published var cityName = ""
    @Published var currentWeather: CurrentWeather?
    @Published var hourlyForecast: [HourWeather] = []
    @Published var dailyForecast: [DayWeather] = []
    @Published var minuteForecast: Forecast<MinuteWeather>?
    @Published var weatherAlerts: [WeatherAlert] = []
    @Published var locationName: String?
    @Published var locationTimeZone: TimeZone?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var refreshIntervalMinutes: Int = 30
    @Published var searchSuggestions: [MKLocalSearchCompletion] = []
    @Published var isShowingSuggestions: Bool = false
    @Published var savedLocations: [SavedLocation] = []
    @Published var currentLocationIndex: Int? = nil  // nil = showing current location, not a saved location
    @Published var lastUpdated: Date? = nil
    
    // Cache for weather data of saved locations
    @Published var locationWeatherCache: [UUID: CachedLocationWeather] = [:]

    var onWeatherUpdate: ((CurrentWeather) -> Void)?
    private let searchCompleter = MKLocalSearchCompleter()
    private var suppressAutocomplete = false

    private var refreshTimer: AnyCancellable?
    var lastLocation: CLLocation?

    private var locationRetryCount: Int = 0
    private let maxLocationRetries: Int = 3
    
    private let weatherService = WeatherService.shared
    private let geocoder = CLGeocoder()
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.requestWhenInUseAuthorization()
        
        loadSavedLocations()
        
        let storedMinutes = UserDefaults.standard.integer(forKey: "refreshIntervalMinutes")
        if storedMinutes > 0 {
            refreshIntervalMinutes = storedMinutes
        } else {
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: "refreshIntervalMinutes")
        }
        scheduleRefreshTimer()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserDefaultsChanged), name: UserDefaults.didChangeNotification, object: nil)
        
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address]
        
        // Refresh weather for saved locations on startup
        refreshAllSavedLocations()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        refreshTimer?.cancel()
    }
    
    // MARK: - Suggestions control
    func dismissSuggestions() {
        isShowingSuggestions = false
        searchSuggestions = []
        searchCompleter.queryFragment = ""
    }
    
    func searchCity() {
        guard !cityName.isEmpty else { return }
        isShowingSuggestions = false
        searchSuggestions = []
        
        isLoading = true
        errorMessage = nil
        
        geocoder.geocodeAddressString(cityName) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Could not find location: \(error.localizedDescription)"
                }
                return
            }
            
            guard let location = placemarks?.first?.location else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "City not found"
                }
                return
            }
            
            self.locationName = placemarks?.first?.locality ?? self.cityName
            self.fetchWeather(for: location)
        }
    }

    func updateSearchCompletions(for query: String) {
        if suppressAutocomplete { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 2 {
            searchCompleter.queryFragment = trimmed
            isShowingSuggestions = true
        } else {
            searchSuggestions = []
            isShowingSuggestions = false
        }
    }

    func selectSuggestion(_ suggestion: MKLocalSearchCompletion) {
        suppressAutocomplete = true
        searchCompleter.queryFragment = ""
        isLoading = true
        isShowingSuggestions = false
        cityName = suggestion.title
        searchSuggestions = []

        let request = MKLocalSearch.Request(completion: suggestion)
        DispatchQueue.main.async { [weak self] in self?.suppressAutocomplete = false }
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            if let item = response?.mapItems.first {
                let coord = item.placemark.coordinate
                let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let name = item.placemark.locality ?? item.name ?? suggestion.title
                DispatchQueue.main.async {
                    self.locationName = name
                    self.addSavedLocation(name: name, location: location)
                }
                self.fetchWeather(for: location)
            } else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = error?.localizedDescription ?? "Could not resolve location."
                }
            }
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchSuggestions = completer.results
            self.isShowingSuggestions = !completer.results.isEmpty
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.searchSuggestions = []
            self.isShowingSuggestions = false
        }
    }
    
    func fetchCurrentLocationWeather() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.currentLocationIndex = nil  // Reset to indicate we're viewing current location, not a saved one
        }

        guard CLLocationManager.locationServicesEnabled() else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Location services are disabled. Enable Location Services in System Settings."
            }
            return
        }

        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            self.locationRetryCount = 0
            locationManager.requestLocation()
            locationManager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Cannot access current location. Check app permissions in System Settings > Privacy & Security > Location Services."
            }
        @unknown default:
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Unknown location authorization status."
            }
        }
    }
    
    private func scheduleRefreshTimer() {
        refreshTimer?.cancel()
        let interval = TimeInterval(refreshIntervalMinutes * 60)
        guard interval > 0 else { return }

        refreshTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshNow()
            }
    }

    private func refreshNow() {
        if isLoading { return }
        
        // Refresh all saved locations in the background
        refreshAllSavedLocations()
        
        // If we're viewing a saved location, refresh that location's weather
        if let currentIndex = currentLocationIndex, currentIndex < savedLocations.count {
            let location = savedLocations[currentIndex]
            fetchWeather(for: location.clLocation)
        } else if let loc = lastLocation {
            // Otherwise refresh the last location (current location)
            fetchWeather(for: loc)
        } else {
            // Fallback: fetch current location
            fetchCurrentLocationWeather()
        }
    }
    
    private func refreshAllSavedLocations() {
        // Refresh weather for all saved locations in the background
        for location in savedLocations {
            Task {
                do {
                    let weather = try await weatherService.weather(for: location.clLocation)
                    let cachedWeather = CachedLocationWeather(locationId: location.id, weather: weather.currentWeather)
                    
                    DispatchQueue.main.async {
                        self.locationWeatherCache[location.id] = cachedWeather
                        self.saveWeatherCache()
                    }
                } catch {
                    // Silently fail for background refreshes - we don't want to show errors for locations not currently being viewed
                    print("Failed to refresh weather for \(location.name): \(error.localizedDescription)")
                }
            }
        }
    }
    
    func refreshCurrentWeather() {
        if let weather = currentWeather { onWeatherUpdate?(weather) }
        DispatchQueue.main.async { self.lastUpdated = Date() }
    }

    @objc private func handleUserDefaultsChanged() {
        let minutes = UserDefaults.standard.integer(forKey: "refreshIntervalMinutes")
        if minutes > 0 && minutes != refreshIntervalMinutes {
            refreshIntervalMinutes = minutes
            scheduleRefreshTimer()
        }
        if let weather = currentWeather { onWeatherUpdate?(weather) }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            self.locationRetryCount = 0
            manager.requestLocation()
            manager.startUpdatingLocation()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Location access denied. Please enable location services."
            }
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        manager.stopUpdatingLocation()
        self.locationRetryCount = 0

        searchCompleter.region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let locality = placemarks?.first?.locality {
                DispatchQueue.main.async { self?.locationName = locality }
            }
        }

        fetchWeather(for: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        if nsError.domain == kCLErrorDomain && nsError.code == CLError.locationUnknown.rawValue {
            if locationRetryCount < maxLocationRetries {
                locationRetryCount += 1
                let delay = pow(2.0, Double(locationRetryCount - 1))
                DispatchQueue.main.async {
                    self.isLoading = true
                    self.errorMessage = "Determining your location…"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    manager.requestLocation()
                    manager.startUpdatingLocation()
                }
                return
            }
        }

        DispatchQueue.main.async {
            self.isLoading = false
            if nsError.domain == kCLErrorDomain && nsError.code == CLError.denied.rawValue {
                self.errorMessage = "Location permission denied. Enable it in System Settings > Privacy & Security > Location Services."
            } else if nsError.domain == kCLErrorDomain && nsError.code == CLError.locationUnknown.rawValue {
                self.errorMessage = "Still couldn’t determine your location. Try moving outdoors, turning on Wi‑Fi, or checking Location Services."
            } else {
                self.errorMessage = "Failed to get current location: \(error.localizedDescription). Try moving outdoors or checking Location Services."
            }
        }
    }
    
    // MARK: - Saved Locations Management
    private func loadSavedLocations() {
        if let data = UserDefaults.standard.data(forKey: "savedLocations"),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = decoded
        }
        loadWeatherCache()
    }
    
    private func saveSavedLocations() {
        if let encoded = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(encoded, forKey: "savedLocations")
        }
    }
    
    private func loadWeatherCache() {
        if let data = UserDefaults.standard.data(forKey: "locationWeatherCache"),
           let decoded = try? JSONDecoder().decode([UUID: CachedLocationWeather].self, from: data) {
            locationWeatherCache = decoded
        }
    }
    
    private func saveWeatherCache() {
        if let encoded = try? JSONEncoder().encode(locationWeatherCache) {
            UserDefaults.standard.set(encoded, forKey: "locationWeatherCache")
        }
    }
    
    func getCachedWeather(for locationId: UUID) -> CachedLocationWeather? {
        return locationWeatherCache[locationId]
    }
    
    func addSavedLocation(name: String, location: CLLocation) {
        let newLocation = SavedLocation(name: name, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        
        // Check if location already exists
        if let existingIndex = savedLocations.firstIndex(where: { $0.latitude == newLocation.latitude && $0.longitude == newLocation.longitude }) {
            // Location exists, just select it
            currentLocationIndex = existingIndex
        } else {
            // Add new location and select it
            savedLocations.append(newLocation)
            currentLocationIndex = savedLocations.count - 1
            saveSavedLocations()
        }
    }
    
    func removeSavedLocation(at indexSet: IndexSet) {
        savedLocations.remove(atOffsets: indexSet)
        if let currentIndex = currentLocationIndex, currentIndex >= savedLocations.count {
            currentLocationIndex = savedLocations.isEmpty ? nil : max(0, savedLocations.count - 1)
        }
        saveSavedLocations()
    }
    
    func selectLocation(at index: Int) {
        guard index < savedLocations.count else { return }
        currentLocationIndex = index
        let location = savedLocations[index]
        locationName = location.name
        fetchWeather(for: location.clLocation)
    }
    
    private func fetchWeather(for location: CLLocation) {
        Task {
            self.lastLocation = location
            self.searchCompleter.region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
            )
            
            // Fetch timezone for the location
            geocoder.reverseGeocodeLocation(location) { placemarks, error in
                if let timeZone = placemarks?.first?.timeZone {
                    DispatchQueue.main.async {
                        self.locationTimeZone = timeZone
                    }
                }
            }
            
            do {
                let weather = try await weatherService.weather(for: location)
                let hourly = try await weatherService.weather(for: location, including: .hourly)
                let daily = try await weatherService.weather(for: location, including: .daily)
                let minute = try? await weatherService.weather(for: location, including: .minute)
                let alerts = try? await weatherService.weather(for: location, including: .alerts)
                
                DispatchQueue.main.async {
                    self.currentWeather = weather.currentWeather
                    self.hourlyForecast = Array(hourly)
                    self.dailyForecast = Array(daily)
                    self.minuteForecast = minute
                    self.weatherAlerts = alerts.map { Array($0) } ?? []
                    self.isLoading = false
                    self.errorMessage = nil
                    self.lastUpdated = Date()
                    self.onWeatherUpdate?(weather.currentWeather)
                    
                    // Cache weather data for this location if it's a saved location
                    if let currentIndex = self.currentLocationIndex, currentIndex < self.savedLocations.count {
                        let savedLocation = self.savedLocations[currentIndex]
                        let cachedWeather = CachedLocationWeather(locationId: savedLocation.id, weather: weather.currentWeather)
                        self.locationWeatherCache[savedLocation.id] = cachedWeather
                        self.saveWeatherCache()
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
                }
            }
        }
    }
    
    public func manualRefresh() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        if let location = lastLocation {
            fetchWeather(for: location)
        } else {
            fetchCurrentLocationWeather()
        }
    }
}

extension String.Encoding {
    init?(ianaCharsetName: String) {
        let cfEnc = CFStringConvertIANACharSetNameToEncoding(ianaCharsetName as CFString)
        if cfEnc != kCFStringEncodingInvalidId {
            self = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEnc))
        } else {
            return nil
        }
    }
}

#Preview {
    ContentView().mainContentView
}
