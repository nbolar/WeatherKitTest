import Foundation
import SwiftUI
import Combine
import CoreLocation
import MapKit
import WeatherKit
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Weather View Model

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
    @Published var airQuality: AirQualitySnapshot?
    @Published var airQualityHourly: [AirQualityHourPoint] = []
    @Published var weatherAttribution: WeatherAttribution?
    @Published var aiSummaryShort: String? = nil
    @Published var aiSummaryLong: String? = nil
    @Published var aiSummaryStatus: String? = nil
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
    private var activeLocationKey: String?
    private var fetchSequence: Int = 0

    private var locationRetryCount: Int = 0
    private let maxLocationRetries: Int = 3
    
    private let weatherService = WeatherService.shared
    private let geocoder = CLGeocoder()
    private let locationManager = CLLocationManager()
    private let isoFormatter = ISO8601DateFormatter()
    private let openMeteoFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter
    }()
    
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
        
        Task {
            await loadWeatherAttribution()
        }
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
    
    // MARK: - Location Fetching
    
    func fetchCurrentLocationWeather() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
            self.currentLocationIndex = nil  // Reset to indicate we're viewing current location, not a saved one
        }

        guard CLLocationManager.locationServicesEnabled() else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Location Services are turned off system-wide. Enable them in System Settings > Privacy & Security > Location Services."
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
    
    // MARK: - Refresh Timer
    
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
                    async let weather = weatherService.weather(for: location.clLocation)
                    async let daily = weatherService.weather(for: location.clLocation, including: .daily)
                    let weatherResult = try await weather
                    let dailyResult = try await daily
                    let cachedWeather = CachedLocationWeather(
                        locationId: location.id,
                        weather: weatherResult.currentWeather,
                        daily: dailyResult.first
                    )
                    
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
                self.errorMessage = "Still couldn't determine your location. Try moving outdoors, turning on Wi‑Fi, or checking Location Services."
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

    func moveSavedLocation(from source: Int, to destination: Int) {
        guard source != destination,
              source >= 0, source < savedLocations.count,
              destination >= 0, destination <= savedLocations.count else { return }
        var locations = savedLocations
        let item = locations.remove(at: source)
        let adjustedDestination = destination > source ? destination - 1 : destination
        locations.insert(item, at: adjustedDestination)
        if let currentIndex = currentLocationIndex {
            let currentLocation = savedLocations[currentIndex]
            if let newIndex = locations.firstIndex(of: currentLocation) {
                currentLocationIndex = newIndex
            }
        }
        savedLocations = locations
        saveSavedLocations()
    }
    
    func selectLocation(at index: Int) {
        guard index < savedLocations.count else { return }
        currentLocationIndex = index
        let location = savedLocations[index]
        locationName = location.name
        fetchWeather(for: location.clLocation)
    }
    
    // MARK: - Weather Fetching
    
    private func fetchWeather(for location: CLLocation) {
        Task { [weak self] in
            guard let self else { return }
            await self.fetchWeatherTask(for: location)
        }
    }

    private func fetchWeatherTask(for location: CLLocation) async {
        self.lastLocation = location
            let locationKey = "\(location.coordinate.latitude),\(location.coordinate.longitude)"
            fetchSequence += 1
            let requestSequence = fetchSequence
            activeLocationKey = locationKey
            DispatchQueue.main.async {
                self.aiSummaryShort = nil
                self.aiSummaryLong = nil
                self.aiSummaryStatus = "Awaiting data…"
            }
            aiSummaryTask?.cancel()
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
                async let airQualityResult = fetchAirQuality(for: location)
                let weather = try await weatherService.weather(for: location)
                let hourly = try await weatherService.weather(for: location, including: .hourly)
                let daily = try await weatherService.weather(for: location, including: .daily)
                let minute = try? await weatherService.weather(for: location, including: .minute)
                let alerts: [WeatherAlert]? = try? await weatherService.weather(for: location, including: .alerts)
                let airQualityValue = await airQualityResult
                
                let alertArray: [WeatherAlert] = alerts ?? []
                
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.fetchSequence == requestSequence, self.activeLocationKey == locationKey else {
                        return
                    }
                    self.currentWeather = weather.currentWeather
                    self.hourlyForecast = Array(hourly)
                    self.dailyForecast = Array(daily)
                    self.minuteForecast = minute
                    self.weatherAlerts = alertArray
                    self.airQuality = airQualityValue.current
                    self.airQualityHourly = airQualityValue.hourly
                    self.isLoading = false
                    self.errorMessage = nil
                    self.lastUpdated = Date()
                    self.onWeatherUpdate?(weather.currentWeather)
                    
                    // Cache weather data for this location if it's a saved location
                    if let currentIndex = self.currentLocationIndex, currentIndex < self.savedLocations.count {
                        let savedLocation = self.savedLocations[currentIndex]
                        let cachedWeather = CachedLocationWeather(
                            locationId: savedLocation.id,
                            weather: weather.currentWeather,
                            daily: daily.first
                        )
                        self.locationWeatherCache[savedLocation.id] = cachedWeather
                        self.saveWeatherCache()
                    }

                    self.generateAISummaryIfAvailable(locationKey: locationKey)
                    self.scheduleNotificationsIfNeeded(
                        locationKey: locationKey,
                        alerts: alertArray,
                        minuteForecast: minute
                    )
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.fetchSequence == requestSequence, self.activeLocationKey == locationKey else {
                        return
                    }
                    self.isLoading = false
                    self.errorMessage = "Failed to fetch weather: \(error.localizedDescription)"
                }
            }
    }

    private func scheduleNotificationsIfNeeded(
        locationKey: String,
        alerts: [WeatherAlert],
        minuteForecast: Forecast<MinuteWeather>?
    ) {
        guard activeLocationKey == locationKey else { return }
        guard currentLocationIndex == nil else { return }
        Task {
            await WeatherNotificationManager.shared.handleCurrentLocationNotifications(
                locationName: locationName,
                currentWeather: currentWeather,
                alerts: alerts,
                minuteForecast: minuteForecast
            )
        }
    }

    // MARK: - Apple Foundation Models summary
    
    private var lastSummaryKey: String?
    private var aiSummaryTask: Task<Void, Never>?
    
    private func generateAISummaryIfAvailable(locationKey: String) {
#if canImport(FoundationModels)
        guard activeLocationKey == locationKey else {
            DispatchQueue.main.async {
                self.aiSummaryStatus = "Waiting for current location…"
            }
            return
        }
        guard #available(macOS 26.0, *) else {
            DispatchQueue.main.async {
                self.aiSummaryStatus = "Apple Intelligence unavailable on this OS."
            }
            return
        }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            DispatchQueue.main.async {
                switch reason {
                case .deviceNotEligible:
                    self.aiSummaryStatus = "Apple Intelligence unavailable on this device."
                case .appleIntelligenceNotEnabled:
                    self.aiSummaryStatus = "Apple Intelligence is turned off in System Settings."
                case .modelNotReady:
                    self.aiSummaryStatus = "Apple Intelligence is still preparing. Try again later."
                @unknown default:
                    self.aiSummaryStatus = "Apple Intelligence unavailable right now."
                }
            }
            return
        }
        guard model.supportsLocale(Locale.current) else {
            DispatchQueue.main.async {
                let preferred = Locale.preferredLanguages.joined(separator: ", ")
                let current = Locale.current.identifier
                self.aiSummaryStatus = "Apple Intelligence doesn't support this locale. Current: \(current). Preferred: \(preferred)."
            }
            return
        }
        guard let currentWeather, let daily = dailyForecast.first else {
            DispatchQueue.main.async {
                self.aiSummaryStatus = "Waiting for weather data…"
            }
            return
        }
        guard !hourlyForecast.isEmpty else {
            DispatchQueue.main.async {
                self.aiSummaryStatus = "Waiting for hourly forecast…"
            }
            return
        }
        let hourly = hourlyForecast

        let key = "\(locationKey)-\(currentWeather.date.timeIntervalSince1970)-\(daily.highTemperature.value)-\(daily.lowTemperature.value)-\(currentWeather.condition.rawValue)-\(hourly.first?.date.timeIntervalSince1970 ?? 0)"
        if lastSummaryKey == key, aiSummaryShort != nil || aiSummaryLong != nil {
            DispatchQueue.main.async {
                self.aiSummaryStatus = "AI summary up to date."
            }
            return
        }
        lastSummaryKey = key

        DispatchQueue.main.async {
            self.aiSummaryStatus = ""
        }

        aiSummaryTask?.cancel()
        aiSummaryTask = Task.detached(priority: .userInitiated) { [hourly, currentWeather, daily, locationKey] in
            do {
                let session = LanguageModelSession(instructions: """
                You are a concise weather assistant. Respond with two lines only.
                Line 1: a short, friendly summary (max 160 characters).
                Line 2: a casual 4–5 sentence detailed summary with a bit more detail.
                Avoid emojis and markdown.
                Use whole numbers only (no decimals) for all numeric values.
                Respond in English.
                """)

                let useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
                let prompt = Self.summaryPrompt(
                    current: currentWeather,
                    daily: daily,
                    hourly: hourly,
                    useCelsius: useCelsius
                )

                let response = try await session.respond(to: prompt)
                let text = Self.normalizedWholeNumberText(response.content)
                let lines = text
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .map { Self.stripLinePrefix($0) }
                    .filter { !$0.isEmpty }

                let shortLine = lines.first
                let longLine: String?
                if lines.count >= 2 {
                    longLine = lines.dropFirst().joined(separator: " ")
                } else {
                    longLine = shortLine
                }

                DispatchQueue.main.async {
                    if self.lastSummaryKey == key, self.activeLocationKey == locationKey {
                        self.aiSummaryShort = shortLine
                        if let longLine, !longLine.isEmpty {
                            self.aiSummaryLong = longLine
                        } else {
                            self.aiSummaryLong = nil
                        }
                        self.aiSummaryStatus = "AI summary ready."
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if self.lastSummaryKey == key, self.activeLocationKey == locationKey {
                        self.aiSummaryShort = nil
                        self.aiSummaryLong = nil
                        self.lastSummaryKey = nil
                        self.aiSummaryStatus = "AI summary failed."
                    }
                }
            }
        }
#else
        DispatchQueue.main.async {
            self.aiSummaryStatus = "Apple Intelligence not available in this build."
        }
#endif
    }
    
    nonisolated private static func summaryPrompt(
        current: CurrentWeather,
        daily: DayWeather,
        hourly: [HourWeather],
        useCelsius: Bool
    ) -> String {
        let nextHours = hourly.prefix(24)
        let maxPrecip = nextHours.map(\.precipitationChance).max() ?? 0
        let maxWind = nextHours.map { $0.wind.speed }.max(by: { $0.value < $1.value }) ?? current.wind.speed
        let minTemp = nextHours.map { $0.temperature }.min(by: { $0.value < $1.value }) ?? current.temperature
        let maxTemp = nextHours.map { $0.temperature }.max(by: { $0.value < $1.value }) ?? current.temperature
        
        return """
        Today's data:
        - Current: \(conditionLabel(current.condition)), \(tempString(current.temperature, useCelsius: useCelsius)).
        - Daily high/low: \(tempString(daily.highTemperature, useCelsius: useCelsius)) / \(tempString(daily.lowTemperature, useCelsius: useCelsius)).
        - 24h temp range (hourly): \(tempString(minTemp, useCelsius: useCelsius)) to \(tempString(maxTemp, useCelsius: useCelsius)).
        - Peak precip chance next 24h: \(Int(maxPrecip * 100))%.
        - Peak wind speed next 24h: \(speedString(maxWind, useCelsius: useCelsius)).
        """
    }

    nonisolated private static func tempString(_ temp: Measurement<UnitTemperature>, useCelsius: Bool) -> String {
        let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
        let value = temp.converted(to: unit).value
        let rounded = Int(value.rounded())
        return "\(rounded)°\(useCelsius ? "C" : "F")"
    }

    nonisolated private static func speedString(_ speed: Measurement<UnitSpeed>, useCelsius: Bool) -> String {
        let unit: UnitSpeed = useCelsius ? .kilometersPerHour : .milesPerHour
        let value = speed.converted(to: unit).value
        let rounded = Int(value.rounded())
        return "\(rounded) \(useCelsius ? "km/h" : "mph")"
    }

    nonisolated private static func conditionLabel(_ condition: WeatherCondition) -> String {
        let raw = condition.rawValue.replacingOccurrences(of: "_", with: " ")
        let spaced = raw.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return spaced.lowercased()
    }

    nonisolated private static func normalizedWholeNumberText(_ text: String) -> String {
        let pattern = #"(-?\d+)\.(\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        var result = text
        let matches = regex.matches(in: result, options: [], range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let raw = String(result[range])
            guard let value = Double(raw) else { continue }
            let rounded = String(Int(value.rounded()))
            result.replaceSubrange(range, with: rounded)
        }
        return result
    }

    nonisolated private static func stripLinePrefix(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = ["Line 1:", "Line 2:", "Line 1 -", "Line 2 -", "Line1:", "Line2:"]
        for prefix in prefixes {
            if trimmed.lowercased().hasPrefix(prefix.lowercased()) {
                let start = trimmed.index(trimmed.startIndex, offsetBy: prefix.count)
                return trimmed[start...].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return trimmed
    }

    private func loadWeatherAttribution() async {
        do {
            let attribution = try await weatherService.attribution
            DispatchQueue.main.async {
                self.weatherAttribution = attribution
            }
        } catch {
            DispatchQueue.main.async {
                self.weatherAttribution = nil
            }
        }
    }

    // MARK: - Air Quality (Open-Meteo)
    
    private struct OpenMeteoAirQualityResponse: Decodable {
        let current: Current?
        let currentUnits: Units?
        let hourlyUnits: Units?
        let hourly: Hourly?
        
        private enum CodingKeys: String, CodingKey {
            case current
            case currentUnits = "current_units"
            case hourlyUnits = "hourly_units"
            case hourly
        }
        
        struct Current: Decodable {
            let time: String
            let usAQI: Double?
            let europeanAQI: Double?
            let pm25: Double?
            let pm10: Double?
            let ozone: Double?
            let nitrogenDioxide: Double?
            let sulphurDioxide: Double?
            let carbonMonoxide: Double?
            let uvIndex: Double?
            let uvIndexClearSky: Double?
            let aerosolOpticalDepth: Double?
            
            private enum CodingKeys: String, CodingKey {
                case time
                case usAQI = "us_aqi"
                case europeanAQI = "european_aqi"
                case pm25 = "pm2_5"
                case pm10 = "pm10"
                case ozone = "ozone"
                case nitrogenDioxide = "nitrogen_dioxide"
                case sulphurDioxide = "sulphur_dioxide"
                case carbonMonoxide = "carbon_monoxide"
                case uvIndex = "uv_index"
                case uvIndexClearSky = "uv_index_clear_sky"
                case aerosolOpticalDepth = "aerosol_optical_depth"
            }
        }
        
        struct Units: Decodable {
            let usAQI: String?
            let europeanAQI: String?
            let pm25: String?
            let pm10: String?
            let ozone: String?
            let nitrogenDioxide: String?
            let sulphurDioxide: String?
            let carbonMonoxide: String?
            let uvIndex: String?
            let uvIndexClearSky: String?
            let aerosolOpticalDepth: String?
            
            private enum CodingKeys: String, CodingKey {
                case usAQI = "us_aqi"
                case europeanAQI = "european_aqi"
                case pm25 = "pm2_5"
                case pm10 = "pm10"
                case ozone = "ozone"
                case nitrogenDioxide = "nitrogen_dioxide"
                case sulphurDioxide = "sulphur_dioxide"
                case carbonMonoxide = "carbon_monoxide"
                case uvIndex = "uv_index"
                case uvIndexClearSky = "uv_index_clear_sky"
                case aerosolOpticalDepth = "aerosol_optical_depth"
            }
        }
        
        struct Hourly: Decodable {
            let time: [String]
            let usAQI: [Double?]?
            let europeanAQI: [Double?]?
            let pm25: [Double?]?
            let pm10: [Double?]?
            let ozone: [Double?]?
            let nitrogenDioxide: [Double?]?
            let sulphurDioxide: [Double?]?
            let carbonMonoxide: [Double?]?
            let uvIndex: [Double?]?
            let uvIndexClearSky: [Double?]?
            let aerosolOpticalDepth: [Double?]?
            
            private enum CodingKeys: String, CodingKey {
                case time
                case usAQI = "us_aqi"
                case europeanAQI = "european_aqi"
                case pm25 = "pm2_5"
                case pm10 = "pm10"
                case ozone = "ozone"
                case nitrogenDioxide = "nitrogen_dioxide"
                case sulphurDioxide = "sulphur_dioxide"
                case carbonMonoxide = "carbon_monoxide"
                case uvIndex = "uv_index"
                case uvIndexClearSky = "uv_index_clear_sky"
                case aerosolOpticalDepth = "aerosol_optical_depth"
            }
        }
    }
    
    private struct AirQualityResult {
        let current: AirQualitySnapshot?
        let hourly: [AirQualityHourPoint]
    }
    
    private func fetchAirQuality(for location: CLLocation) async -> AirQualityResult {
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let urlString = """
        https://air-quality-api.open-meteo.com/v1/air-quality?latitude=\(lat)&longitude=\(lon)&current=us_aqi,european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide,uv_index,uv_index_clear_sky,aerosol_optical_depth&hourly=us_aqi,european_aqi,pm2_5,pm10,ozone,nitrogen_dioxide,sulphur_dioxide,carbon_monoxide,uv_index,uv_index_clear_sky,aerosol_optical_depth&timezone=auto
        """
        
        guard let url = URL(string: urlString) else {
            return AirQualityResult(current: nil, hourly: [])
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoAirQualityResponse.self, from: data)
            
            let unitsSource = decoded.currentUnits ?? decoded.hourlyUnits
            let units = AirQualityUnits(
                usAQI: unitsSource?.usAQI,
                europeanAQI: unitsSource?.europeanAQI,
                pm25: unitsSource?.pm25,
                pm10: unitsSource?.pm10,
                ozone: unitsSource?.ozone,
                nitrogenDioxide: unitsSource?.nitrogenDioxide,
                sulphurDioxide: unitsSource?.sulphurDioxide,
                carbonMonoxide: unitsSource?.carbonMonoxide,
                uvIndex: unitsSource?.uvIndex,
                uvIndexClearSky: unitsSource?.uvIndexClearSky,
                aerosolOpticalDepth: unitsSource?.aerosolOpticalDepth
            )
            
            var currentSnapshot: AirQualitySnapshot? = {
                guard let current = decoded.current,
                      let date = parseOpenMeteoDate(current.time) else {
                    return nil
                }
                var scale: AirQualityScale? = {
                    if current.usAQI != nil { return .us }
                    if current.europeanAQI != nil { return .eu }
                    return nil
                }()
                let computedUS = computeUSAQIFromPM25(current.pm25)
                if scale == nil, computedUS != nil {
                    scale = .us
                }
                return AirQualitySnapshot(
                    time: date,
                    usAQI: current.usAQI ?? computedUS,
                    europeanAQI: current.europeanAQI,
                    pm25: current.pm25,
                    pm10: current.pm10,
                    ozone: current.ozone,
                    nitrogenDioxide: current.nitrogenDioxide,
                    sulphurDioxide: current.sulphurDioxide,
                    carbonMonoxide: current.carbonMonoxide,
                    uvIndex: current.uvIndex,
                    uvIndexClearSky: current.uvIndexClearSky,
                    aerosolOpticalDepth: current.aerosolOpticalDepth,
                    units: units,
                    scale: scale
                )
            }()
            
            if let hourly = decoded.hourly,
               let date = hourly.time.first.flatMap(parseOpenMeteoDate) {
                let usValue = firstNonNil(hourly.usAQI)
                let euValue = firstNonNil(hourly.europeanAQI)
                let computedUS = computeUSAQIFromPM25(firstNonNil(hourly.pm25))
                let scale: AirQualityScale? = {
                    if usValue != nil { return .us }
                    if euValue != nil { return .eu }
                    if computedUS != nil { return .us }
                    return nil
                }()
                
                let merged = AirQualitySnapshot(
                    time: currentSnapshot?.time ?? date,
                    usAQI: currentSnapshot?.usAQI ?? usValue ?? computedUS,
                    europeanAQI: currentSnapshot?.europeanAQI ?? euValue,
                    pm25: currentSnapshot?.pm25 ?? firstNonNil(hourly.pm25),
                    pm10: currentSnapshot?.pm10 ?? firstNonNil(hourly.pm10),
                    ozone: currentSnapshot?.ozone ?? firstNonNil(hourly.ozone),
                    nitrogenDioxide: currentSnapshot?.nitrogenDioxide ?? firstNonNil(hourly.nitrogenDioxide),
                    sulphurDioxide: currentSnapshot?.sulphurDioxide ?? firstNonNil(hourly.sulphurDioxide),
                    carbonMonoxide: currentSnapshot?.carbonMonoxide ?? firstNonNil(hourly.carbonMonoxide),
                    uvIndex: currentSnapshot?.uvIndex ?? firstNonNil(hourly.uvIndex),
                    uvIndexClearSky: currentSnapshot?.uvIndexClearSky ?? firstNonNil(hourly.uvIndexClearSky),
                    aerosolOpticalDepth: currentSnapshot?.aerosolOpticalDepth ?? firstNonNil(hourly.aerosolOpticalDepth),
                    units: units,
                    scale: currentSnapshot?.scale ?? scale
                )
                
                if currentSnapshot == nil
                    || (currentSnapshot?.usAQI == nil && currentSnapshot?.europeanAQI == nil)
                    || currentSnapshot?.uvIndexClearSky == nil
                    || currentSnapshot?.aerosolOpticalDepth == nil
                    || currentSnapshot?.uvIndex == nil {
                    currentSnapshot = merged
                }
            }
            
            if currentSnapshot == nil {
                currentSnapshot = AirQualitySnapshot(
                    time: Date(),
                    usAQI: nil,
                    europeanAQI: nil,
                    pm25: nil,
                    pm10: nil,
                    ozone: nil,
                    nitrogenDioxide: nil,
                    sulphurDioxide: nil,
                    carbonMonoxide: nil,
                    uvIndex: nil,
                    uvIndexClearSky: nil,
                    aerosolOpticalDepth: nil,
                    units: AirQualityUnits(usAQI: "AQI"),
                    scale: nil
                )
            }
            
            let hourlyPoints: [AirQualityHourPoint] = {
                guard let hourly = decoded.hourly else {
                    return []
                }
                
                let useUS = (hourly.usAQI?.contains { $0 != nil } == true)
                let useEU = (hourly.europeanAQI?.contains { $0 != nil } == true)
                let values: [Double?]
                let scale: AirQualityScale
                if useUS {
                    values = hourly.usAQI ?? []
                    scale = .us
                } else if useEU {
                    values = hourly.europeanAQI ?? []
                    scale = .eu
                } else if let pm25 = hourly.pm25 {
                    values = pm25.map { computeUSAQIFromPM25($0) }
                    scale = .us
                } else {
                    return []
                }
                
                let count = min(hourly.time.count, values.count, 48)
                var result: [AirQualityHourPoint] = []
                result.reserveCapacity(count)
                
                for index in 0..<count {
                    if let date = parseOpenMeteoDate(hourly.time[index]),
                       let value = values[index] {
                        result.append(AirQualityHourPoint(date: date, usAQI: value, scale: scale))
                    }
                }
                return result
            }()
            
            return AirQualityResult(current: currentSnapshot, hourly: hourlyPoints)
        } catch {
            return AirQualityResult(
                current: AirQualitySnapshot(
                    time: Date(),
                    usAQI: nil,
                    europeanAQI: nil,
                    pm25: nil,
                    pm10: nil,
                    ozone: nil,
                    nitrogenDioxide: nil,
                    sulphurDioxide: nil,
                    carbonMonoxide: nil,
                    uvIndex: nil,
                    uvIndexClearSky: nil,
                    aerosolOpticalDepth: nil,
                    units: AirQualityUnits(usAQI: "AQI"),
                    scale: nil
                ),
                hourly: []
            )
        }
    }

    private func parseOpenMeteoDate(_ raw: String) -> Date? {
        if let date = isoFormatter.date(from: raw) {
            return date
        }
        return openMeteoFormatter.date(from: raw)
    }
    
    private func firstNonNil(_ values: [Double?]?) -> Double? {
        guard let values else { return nil }
        for value in values {
            if let value { return value }
        }
        return nil
    }

    private func computeUSAQIFromPM25(_ value: Double?) -> Double? {
        guard let value else { return nil }
        let c = max(0.0, value)
        let breakpoints: [(Double, Double, Double, Double)] = [
            (0.0, 12.0, 0.0, 50.0),
            (12.1, 35.4, 51.0, 100.0),
            (35.5, 55.4, 101.0, 150.0),
            (55.5, 150.4, 151.0, 200.0),
            (150.5, 250.4, 201.0, 300.0),
            (250.5, 350.4, 301.0, 400.0),
            (350.5, 500.4, 401.0, 500.0)
        ]
        
        for (clow, chigh, ilow, ihigh) in breakpoints {
            if c >= clow && c <= chigh {
                let aqi = (ihigh - ilow) / (chigh - clow) * (c - clow) + ilow
                return min(max(aqi, 0), 500)
            }
        }
        return 500
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

// MARK: - String Encoding Helper

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
