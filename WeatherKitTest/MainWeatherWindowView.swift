import SwiftUI
import AppKit
import Combine
import MapKit
import WeatherKit

struct MainWeatherWindowView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @EnvironmentObject private var shellState: AppShellState
    @EnvironmentObject private var appVisibility: AppVisibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("energySaverMode") private var energySaverMode: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sidebarFocusRequest: UUID?

    private var isSidebarVisible: Bool {
        sidebarIsVisible(for: columnVisibility)
    }

    private var sidebarVisibilityAnimation: Animation {
        WeatherMotionTokens.sidebarVisibility(
            isVisible: isSidebarVisible,
            reduceMotion: reduceMotion,
            energySaver: energySaverMode
        )
    }

    private var allowsLiveWindowContent: Bool {
        appVisibility.allowsLiveMainWindowRendering || shellState.mainWindow == nil
    }

    var body: some View {
        Group {
            if allowsLiveWindowContent {
                liveWindowContent
            } else {
                suspendedWindowContent
            }
        }
        .frame(minWidth: WeatherDesignTokens.mainWindowMin.width, minHeight: WeatherDesignTokens.mainWindowMin.height)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background(MainWindowVisibilityObserver().frame(width: 0, height: 0))
        .overlay(alignment: .top) {
            if allowsLiveWindowContent {
                WindowToolbarBackdrop()
            }
        }
        .toolbar {
            if allowsLiveWindowContent {
                ToolbarItemGroup(placement: .automatic) {
                    Menu {
                        ForEach(AppDestination.allCases) { destination in
                            Button {
                                shellState.open(destination)
                            } label: {
                                Label(destination.title, systemImage: destination.systemImage)
                            }
                        }
                    } label: {
                        Label(
                            shellState.selectedDestination.title,
                            systemImage: shellState.selectedDestination.systemImage
                        )
                    }
                    .help("Show Destination")

                    Button {
                        shellState.focusSearch()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .help("Focus Search")

                    Button {
                        viewModel.manualRefresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh")

                    SettingsLink {
                        Image(systemName: "gearshape")
                    }
                    .help("Settings")
                }
            }
        }
        .onAppear {
            if sidebarFocusRequest == nil {
                sidebarFocusRequest = shellState.searchFocusRequest
            }
        }
        .onChange(of: shellState.searchFocusRequest) { _, request in
            guard request != nil else { return }
            withAnimation(sidebarVisibilityAnimation) {
                columnVisibility = .all
            }
            DispatchQueue.main.async {
                sidebarFocusRequest = request
            }
        }
    }

    private func sidebarIsVisible(for visibility: NavigationSplitViewVisibility) -> Bool {
        visibility != .detailOnly
    }

    private var liveWindowContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WeatherSidebarView(
                viewModel: viewModel,
                searchFocusRequest: sidebarFocusRequest,
                isSidebarVisible: isSidebarVisible
            )
                .navigationSplitViewColumnWidth(min: 280, ideal: WeatherDesignTokens.sidebarWidth, max: 340)
        } detail: {
            MainWeatherDetailView(
                viewModel: viewModel,
                isSidebarVisible: isSidebarVisible
            )
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var suspendedWindowContent: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.16, blue: 0.30),
                Color(red: 0.04, green: 0.06, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct WeatherSidebarView: View {
    private struct SidebarSearchState {
        var hoveredSuggestionIndex: Int?
        var selectedSuggestionIndex: Int?

        mutating func reset() {
            hoveredSuggestionIndex = nil
            selectedSuggestionIndex = nil
        }
    }

    @ObservedObject var viewModel: WeatherViewModel
    let searchFocusRequest: UUID?
    let isSidebarVisible: Bool
    @EnvironmentObject private var shellState: AppShellState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("energySaverMode") private var energySaverMode: Bool = false
    @FocusState private var searchFocused: Bool
    @State private var searchState = SidebarSearchState()
    @State private var searchKeyMonitor: Any?
    @State private var currentTime = Date()
    @State private var lastHandledSearchFocusRequest: UUID?
    private let currentTimeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var sidebarVisibilityAnimation: Animation {
        WeatherMotionTokens.sidebarVisibility(
            isVisible: isSidebarVisible,
            reduceMotion: reduceMotion,
            energySaver: energySaverMode
        )
    }

    private var sidebarInteractionAnimation: Animation {
        WeatherMotionTokens.interaction(reduceMotion: reduceMotion, energySaver: energySaverMode)
    }

    private var sidebarMotionEnabled: Bool {
        !reduceMotion && !energySaverMode
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: WeatherDesignTokens.sectionSpacing) {
                stagedSidebarPanel(
                    WeatherSidebarHeader(viewModel: viewModel),
                    order: 0
                )
                stagedSidebarPanel(destinationSection, order: 1)
                stagedSidebarPanel(searchSection, order: 2)
                stagedSidebarPanel(locationsSection, order: 3)
            }
            .padding(18)
            .scrollTargetLayout()
        }
        .background(sidebarBackdrop)
        .weatherSoftTopScrollEdgeEffect()
        .onAppear {
            installSearchKeyMonitor()
            requestSearchFocusIfNeeded(for: searchFocusRequest)
        }
        .onChange(of: searchFocusRequest) { _, request in
            requestSearchFocusIfNeeded(for: request)
        }
        .onReceive(currentTimeTimer) { newTime in
            currentTime = newTime
        }
        .onChange(of: searchFocused) { _, isFocused in
            if !isFocused {
                dismissSearchInteraction()
            }
        }
        .onChange(of: viewModel.isShowingSuggestions) { _, _ in
            syncSuggestionSelection()
        }
        .onChange(of: viewModel.searchSuggestions.count) { _, _ in
            syncSuggestionSelection()
        }
        .onDisappear {
            removeSearchKeyMonitor()
        }
    }

    private func stagedSidebarPanel<Content: View>(_ content: Content, order: Int) -> some View {
        content
            .modifier(SidebarPanelScrollEffectModifier(isEnabled: sidebarMotionEnabled))
            .opacity(isSidebarVisible || !sidebarMotionEnabled ? 1.0 : 0.96)
            .offset(x: isSidebarVisible || !sidebarMotionEnabled ? 0 : -8)
            .animation(
                sidebarPanelAnimation(for: order),
                value: isSidebarVisible
            )
    }

    private func sidebarPanelAnimation(for order: Int) -> Animation {
        let baseAnimation = sidebarVisibilityAnimation
        guard isSidebarVisible, sidebarMotionEnabled else { return baseAnimation }
        return baseAnimation.delay(WeatherMotionTokens.staggerDelay(for: order))
    }

    private var sidebarBackdrop: some View {
        RoundedRectangle(cornerRadius: 0, style: .continuous)
            .fill(WeatherDesignTokens.panelBase.opacity(0.96))
            .overlay(
                Rectangle()
                    .fill(.regularMaterial)
                    .opacity(0.82)
            )
            .overlay(
                Rectangle()
                    .fill(WeatherDesignTokens.panelFill)
            )
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1)
            }
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Destinations")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))

            ForEach(AppDestination.allCases) { destination in
                Button {
                    shellState.open(destination)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: destination.systemImage)
                            .frame(width: 18)
                        Text(destination.title)
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(shellState.selectedDestination == destination ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(shellState.selectedDestination == destination ? 0.14 : 0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(shellState.selectedDestination == destination ? 1.0 : 0.82))
            }
        }
        .padding(16)
        .weatherShellPanel(cornerRadius: WeatherDesignTokens.cardCorner)
    }

    private var suggestionsToShow: [MKLocalSearchCompletion] {
        Array(viewModel.searchSuggestions.prefix(6))
    }

    private var highlightedSuggestionIndex: Int? {
        searchState.hoveredSuggestionIndex ?? searchState.selectedSuggestionIndex
    }

    private var selectedSavedLocationID: UUID? {
        guard let currentIndex = viewModel.currentLocationIndex,
              viewModel.savedLocations.indices.contains(currentIndex) else {
            return nil
        }

        return viewModel.savedLocations[currentIndex].id
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Search")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))

                Spacer()

                Text("Command-L")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.52))
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.70))

                TextField("Search locations", text: $viewModel.cityName)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .foregroundStyle(.white)
                    .onSubmit {
                        submitSearch()
                    }
                    .onChange(of: viewModel.cityName) { _, newValue in
                        searchState.hoveredSuggestionIndex = nil
                        searchState.selectedSuggestionIndex = nil
                        viewModel.updateSearchCompletions(for: newValue)
                    }

                if !viewModel.cityName.isEmpty {
                    Button {
                        dismissSearchInteraction(clearQuery: true)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                    .help("Clear Search")
                }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )

            Text("Use the arrow keys to pick a match, then press Return.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))

            if viewModel.isShowingSuggestions, !suggestionsToShow.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(suggestionsToShow.enumerated()), id: \.element) { index, suggestion in
                        SuggestionRow(
                            suggestion: suggestion,
                            isHighlighted: highlightedSuggestionIndex == index,
                            onTap: {
                                acceptSuggestion(suggestion)
                            },
                            onHoverChange: { hovering in
                                searchState.hoveredSuggestionIndex = hovering ? index : nil
                                if hovering {
                                    searchState.selectedSuggestionIndex = index
                                }
                            }
                        )
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top)
                            .combined(with: .opacity)
                            .combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .padding(16)
        .weatherShellPanel(cornerRadius: WeatherDesignTokens.cardCorner)
        .animation(sidebarInteractionAnimation, value: viewModel.isShowingSuggestions)
        .animation(sidebarInteractionAnimation, value: suggestionsToShow.count)
    }

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Locations")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))

                    Text("Search adds cities here automatically.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer()

                Text("\(viewModel.savedLocations.count + 1)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Button {
                viewModel.fetchCurrentLocationWeather(userInitiated: true)
            } label: {
                WeatherSidebarLocationRow(
                    title: "Current Location",
                    subtitle: viewModel.currentLocationIndex == nil
                        ? (viewModel.loadingStatusMessage ?? viewModel.locationName ?? "Live weather")
                        : "Use device location",
                    symbolName: viewModel.currentLocationIndex == nil ? viewModel.currentWeather?.symbolName : "location.fill",
                    temperature: viewModel.currentLocationIndex == nil ? viewModel.currentWeather?.temperature : nil,
                    isSelected: viewModel.currentLocationIndex == nil
                )
            }
            .buttonStyle(.plain)
            .modifier(
                SidebarRowScrollEffectModifier(
                    isSelected: viewModel.currentLocationIndex == nil,
                    isEnabled: sidebarMotionEnabled
                )
            )

            ForEach(Array(viewModel.savedLocations.enumerated()), id: \.element.id) { index, location in
                WeatherSidebarSavedLocationItem(
                    location: location,
                    cachedWeather: viewModel.locationWeatherCache[location.id],
                    currentTime: currentTime,
                    isSelected: selectedSavedLocationID == location.id,
                    canMoveUp: index > 0,
                    canMoveDown: index < viewModel.savedLocations.count - 1,
                    onSelect: {
                        viewModel.selectLocation(id: location.id)
                    },
                    onMoveUp: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            viewModel.moveSavedLocation(from: index, to: index - 1)
                        }
                    },
                    onMoveDown: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            viewModel.moveSavedLocation(from: index, to: index + 2)
                        }
                    },
                    onRemove: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                            viewModel.removeSavedLocation(id: location.id)
                        }
                    },
                    scrollMotionEnabled: sidebarMotionEnabled
                )
            }

            if viewModel.savedLocations.isEmpty {
                Text("No saved cities yet. Search for a place and it will appear here.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .weatherShellPanel(cornerRadius: WeatherDesignTokens.cardCorner)
    }

    private func installSearchKeyMonitor() {
        guard searchKeyMonitor == nil else { return }

        searchKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleSearchKeyEvent(event)
        }
    }

    private func removeSearchKeyMonitor() {
        guard let searchKeyMonitor else { return }
        NSEvent.removeMonitor(searchKeyMonitor)
        self.searchKeyMonitor = nil
    }

    private func handleSearchKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard searchFocused else { return event }

        switch event.keyCode {
        case 125:
            guard !suggestionsToShow.isEmpty else { return event }
            moveSuggestionSelection(delta: 1)
            return nil
        case 126:
            guard !suggestionsToShow.isEmpty else { return event }
            moveSuggestionSelection(delta: -1)
            return nil
        case 36, 76:
            submitSearch()
            return nil
        case 53:
            handleEscapeKey()
            return nil
        default:
            return event
        }
    }

    private func moveSuggestionSelection(delta: Int) {
        guard !suggestionsToShow.isEmpty else { return }

        let currentIndex = searchState.selectedSuggestionIndex ?? (delta > 0 ? -1 : 0)
        let nextIndex = (currentIndex + delta + suggestionsToShow.count) % suggestionsToShow.count
        searchState.selectedSuggestionIndex = nextIndex
        searchState.hoveredSuggestionIndex = nil
    }

    private func submitSearch() {
        let trimmedQuery = viewModel.cityName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        if let selectedIndex = highlightedSuggestionIndex,
           suggestionsToShow.indices.contains(selectedIndex),
           viewModel.isShowingSuggestions {
            acceptSuggestion(suggestionsToShow[selectedIndex])
            return
        }

        viewModel.searchCity()
        searchFocused = false
        searchState.reset()
    }

    private func acceptSuggestion(_ suggestion: MKLocalSearchCompletion) {
        searchState.reset()
        viewModel.selectSuggestion(suggestion)
        searchFocused = false
    }

    private func dismissSearchInteraction(clearQuery: Bool = false) {
        if clearQuery {
            viewModel.cityName = ""
        }
        searchState.reset()
        viewModel.dismissSuggestions()
    }

    private func handleEscapeKey() {
        if viewModel.isShowingSuggestions {
            dismissSearchInteraction()
        } else if !viewModel.cityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dismissSearchInteraction(clearQuery: true)
        } else {
            searchFocused = false
        }
    }

    private func syncSuggestionSelection() {
        guard viewModel.isShowingSuggestions, !suggestionsToShow.isEmpty else {
            searchState.reset()
            return
        }

        if let selectedIndex = searchState.selectedSuggestionIndex,
           suggestionsToShow.indices.contains(selectedIndex) {
            return
        }

        searchState.selectedSuggestionIndex = 0
    }

    private func requestSearchFocusIfNeeded(for request: UUID?) {
        guard let request else { return }
        guard lastHandledSearchFocusRequest != request else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard searchFocusRequest == request else { return }
            lastHandledSearchFocusRequest = request
            searchFocused = true
        }
    }
}

