import SwiftUI
import AppKit
import MapKit
import WeatherKit

// MARK: - Content View

struct ContentView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var escapeMonitor: Any?
    @FocusState private var searchFocused: Bool
    @State private var hoveredSuggestionIndex: Int? = nil
    @State private var selectedSuggestionIndex: Int? = nil
    @State private var isLocationsExpanded: Bool = false
    @State private var isSearchExpanded: Bool = false
    @State private var isSpinnerAnimating: Bool = false
    
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
                    .environment(\.isDaylight, viewModel.currentWeather?.isDaylight)
                    .zIndex(3)
            }
        }
        .onChange(of: searchFocused) { oldValue, newValue in
            if !newValue {
                viewModel.dismissSuggestions()
            }
        }
        .onChange(of: viewModel.isShowingSuggestions) { oldValue, newValue in
            if newValue && !viewModel.searchSuggestions.isEmpty {
                selectedSuggestionIndex = 0
            } else {
                selectedSuggestionIndex = nil
            }
        }
        .onChange(of: viewModel.searchSuggestions) { oldList, newList in
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
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                isSearchExpanded = false
                            }
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
            
            savedLocationsDrawer
                .animation(nil, value: viewModel.currentLocationIndex)
            
            // Search bar now expands from the top-left icon.
            currentLocationButton
            tabPickerView
            scrollArea
                .frame(maxHeight: .infinity)
            lastUpdatedFooter
        }
        .padding(25)
        .background(Color.clear)
        .overlay {
            if viewModel.isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.7)
                        .frame(width: 64, height: 64)
                    ElegantSpinner()
                        .frame(width: 26, height: 26)
                }
                .transition(.opacity)
            }
        }
        .environment(\.isDaylight, viewModel.currentWeather?.isDaylight)
    }
    
    @ViewBuilder
    private var savedLocationsDrawer: some View {
        SavedLocationsDrawer(
            locations: $viewModel.savedLocations,
            selectedIndex: viewModel.currentLocationIndex,
            cachedWeather: viewModel.locationWeatherCache,
            isExpanded: $isLocationsExpanded,
            onSelect: { index in
                viewModel.selectLocation(at: index)
            },
            onMove: { fromIndex, toIndex in
                viewModel.moveSavedLocation(from: fromIndex, to: toIndex)
            },
            onRemove: { location in
                if let idx = viewModel.savedLocations.firstIndex(where: { $0.id == location.id }) {
                    viewModel.removeSavedLocation(at: IndexSet(integer: idx))
                }
            }
        )
    }

    
    @ViewBuilder
    private var settingsButtonRow: some View {
        HStack {
            searchButtonInline
            
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

    private var searchButtonInline: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .frame(maxWidth: isSearchExpanded ? .infinity : 28)
                    .frame(height: 28)

                if isSearchExpanded {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.7))
                        TextField("Search Locations", text: $viewModel.cityName)
                            .textFieldStyle(.plain)
                            .focused($searchFocused)
                            .foregroundColor(.white)
                            .onSubmit {
                                searchFocused = false
                                viewModel.searchCity()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    isSearchExpanded = false
                                }
                            }
                            .onChange(of: viewModel.cityName) { oldValue, newValue in
                                viewModel.updateSearchCompletions(for: newValue)
                            }
                        if isSearchExpanded,
                           searchFocused,
                           !viewModel.cityName.isEmpty,
                           viewModel.isShowingSuggestions,
                           viewModel.searchSuggestions.isEmpty {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                                .tint(.white.opacity(0.7))
                        }
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                isSearchExpanded = false
                                searchFocused = false
                                viewModel.dismissSuggestions()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                } else {
                    HStack(spacing: 0) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .frame(width: 28, height: 28)
                    .contentShape(Capsule())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isSearchExpanded = true
                            searchFocused = true
                        }
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isSearchExpanded)

            if isSearchExpanded, viewModel.isShowingSuggestions {
                suggestionsList
            }
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
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isSearchExpanded = false
                        }
                    }
                    .onChange(of: viewModel.cityName) { oldValue, newValue in
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
                        locationTimeZone: viewModel.locationTimeZone,
                        airQuality: viewModel.airQuality,
                        hourlyForecast: viewModel.hourlyForecast,
                        minuteForecast: viewModel.minuteForecast,
                        aiSummaryStatus: viewModel.aiSummaryStatus,
                        aiSummaryShort: viewModel.aiSummaryShort,
                        aiSummaryLong: viewModel.aiSummaryLong
                    )
                } else if selectedTab == 1 {
                    WeatherChartsView(
                        hourlyForecast: viewModel.hourlyForecast,
                        minuteForecast: viewModel.minuteForecast,
                        airQuality: viewModel.airQuality,
                        airQualityHourly: viewModel.airQualityHourly
                    )
                    .padding(.top, 16)
                } else if selectedTab == 2 {
                    HourlyForecastView(hourlyForecast: viewModel.hourlyForecast)
                } else if selectedTab == 3 {
                    DailyForecastView(
                        dailyForecast: viewModel.dailyForecast,
                        hourlyForecast: viewModel.hourlyForecast,
                        locationTimeZone: viewModel.locationTimeZone
                    )
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
        .scrollContentBackground(.hidden)
        .background(Color.clear)
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

// MARK: - Preview

#Preview {
    ContentView().mainContentView
}