private struct WeatherSidebarHeader: View {
    @ObservedObject var viewModel: WeatherViewModel
    @AppStorage("useCelsius") private var useCelsius: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Forecast")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.60))

                    Text(viewModel.locationName ?? "Weather")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer()

                if let weather = viewModel.currentWeather {
                    Text("\(formattedTemperature(weather.temperature))°")
                        .font(.system(size: 34, weight: .thin))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }
            }

            Text(viewModel.currentWeather?.condition.description ?? "Select a location to explore the forecast.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(18)
        .weatherShellPanel(cornerRadius: WeatherDesignTokens.shellCorner)
    }

    private func formattedTemperature(_ temperature: Measurement<UnitTemperature>) -> Int {
        let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
        return Int(temperature.converted(to: unit).value.rounded())
    }
}

private struct WeatherSidebarLocationRow: View {
    let title: String
    let subtitle: String
    var timeText: String? = nil
    let symbolName: String?
    var temperature: Measurement<UnitTemperature>? = nil
    var cachedTemperature: CachedLocationWeather? = nil
    let isSelected: Bool
    var isHighlighted: Bool = false
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("energySaverMode") private var energySaverMode: Bool = false

    private var interactionAnimation: Animation {
        WeatherMotionTokens.interaction(reduceMotion: reduceMotion, energySaver: energySaverMode)
    }

    private var emphasisActive: Bool {
        isSelected || isHighlighted
    }

    private var rowScale: CGFloat {
        guard emphasisActive, !reduceMotion, !energySaverMode else { return 1.0 }
        return 1.01
    }

    private var rowOffset: CGFloat {
        guard emphasisActive, !reduceMotion, !energySaverMode else { return 0 }
        return 2
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName ?? "location")
                .frame(width: 18)
                .foregroundStyle(.white.opacity(0.86))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if let timeText {
                    Text(timeText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.68))
                        .monospacedDigit()
                        .lineLimit(1)
                }

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer()

            if let temperatureLabel {
                Text(temperatureLabel)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(emphasisActive ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(emphasisActive ? 0.16 : 0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(emphasisActive ? 0.14 : 0), radius: emphasisActive ? 18 : 0, x: 0, y: 10)
        .scaleEffect(rowScale)
        .offset(x: rowOffset)
        .animation(interactionAnimation, value: emphasisActive)
    }

    private var temperatureLabel: String? {
        if let temperature {
            let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
            let value = Int(temperature.converted(to: unit).value.rounded())
            return "\(value)°"
        }

        if let cachedTemperature {
            let source = Measurement(value: cachedTemperature.temperature, unit: UnitTemperature.celsius)
            let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
            let value = Int(source.converted(to: unit).value.rounded())
            return "\(value)°"
        }

        return nil
    }
}

private struct WeatherSidebarSavedLocationItem: View {
    let location: SavedLocation
    let cachedWeather: CachedLocationWeather?
    let currentTime: Date
    let isSelected: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onSelect: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void
    let scrollMotionEnabled: Bool

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("energySaverMode") private var energySaverMode: Bool = false
    private static var localTimeFormatters: [String: DateFormatter] = [:]

    private var interactionAnimation: Animation {
        WeatherMotionTokens.interaction(reduceMotion: reduceMotion, energySaver: energySaverMode)
    }

    private var interactionEmphasisActive: Bool {
        isHovering || isSelected
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                WeatherSidebarLocationRow(
                    title: location.name,
                    subtitle: cachedWeather?.condition ?? "Saved location",
                    timeText: formattedLocalTime,
                    symbolName: cachedWeather?.symbolName,
                    cachedTemperature: cachedWeather,
                    isSelected: isSelected,
                    isHighlighted: isHovering
                )
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    onMoveUp()
                } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(!canMoveUp)

                Button {
                    onMoveDown()
                } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(!canMoveDown)

                Divider()

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Label("Remove Location", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(interactionEmphasisActive ? 0.88 : 0.56))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(interactionEmphasisActive ? 0.14 : 0.06))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(interactionEmphasisActive ? 0.16 : 0.10), lineWidth: 1)
                    )
                    .scaleEffect(interactionEmphasisActive && !reduceMotion && !energySaverMode ? 1.04 : 1.0)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .help("Location Actions")
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                onMoveUp()
            } label: {
                Label("Move Up", systemImage: "arrow.up")
            }
            .disabled(!canMoveUp)

            Button {
                onMoveDown()
            } label: {
                Label("Move Down", systemImage: "arrow.down")
            }
            .disabled(!canMoveDown)

            Divider()

            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove Location", systemImage: "trash")
            }
        }
        .onHover { hovering in
            withAnimation(interactionAnimation) {
                isHovering = hovering
            }
        }
        .animation(interactionAnimation, value: interactionEmphasisActive)
        .modifier(
            SidebarRowScrollEffectModifier(
                isSelected: isSelected,
                isEnabled: scrollMotionEnabled
            )
        )
    }

    private var formattedLocalTime: String? {
        guard let timeZoneIdentifier = cachedWeather?.timeZoneIdentifier else {
            return nil
        }

        let formatter: DateFormatter
        if let cachedFormatter = Self.localTimeFormatters[timeZoneIdentifier] {
            formatter = cachedFormatter
        } else {
            guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
                return nil
            }
            let newFormatter = DateFormatter()
            newFormatter.timeStyle = .short
            newFormatter.timeZone = timeZone
            Self.localTimeFormatters[timeZoneIdentifier] = newFormatter
            formatter = newFormatter
        }

        return formatter.string(from: currentTime)
    }
}

private struct MainWeatherDetailView: View {
    @ObservedObject var viewModel: WeatherViewModel
    let isSidebarVisible: Bool
    @EnvironmentObject private var shellState: AppShellState
    @EnvironmentObject private var appVisibility: AppVisibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("energySaverMode") private var energySaverMode: Bool = false

    private var motionEnabled: Bool {
        !reduceMotion && !energySaverMode
    }

    private var sidebarVisibilityAnimation: Animation {
        WeatherMotionTokens.sidebarVisibility(
            isVisible: isSidebarVisible,
            reduceMotion: reduceMotion,
            energySaver: energySaverMode
        )
    }

    private var detailContentOffset: CGFloat {
        guard isSidebarVisible, motionEnabled else { return 0 }
        return WeatherMotionTokens.detailLiftOffset
    }

    private var detailContentScale: CGFloat {
        guard isSidebarVisible, motionEnabled else { return 1.0 }
        return WeatherMotionTokens.detailLiftScale
    }

    private var allowsLiveRendering: Bool {
        appVisibility.allowsLiveMainWindowRendering
    }

    var body: some View {
        ZStack {
            if allowsLiveRendering {
                detailBackdrop
            } else {
                suspendedBackdrop
            }

            if allowsLiveRendering {
                // Suspend expensive backdrop, overview, and map rendering while the window is fully off-screen.
                detailContent
                    .scaleEffect(detailContentScale, anchor: .leading)
                    .offset(x: detailContentOffset)
                    .shadow(color: .black.opacity(isSidebarVisible && motionEnabled ? 0.14 : 0), radius: isSidebarVisible && motionEnabled ? 18 : 0, x: 0, y: 14)
                    .overlay {
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isSidebarVisible && motionEnabled ? 0.025 : 0),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .allowsHitTesting(false)
                    }
                    .animation(sidebarVisibilityAnimation, value: isSidebarVisible)
            } else {
                Color.clear
                    .allowsHitTesting(false)
            }
        }
        .environment(\.isDaylight, viewModel.currentWeather?.isDaylight)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch shellState.selectedDestination {
        case .overview:
            OverviewDestinationView(viewModel: viewModel)
        case .map:
            WeatherMapDestinationView(viewModel: viewModel)
        case .alerts:
            AlertsDestinationView(viewModel: viewModel)
        }
    }

    @ViewBuilder
    private var detailBackdrop: some View {
        if let weather = viewModel.currentWeather {
            WeatherBackdropView(weather: weather)
        } else {
            suspendedBackdrop
        }
    }

    private var suspendedBackdrop: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.16, blue: 0.30),
                Color(red: 0.04, green: 0.06, blue: 0.12)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct OverviewDestinationView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @EnvironmentObject private var shellState: AppShellState
    @State private var expandedAlertKeys: Set<String> = []
    private let alertsSectionID = "overview-alerts-section"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                if let weather = viewModel.currentWeather {
                    OverviewForecastDashboard(
                        weather: weather,
                        locationName: viewModel.locationName,
                        isCurrentLocation: viewModel.currentLocationIndex == nil,
                        dailyForecast: viewModel.dailyForecast.first,
                        dailyForecasts: viewModel.dailyForecast,
                        alerts: viewModel.weatherAlerts,
                        locationTimeZone: viewModel.locationTimeZone,
                        airQuality: viewModel.airQuality,
                        hourlyForecast: viewModel.hourlyForecast,
                        minuteForecast: viewModel.minuteForecast,
                        aiSummaryStatus: viewModel.aiSummaryStatus,
                        aiSummaryShort: viewModel.aiSummaryShort,
                        aiSummaryLong: viewModel.aiSummaryLong,
                        lastUpdated: viewModel.lastUpdated,
                        expandedAlertKeys: expandedAlertKeys,
                        toggleAlertExpansion: toggleAlertExpansion,
                        alertsSectionID: alertsSectionID
                    )
                } else {
                    DetailEmptyState(
                        title: viewModel.loadingStatusMessage == nil ? "No active forecast" : "Loading forecast",
                        message: viewModel.loadingStatusMessage ?? viewModel.errorMessage ?? "Choose a saved location or use your current location to load the full forecast.",
                        actionTitle: viewModel.shouldOfferLocationSettingsShortcut ? "Open Location Settings" : nil,
                        action: viewModel.shouldOfferLocationSettingsShortcut ? {
                            viewModel.openLocationServicesSettings()
                        } : nil
                    )
                }
            }
            .scrollContentBackground(.hidden)
            .onAppear {
                syncExpandedAlertKeys()
                handlePendingOverviewAlertRequest(using: proxy)
            }
            .onChange(of: alertNavigationToken) { _, _ in
                syncExpandedAlertKeys()
                handlePendingOverviewAlertRequest(using: proxy)
            }
            .onChange(of: shellState.pendingOverviewAlertRequest) { _, _ in
                handlePendingOverviewAlertRequest(using: proxy)
            }
        }
    }

    private var alertTargets: [WeatherAlertNavigationTarget] {
        Array(viewModel.weatherAlerts.enumerated()).map { index, alert in
            alert.navigationTarget(at: index)
        }
    }

    private var alertNavigationToken: String {
        alertTargets.map(\.key).joined(separator: "|")
    }

    private func toggleAlertExpansion(_ alertKey: String) {
        withAnimation(.smooth(duration: 0.35, extraBounce: 0)) {
            if expandedAlertKeys.contains(alertKey) {
                expandedAlertKeys.remove(alertKey)
            } else {
                expandedAlertKeys.insert(alertKey)
            }
        }
    }

    private func syncExpandedAlertKeys() {
        let validKeys = Set(alertTargets.map(\.key))
        expandedAlertKeys = expandedAlertKeys.intersection(validKeys)
    }

    private func handlePendingOverviewAlertRequest(using proxy: ScrollViewProxy) {
        guard let request = shellState.pendingOverviewAlertRequest else { return }

        let matchedTarget = alertTargets.first(where: { $0.key == request.alertKey })
            ?? alertTargets.first(where: { $0.index == request.alertIndex })

        guard let matchedTarget else {
            shellState.consumePendingOverviewAlertRequest(request)
            return
        }

        if !expandedAlertKeys.contains(matchedTarget.key) {
            expandedAlertKeys.insert(matchedTarget.key)
        }

        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.28)) {
                proxy.scrollTo(alertsSectionID, anchor: .top)
                proxy.scrollTo(matchedTarget.key, anchor: .top)
            }
        }

        shellState.consumePendingOverviewAlertRequest(request)
    }
}

private struct WeatherMapDestinationView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @EnvironmentObject private var shellState: AppShellState
    @AppStorage("useCelsius") private var useCelsius: Bool = false

    var body: some View {
        Group {
            if viewModel.currentWeather != nil || viewModel.lastLocation != nil {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        mapHeader

                        WeatherMapView(
                            location: viewModel.lastLocation,
                            viewModel: viewModel,
                            presentationStyle: .destination
                        )

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 18) {
                                focusCard
                                conditionsCard
                                actionsCard
                            }

                            VStack(spacing: 18) {
                                focusCard
                                conditionsCard
                                actionsCard
                            }
                        }
                    }
                    .padding(24)
                }
            } else {
                DetailEmptyState(
                    title: "Map unavailable",
                    message: "Load a location first to center the weather map."
                )
            }
        }
    }

    private var locationTitle: String {
        viewModel.locationName ?? "Current Location"
    }

    private var mapHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weather Map", systemImage: "map.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text("Explore overlays, radar, and conditions around \(locationTitle).")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))

            HStack(spacing: 10) {
                DestinationTag(text: locationTitle, systemImage: viewModel.currentLocationIndex == nil ? "location.fill" : "mappin.and.ellipse")

                if !viewModel.weatherAlerts.isEmpty {
                    DestinationTag(
                        text: "\(viewModel.weatherAlerts.count) active alert\(viewModel.weatherAlerts.count == 1 ? "" : "s")",
                        systemImage: "bell.badge.fill",
                        tint: Color.yellow.opacity(0.9)
                    )
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weatherShellPanel(cornerRadius: WeatherDesignTokens.shellCorner)
    }

    private var focusCard: some View {
        DestinationPanelCard(title: "Map Focus", systemImage: "scope") {
            if let location = viewModel.lastLocation {
                DestinationMetricRow(
                    label: "Latitude",
                    value: String(format: "%.4f°", location.coordinate.latitude)
                )
                DestinationMetricRow(
                    label: "Longitude",
                    value: String(format: "%.4f°", location.coordinate.longitude)
                )
            } else {
                Text("Load a place to center the map and show geographic context.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }

            if let timeZone = viewModel.locationTimeZone {
                DestinationMetricRow(label: "Time Zone", value: timeZone.identifier)
            }

            DestinationMetricRow(
                label: "Source",
                value: viewModel.currentLocationIndex == nil ? "Current location" : "Saved location"
            )
        }
        .contextMenu {
            if viewModel.lastLocation != nil {
                Button {
                    openInMaps()
                } label: {
                    Label("Open In Maps", systemImage: "map")
                }
            }

            Button {
                viewModel.fetchCurrentLocationWeather(userInitiated: true)
            } label: {
                Label("Use Current Location", systemImage: "location.fill")
            }
        }
    }

    private var conditionsCard: some View {
        DestinationPanelCard(title: "Current Conditions", systemImage: "cloud.sun.fill") {
            if let weather = viewModel.currentWeather {
                DestinationMetricRow(
                    label: "Temperature",
                    value: "\(formattedTemperature(weather.temperature))°"
                )
                DestinationMetricRow(
                    label: "Condition",
                    value: weather.condition.description
                )
                DestinationMetricRow(
                    label: "Wind",
                    value: formattedWindSpeed(weather.wind.speed)
                )
                DestinationMetricRow(
                    label: "Humidity",
                    value: "\(Int((weather.humidity * 100).rounded()))%"
                )
            } else {
                Text("Current weather will appear here once this location has loaded.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
            }
        }
    }

    private var actionsCard: some View {
        DestinationPanelCard(title: "Quick Actions", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    viewModel.fetchCurrentLocationWeather(userInitiated: true)
                } label: {
                    Label("Use Current Location", systemImage: "location.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WeatherActionButtonStyle())

                if viewModel.lastLocation != nil {
                    Button {
                        openInMaps()
                    } label: {
                        Label("Open In Maps", systemImage: "map")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WeatherActionButtonStyle())
                }

                Button {
                    shellState.open(viewModel.weatherAlerts.isEmpty ? .overview : .alerts)
                } label: {
                    Label(
                        viewModel.weatherAlerts.isEmpty ? "Back To Overview" : "Show Alerts",
                        systemImage: viewModel.weatherAlerts.isEmpty ? "sun.max.fill" : "bell.badge.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WeatherActionButtonStyle(prominent: !viewModel.weatherAlerts.isEmpty))
            }
        }
    }

    private func formattedTemperature(_ temperature: Measurement<UnitTemperature>) -> Int {
        let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
        return Int(temperature.converted(to: unit).value.rounded())
    }

    private func formattedWindSpeed(_ speed: Measurement<UnitSpeed>) -> String {
        let unit: UnitSpeed = useCelsius ? .kilometersPerHour : .milesPerHour
        let value = speed.converted(to: unit).value
        return "\(String(format: "%.1f", value)) \(useCelsius ? "km/h" : "mph")"
    }

    private func openInMaps() {
        guard let location = viewModel.lastLocation else { return }

        let item = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        item.name = locationTitle
        item.openInMaps()
    }
}

private struct AlertsDestinationView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @State private var selectedAlertDescriptorID: String?

    var body: some View {
        Group {
            if viewModel.currentWeather == nil && viewModel.lastLocation == nil && viewModel.weatherAlerts.isEmpty {
                DetailEmptyState(
                    title: "Alerts unavailable",
                    message: "Load a location first to check for severe weather alerts."
                )
            } else if alertDescriptors.isEmpty {
                DetailEmptyState(
                    title: "No active alerts",
                    message: "Severe weather alerts will appear here when WeatherKit provides them for the current location."
                )
            } else {
                GeometryReader { proxy in
                    if proxy.size.width >= 980 {
                        VStack(alignment: .leading, spacing: 20) {
                            alertsHeader
                                .padding(.horizontal, 24)
                                .padding(.top, 24)

                            HStack(alignment: .top, spacing: 18) {
                                alertsListPanel
                                    .frame(width: 300)
                                    .frame(maxHeight: .infinity, alignment: .top)

                                alertDetailPanel
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 18) {
                                alertsHeader
                                alertsListPanel
                                alertDetailPanel
                            }
                            .padding(24)
                        }
                    }
                }
            }
        }
        .onAppear {
            syncSelectedAlert()
        }
        .onChange(of: alertSelectionToken) { _, _ in
            syncSelectedAlert()
        }
    }

    private var alertDescriptors: [AlertDescriptor] {
        let total = viewModel.weatherAlerts.count

        return Array(viewModel.weatherAlerts.enumerated()).map { index, alert in
            let alertTarget = alert.navigationTarget(at: index)
            return AlertDescriptor(
                id: alertTarget.key,
                alertID: alertTarget.alertID,
                title: alert.summary,
                url: alert.detailsURL,
                index: index,
                total: total
            )
        }
    }

    private var selectedAlertDescriptor: AlertDescriptor? {
        if let selectedAlertDescriptorID,
           let match = alertDescriptors.first(where: { $0.id == selectedAlertDescriptorID }) {
            return match
        }

        return alertDescriptors.first
    }

    private var alertSelectionToken: String {
        alertDescriptors.map(\.id).joined(separator: "|")
    }

    private var alertsHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active Alerts", systemImage: "bell.badge.fill")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text("Review severe weather bulletins for \(viewModel.locationName ?? "this location") without expanding a long stack of cards.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))

            HStack(spacing: 10) {
                DestinationTag(
                    text: "\(alertDescriptors.count) alert\(alertDescriptors.count == 1 ? "" : "s")",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: Color.yellow.opacity(0.92)
                )

                if let locationName = viewModel.locationName {
                    DestinationTag(text: locationName, systemImage: "location.fill")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weatherShellPanel(cornerRadius: WeatherDesignTokens.shellCorner)
    }

    private var alertsListPanel: some View {
        DestinationPanelCard(title: "All Alerts", systemImage: "list.bullet.rectangle.portrait") {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(alertDescriptors) { descriptor in
                        Button {
                            selectedAlertDescriptorID = descriptor.id
                        } label: {
                            AlertSelectionRow(
                                descriptor: descriptor,
                                isSelected: selectedAlertDescriptor?.id == descriptor.id
                            )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                openAlertSource(descriptor.url)
                            } label: {
                                Label("Open Source In Browser", systemImage: "safari")
                            }

                            Button {
                                copyAlertLink(descriptor.url)
                            } label: {
                                Label("Copy Alert Link", systemImage: "link")
                            }
                        }
                    }
                }
            }
        }
    }

    private var alertDetailPanel: some View {
        DestinationPanelCard(title: "Alert Details", systemImage: "doc.text.magnifyingglass") {
            if let descriptor = selectedAlertDescriptor {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(descriptor.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text("Alert \(descriptor.index + 1) of \(descriptor.total)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.60))
                        }

                        Spacer()

                        if descriptor.total > 1 {
                            HStack(spacing: 8) {
                                Button {
                                    selectRelativeAlert(-1)
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                                .buttonStyle(WeatherActionButtonStyle())
                                .disabled(descriptor.index == 0)

                                Button {
                                    selectRelativeAlert(1)
                                } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .buttonStyle(WeatherActionButtonStyle())
                                .disabled(descriptor.index == descriptor.total - 1)
                            }
                        }

                        Button {
                            openAlertSource(descriptor.url)
                        } label: {
                            Label("Open Source", systemImage: "safari")
                        }
                        .buttonStyle(WeatherActionButtonStyle(prominent: true))
                    }

                    AlertDetailView(
                        title: descriptor.title,
                        url: descriptor.url,
                        alertIdentifier: descriptor.title,
                        alertID: descriptor.alertID,
                        alertIndex: descriptor.index,
                        totalAlerts: descriptor.total
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .contextMenu {
            if let descriptor = selectedAlertDescriptor {
                Button {
                    openAlertSource(descriptor.url)
                } label: {
                    Label("Open Source In Browser", systemImage: "safari")
                }

                Button {
                    copyAlertLink(descriptor.url)
                } label: {
                    Label("Copy Alert Link", systemImage: "link")
                }
            }
        }
    }

    private func syncSelectedAlert() {
        if let selectedAlertDescriptorID,
           alertDescriptors.contains(where: { $0.id == selectedAlertDescriptorID }) {
            return
        }

        selectedAlertDescriptorID = alertDescriptors.first?.id
    }

    private func selectRelativeAlert(_ delta: Int) {
        guard let selected = selectedAlertDescriptor else { return }
        let nextIndex = selected.index + delta
        guard alertDescriptors.indices.contains(nextIndex) else { return }
        selectedAlertDescriptorID = alertDescriptors[nextIndex].id
    }

    private func openAlertSource(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func copyAlertLink(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
    }
}

private struct DetailEmptyState: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.82))
            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(WeatherDesignTokens.accent.opacity(0.96))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

private struct DestinationPanelCard<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .weatherShellPanel(cornerRadius: WeatherDesignTokens.cardCorner)
    }
}

private struct DestinationMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .textSelection(.enabled)
        }
    }
}

private struct DestinationTag: View {
    let text: String
    let systemImage: String
    var tint: Color = Color.white.opacity(0.86)

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
}

private struct AlertDescriptor: Identifiable {
    let id: String
    let alertID: String
    let title: String
    let url: URL
    let index: Int
    let total: Int
}

private struct AlertSelectionRow: View {
    let descriptor: AlertDescriptor
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(isSelected ? 0.24 : 0.18))
                    .frame(width: 32, height: 32)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.yellow.opacity(0.95))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("Alert \(descriptor.index + 1) of \(descriptor.total)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isSelected ? 0.76 : 0.42))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(isSelected ? 0.18 : 0.08), lineWidth: 1)
        )
    }
}

private struct SidebarPanelScrollEffectModifier: ViewModifier {
    let isEnabled: Bool
    private let maxOffset = WeatherMotionTokens.maxScrollLinkedOffset
    private let minimumScale = WeatherMotionTokens.minimumScrollScale
    private let minimumOpacity = WeatherMotionTokens.minimumScrollOpacity

    func body(content: Content) -> some View {
        content.visualEffect { content, geometry in
            let frame = geometry.frame(in: .scrollView)
            let distance = isEnabled ? min(abs(frame.minY) / 360, 1) : 0
            let yOffset = frame.minY >= 0
                ? -distance * (maxOffset * 0.35)
                : distance * (maxOffset * 0.65)

            return content
                .offset(y: yOffset)
                .scaleEffect(1 - (distance * (1 - minimumScale)))
                .opacity(1 - (Double(distance) * (1 - minimumOpacity)))
        }
    }
}

private struct SidebarRowScrollEffectModifier: ViewModifier {
    let isSelected: Bool
    let isEnabled: Bool
    private let maxOffset = WeatherMotionTokens.maxScrollLinkedOffset
    private let minimumScale = WeatherMotionTokens.minimumScrollScale
    private let minimumOpacity = WeatherMotionTokens.minimumScrollOpacity

    func body(content: Content) -> some View {
        content.scrollTransition(axis: .vertical) { content, phase in
            let shouldTransform = isEnabled && !isSelected && !phase.isIdentity

            return content
                .scaleEffect(shouldTransform ? minimumScale : 1.0)
                .opacity(shouldTransform ? minimumOpacity : 1.0)
                .offset(y: shouldTransform ? maxOffset * 0.2 : 0)
        }
    }
}

private struct WindowToolbarBackdrop: View {
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 1)
            }
            .mask(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.92),
                        Color.black.opacity(0.82),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: 96)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

private struct MainWindowVisibilityObserver: NSViewRepresentable {
    @EnvironmentObject private var appVisibility: AppVisibility
    @EnvironmentObject private var shellState: AppShellState

    func makeCoordinator() -> Coordinator {
        Coordinator(appVisibility: appVisibility, shellState: shellState)
    }

    func makeNSView(context: Context) -> WindowObservationView {
        let view = WindowObservationView()
        view.onWindowChange = { window in
            context.coordinator.observe(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowObservationView, context: Context) {
        context.coordinator.appVisibility = appVisibility
        context.coordinator.shellState = shellState
        if let window = nsView.window {
            context.coordinator.observe(window: window)
        }
    }

    final class Coordinator: NSObject {
        weak var appVisibility: AppVisibility?
        weak var shellState: AppShellState?
        private weak var observedWindow: NSWindow?
        private var observers: [NSObjectProtocol] = []

        init(appVisibility: AppVisibility, shellState: AppShellState) {
            self.appVisibility = appVisibility
            self.shellState = shellState
        }

        deinit {
            removeObservers()
        }

        func observe(window: NSWindow?) {
            guard observedWindow !== window else {
                syncVisibility(for: window)
                return
            }

            removeObservers()
            observedWindow = window
            shellState?.registerMainWindow(window)

            guard let window else {
                syncVisibility(for: nil)
                return
            }

            configure(window: window)

            let center = NotificationCenter.default
            let notifications: [Notification.Name] = [
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification,
                NSWindow.didMiniaturizeNotification,
                NSWindow.didDeminiaturizeNotification,
                NSWindow.didMoveNotification,
                NSWindow.didEndLiveResizeNotification,
                NSWindow.didChangeOcclusionStateNotification
            ]

            observers = notifications.map { name in
                center.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    self?.syncVisibility(for: window)
                }
            }

            observers.append(
                center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
                    self?.observe(window: nil)
                }
            )

            syncVisibility(for: window)
        }

        private func configure(window: NSWindow) {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.toolbarStyle = .unified
            window.titlebarSeparatorStyle = .none
            window.isMovableByWindowBackground = true
            window.isOpaque = true
            window.backgroundColor = NSColor(
                calibratedRed: 0.05,
                green: 0.08,
                blue: 0.14,
                alpha: 1.0
            )
        }

        private func syncVisibility(for window: NSWindow?) {
            let isVisible = {
                guard let window else { return false }
                return window.isVisible
                    && !window.isMiniaturized
                    && window.occlusionState.contains(.visible)
            }()

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.appVisibility?.isMainWindowVisible = isVisible
                self.shellState?.registerMainWindow(window)
            }
        }

        private func removeObservers() {
            let center = NotificationCenter.default
            observers.forEach(center.removeObserver)
            observers.removeAll()
        }
    }
}

private final class WindowObservationView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
