import SwiftUI
import Combine
import WeatherKit

private enum PopoverDateFormatterCache {
    private static var formatters: [String: DateFormatter] = [:]

    static func shortTimeFormatter(for timeZone: TimeZone) -> DateFormatter {
        formatter(key: "short:\(timeZone.identifier)") {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.timeZone = timeZone
            return formatter
        }
    }

    static func hourFormatter(for timeZone: TimeZone) -> DateFormatter {
        formatter(key: "hour:\(timeZone.identifier)") {
            let formatter = DateFormatter()
            formatter.dateFormat = "ha"
            formatter.amSymbol = "A"
            formatter.pmSymbol = "P"
            formatter.timeZone = timeZone
            return formatter
        }
    }

    static func dayFormatter(for timeZone: TimeZone) -> DateFormatter {
        formatter(key: "day:\(timeZone.identifier)") {
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            formatter.timeZone = timeZone
            return formatter
        }
    }

    private static func formatter(key: String, create: () -> DateFormatter) -> DateFormatter {
        if let formatter = formatters[key] {
            return formatter
        }

        let formatter = create()
        formatters[key] = formatter
        return formatter
    }
}

struct QuickStatusPopoverView: View {
    @ObservedObject var viewModel: WeatherViewModel
    @EnvironmentObject private var appVisibility: AppVisibility
    @EnvironmentObject private var shellState: AppShellState
    @Environment(\.openWindow) private var openWindow
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    @State private var currentTime = Date()
    private let currentTimeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            popoverBackdrop

            VStack(alignment: .leading, spacing: WeatherDesignTokens.popoverSectionSpacing) {
                PopoverCurrentConditionsCard(
                    locationName: activeLocationName,
                    localTimeText: activeLocalTimeText,
                    onCurrentLocation: {
                        if viewModel.shouldPromoteWindowForLocationAuthorization {
                            openFullForecast()
                        }
                        viewModel.fetchCurrentLocationWeather(userInitiated: true)
                    },
                    onRefresh: { viewModel.manualRefresh() },
                    openFullForecast: openFullForecast,
                    summary: displaySummary,
                    metricChips: displayMetricChips,
                    alertText: alertText,
                    onAlertTap: openOverviewAlert,
                    statusText: summaryStatusText,
                    isFetchingCurrentLocation: viewModel.isFetchingCurrentLocation,
                    isLoading: viewModel.isLoading && displaySummary == nil,
                    fallbackText: emptyStateText
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: WeatherDesignTokens.popoverSectionSpacing) {
                        PopoverForecastDeck(
                            minuteForecast: viewModel.minuteForecast,
                            hourlyForecast: Array(viewModel.hourlyForecast.prefix(8)),
                            dailyForecast: Array(viewModel.dailyForecast.prefix(3)),
                            timeZone: activeTimeZone,
                            useCelsius: useCelsius,
                            isLoading: viewModel.isLoading,
                            formatter: formatting
                        )

                        if !viewModel.savedLocations.isEmpty {
                            PopoverSavedLocationsRail(
                                locations: viewModel.savedLocations,
                                cache: viewModel.locationWeatherCache,
                                selectedLocationID: activeSavedLocation?.id,
                                currentTime: currentTime,
                                useCelsius: useCelsius,
                                onSelectLocation: { viewModel.selectLocation(id: $0) },
                                openFullForecast: openFullForecast
                    )
                        }
                    }
                    .padding(.bottom, 2)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if viewModel.shouldOfferLocationSettingsShortcut {
                    HStack {
                        Spacer()
                        Button("Open Location Settings") {
                            viewModel.openLocationServicesSettings()
                        }
                        .buttonStyle(PopoverTextButtonStyle(emphasized: true))
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding(WeatherDesignTokens.popoverContentPadding)
            .environment(\.isDaylight, displaySummary?.isDaylight)
        }
        .clipShape(RoundedRectangle(cornerRadius: WeatherDesignTokens.popoverCorner, style: .continuous))
        .frame(width: WeatherDesignTokens.popoverWidth, height: WeatherDesignTokens.popoverHeight)
        .id(appVisibility.popoverPresentationID)
        .onReceive(currentTimeTimer) { newTime in
            currentTime = newTime
        }
    }

    private var formatting: PopoverFormatting {
        PopoverFormatting(useCelsius: useCelsius)
    }

    private var activeSavedLocation: SavedLocation? {
        guard let index = viewModel.currentLocationIndex,
              viewModel.savedLocations.indices.contains(index) else {
            return nil
        }
        return viewModel.savedLocations[index]
    }

    private var activeCachedWeather: CachedLocationWeather? {
        if let cached = viewModel.activeLocationCachedWeather {
            return cached
        }
        guard let activeSavedLocation else { return nil }
        return viewModel.locationWeatherCache[activeSavedLocation.id]
    }

    private var activeLocationName: String {
        viewModel.locationName ?? activeSavedLocation?.name ?? "Weather"
    }

    private var activeTimeZone: TimeZone {
        viewModel.locationTimeZone
            ?? activeCachedWeather?.timeZone
            ?? activeSavedLocation?.timeZone
            ?? .current
    }

    private var activeLocalTimeText: String {
        "\(formattedTime(currentTime, in: activeTimeZone)) local"
    }

    private var displaySummary: PopoverWeatherSummary? {
        if let weather = viewModel.currentWeather {
            return PopoverWeatherSummary(
                temperatureText: formatting.temperatureText(weather.temperature),
                symbolName: weather.symbolName,
                conditionText: weather.condition.description,
                updatedText: updatedText(for: viewModel.lastUpdated ?? weather.date),
                isCached: false,
                isDaylight: weather.isDaylight
            )
        }

        guard let cached = activeCachedWeather else { return nil }
        return PopoverWeatherSummary(
            temperatureText: formatting.cachedTemperatureText(cached.temperature),
            symbolName: cached.symbolName,
            conditionText: cached.condition,
            updatedText: updatedText(for: cached.date),
            isCached: true,
            isDaylight: cached.isDaylight
        )
    }

    private var displayMetricChips: [PopoverMetricChip] {
        if let weather = viewModel.currentWeather {
            return liveMetricChips(for: weather)
        }
        guard let cached = activeCachedWeather else { return [] }
        return cachedMetricChips(for: cached)
    }

    private var alertText: String? {
        guard !viewModel.weatherAlerts.isEmpty else { return nil }
        let count = viewModel.weatherAlerts.count
        return count == 1 ? "1 alert in effect" : "\(count) alerts in effect"
    }

    private var primaryAlertNavigationRequest: OverviewAlertNavigationRequest? {
        guard let firstAlert = viewModel.weatherAlerts.first else { return nil }
        return OverviewAlertNavigationRequest(target: firstAlert.navigationTarget(at: 0))
    }

    private var summaryStatusText: String? {
        if let error = viewModel.errorMessage, displaySummary?.isCached == true {
            return "Showing cached conditions. \(error)"
        }

        if let loadingStatusMessage = viewModel.loadingStatusMessage {
            if displaySummary?.isCached == true {
                return "Showing cached conditions. \(loadingStatusMessage)"
            }
            return loadingStatusMessage
        }

        return viewModel.errorMessage
    }

    private var emptyStateText: String {
        if let loadingStatusMessage = viewModel.loadingStatusMessage {
            return loadingStatusMessage
        }
        return "Use Current Location or open the full forecast for a deeper view."
    }

    private var popoverBackdrop: some View {
        RoundedRectangle(cornerRadius: WeatherDesignTokens.popoverCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: popoverGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 170, height: 170)
                    .blur(radius: 58)
                    .offset(x: -52, y: -86)
            }
            .overlay(alignment: .bottomTrailing) {
                Ellipse()
                    .fill(WeatherDesignTokens.accentStrong.opacity(0.18))
                    .frame(width: 220, height: 130)
                    .blur(radius: 64)
                    .offset(x: 54, y: 56)
            }
            .overlay(
                RoundedRectangle(cornerRadius: WeatherDesignTokens.popoverCorner, style: .continuous)
                    .fill(Color.black.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WeatherDesignTokens.popoverCorner, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }

    private var popoverGradientColors: [Color] {
        if let summary = displaySummary, summary.isDaylight == true {
            return [
                Color(red: 0.24, green: 0.36, blue: 0.66),
                Color(red: 0.35, green: 0.47, blue: 0.74),
                Color(red: 0.44, green: 0.56, blue: 0.82)
            ]
        }

        return [
            Color(red: 0.08, green: 0.12, blue: 0.24),
            Color(red: 0.13, green: 0.18, blue: 0.34),
            Color(red: 0.20, green: 0.26, blue: 0.42)
        ]
    }

    private func openFullForecast() {
        shellState.showMainWindow(destination: .overview) {
            openWindow(id: WeatherSceneIDs.mainWindow)
        }
    }

    private func openOverviewAlert() {
        guard let primaryAlertNavigationRequest else {
            openFullForecast()
            return
        }

        shellState.showMainWindow(
            destination: .overview,
            overviewAlertRequest: primaryAlertNavigationRequest
        ) {
            openWindow(id: WeatherSceneIDs.mainWindow)
        }
    }

    private func updatedText(for date: Date) -> String {
        "Updated \(formattedTime(date, in: activeTimeZone))"
    }

    private func formattedTime(_ date: Date, in timeZone: TimeZone) -> String {
        PopoverDateFormatterCache.shortTimeFormatter(for: timeZone).string(from: date)
    }

    private func liveMetricChips(for weather: CurrentWeather) -> [PopoverMetricChip] {
        var chips: [PopoverMetricChip] = [
            PopoverMetricChip(id: "feels", icon: "thermometer.medium", text: "Feels \(formatting.temperatureText(weather.apparentTemperature))"),
            PopoverMetricChip(id: "humidity", icon: "humidity.fill", text: "Hum \(Int((weather.humidity * 100).rounded()))%")
        ]

        if let day = viewModel.dailyForecast.first {
            chips.insert(
                PopoverMetricChip(id: "high", icon: "arrow.up", text: "High \(formatting.temperatureText(day.highTemperature))"),
                at: 1
            )
            chips.insert(
                PopoverMetricChip(id: "low", icon: "arrow.down", text: "Low \(formatting.temperatureText(day.lowTemperature))"),
                at: 2
            )
        }

        return chips
    }

    private func cachedMetricChips(for cached: CachedLocationWeather) -> [PopoverMetricChip] {
        var chips: [PopoverMetricChip] = []

        if let apparentTemperature = cached.apparentTemperature {
            chips.append(
                PopoverMetricChip(
                    id: "feels",
                    icon: "thermometer.medium",
                    text: "Feels \(formatting.cachedTemperatureText(apparentTemperature))"
                )
            )
        }

        if let highTemperature = cached.highTemperature {
            chips.append(
                PopoverMetricChip(
                    id: "high",
                    icon: "arrow.up",
                    text: "High \(formatting.cachedTemperatureText(highTemperature))"
                )
            )
        }

        if let lowTemperature = cached.lowTemperature {
            chips.append(
                PopoverMetricChip(
                    id: "low",
                    icon: "arrow.down",
                    text: "Low \(formatting.cachedTemperatureText(lowTemperature))"
                )
            )
        }

        if let humidity = cached.humidity {
            chips.append(
                PopoverMetricChip(
                    id: "humidity",
                    icon: "humidity.fill",
                    text: "Hum \(Int((humidity * 100).rounded()))%"
                )
            )
        }

        return chips
    }
}

private struct PopoverHeroActions: View {
    let isFetchingCurrentLocation: Bool
    let onCurrentLocation: () -> Void
    let onRefresh: () -> Void
    let openFullForecast: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onCurrentLocation) {
                Group {
                    if isFetchingCurrentLocation {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white.opacity(0.92))
                    } else {
                        Image(systemName: "location")
                    }
                }
            }
            .buttonStyle(WeatherCompactIconButtonStyle(isActive: isFetchingCurrentLocation))
            .disabled(isFetchingCurrentLocation)
            .help(isFetchingCurrentLocation ? "Finding Current Location..." : "Current Location")

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(WeatherCompactIconButtonStyle())
            .help("Refresh")

            Menu {
                Button(action: openFullForecast) {
                    Label("Open Full Forecast", systemImage: "arrow.up.forward.app")
                }
                Divider()
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .buttonStyle(WeatherCompactIconButtonStyle())
            .help("More")
        }
    }
}

private struct PopoverCurrentConditionsCard: View {
    let locationName: String
    let localTimeText: String
    let onCurrentLocation: () -> Void
    let onRefresh: () -> Void
    let openFullForecast: () -> Void
    let summary: PopoverWeatherSummary?
    let metricChips: [PopoverMetricChip]
    let alertText: String?
    let onAlertTap: () -> Void
    let statusText: String?
    let isFetchingCurrentLocation: Bool
    let isLoading: Bool
    let fallbackText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(locationName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(localTimeText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .monospacedDigit()
                }

                Spacer(minLength: 8)

                PopoverHeroActions(
                    isFetchingCurrentLocation: isFetchingCurrentLocation,
                    onCurrentLocation: onCurrentLocation,
                    onRefresh: onRefresh,
                    openFullForecast: openFullForecast
                )
            }

            if let summary {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(summary.conditionText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))

                        Text(summary.updatedText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.64))
                            .monospacedDigit()
                    }

                    Spacer(minLength: 12)

                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: summary.symbolName)
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(.white.opacity(0.90))
                            .symbolRenderingMode(.hierarchical)

                        Text(summary.temperatureText)
                            .font(.system(size: 40, weight: .thin))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                    }
                }

                if !metricChips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(metricChips) { chip in
                                PopoverMetricChipView(chip: chip)
                            }
                        }
                    }
                }

                if let alertText {
                    Button(action: onAlertTap) {
                        alertPill(text: alertText)
                    }
                    .buttonStyle(.plain)
                    .help("Open this alert in the full forecast")
                    .accessibilityHint("Opens the full forecast and expands the alert details")
                }
            } else {
                HStack(spacing: 10) {
                    Text(fallbackText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.84))
                        .multilineTextAlignment(.leading)

                    if isLoading {
                        Spacer(minLength: 8)
                        ProgressView()
                            .tint(.white.opacity(0.88))
                    }
                }
            }

            if let statusText {
                Text(statusText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(2)
            }
        }
        .padding(WeatherDesignTokens.popoverCardPadding)
        .quickStatusCard()
    }

    private func alertPill(text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.yellow.opacity(0.98))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.yellow.opacity(0.12))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.yellow.opacity(0.22), lineWidth: 1)
            )
    }
}

private struct PopoverForecastDeck: View {
    let minuteForecast: Forecast<MinuteWeather>?
    let hourlyForecast: [HourWeather]
    let dailyForecast: [DayWeather]
    let timeZone: TimeZone
    let useCelsius: Bool
    let isLoading: Bool
    let formatter: PopoverFormatting

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            precipitationSection
            deckDivider
            hourlySection
            deckDivider
            dailySection
        }
        .padding(WeatherDesignTokens.popoverCardPadding)
        .quickStatusCard()
    }

    private var precipitationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Next Hour")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))

                Spacer(minLength: 8)

                Text(precipitationSummaryText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .lineLimit(1)
            }

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(minuteBars) { bar in
                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                        .fill(bar.color)
                        .frame(height: bar.height)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 16, alignment: .bottom)
        }
    }

    private var hourlySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Next 8 Hours")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.66))

            if hourlyForecast.isEmpty {
                Text(isLoading ? "Loading hourly forecast…" : "Hourly forecast unavailable.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                HStack(spacing: 6) {
                    ForEach(hourlyForecast, id: \.date) { hour in
                        VStack(spacing: 3) {
                            Text(formatter.hourText(hour.date, in: timeZone))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.62))
                                .monospacedDigit()

                            Image(systemName: hour.symbolName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.90))
                                .symbolRenderingMode(.hierarchical)

                            Text(formatter.temperatureText(hour.temperature))
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .monospacedDigit()

                            Text(hour.precipitationChance >= 0.2 ? "\(Int((hour.precipitationChance * 100).rounded()))%" : " ")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(hour.precipitationChance >= 0.2 ? Color.cyan.opacity(0.94) : Color.clear)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var dailySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Coming Up")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.66))

            if dailyForecast.isEmpty {
                Text(isLoading ? "Loading daily forecast…" : "Daily forecast unavailable.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            } else {
                VStack(spacing: 6) {
                    ForEach(dailyForecast, id: \.date) { day in
                        HStack(spacing: 8) {
                            Text(formatter.dayText(day.date, in: timeZone))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.88))
                                .frame(width: 44, alignment: .leading)

                            Image(systemName: day.symbolName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.88))
                                .symbolRenderingMode(.hierarchical)
                                .frame(width: 18)

                            if day.precipitationChance >= 0.15 {
                                Text("\(Int((day.precipitationChance * 100).rounded()))%")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.cyan.opacity(0.92))
                                    .monospacedDigit()
                                    .frame(width: 34, alignment: .leading)
                            } else {
                                Spacer()
                                    .frame(width: 34)
                            }

                            Spacer(minLength: 6)

                            Text("\(formatter.temperatureText(day.lowTemperature)) / \(formatter.temperatureText(day.highTemperature))")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.86))
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private var precipitationSummaryText: String {
        guard let minuteForecast else {
            return "Minute forecast unavailable"
        }

        let minutes = Array(minuteForecast.prefix(12))
        guard !minutes.isEmpty else {
            return "No minute forecast"
        }

        let maxIntensity = minutes.map(\.precipitationIntensity.value).max() ?? 0
        guard maxIntensity > 0.05 else {
            return "No meaningful rain"
        }

        guard let heaviest = minutes.max(by: { $0.precipitationIntensity.value < $1.precipitationIntensity.value }) else {
            return "Precipitation possible"
        }

        return "Peaks \(formatter.timeText(heaviest.date, in: timeZone))"
    }

    private var minuteBars: [MinuteBar] {
        guard let minuteForecast else {
            return Array(repeating: MinuteBar(height: 4, color: Color.white.opacity(0.12)), count: 12)
        }

        let minutes = Array(minuteForecast.prefix(12))
        let maxIntensity = minutes.map(\.precipitationIntensity.value).max() ?? 0

        return minutes.map { minute in
            let ratio = maxIntensity > 0 ? min(minute.precipitationIntensity.value / maxIntensity, 1) : 0
            return MinuteBar(
                height: max(3, 12 * ratio),
                color: ratio > 0.05 ? Color.cyan.opacity(0.88) : Color.white.opacity(0.14)
            )
        }
    }

    private var deckDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }
}

private struct PopoverSavedLocationsRail: View {
    let locations: [SavedLocation]
    let cache: [UUID: CachedLocationWeather]
    let selectedLocationID: UUID?
    let currentTime: Date
    let useCelsius: Bool
    let onSelectLocation: (UUID) -> Void
    let openFullForecast: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Saved Locations")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))
                Spacer()
                Button("Open Full Forecast", action: openFullForecast)
                    .buttonStyle(PopoverTextButtonStyle(emphasized: true))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WeatherDesignTokens.popoverRailSpacing) {
                    ForEach(locations) { location in
                        let cachedWeather = cache[location.id]
                        Button {
                            onSelectLocation(location.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(location.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text(localTime(for: location, cachedWeather: cachedWeather) ?? "Updating")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.66))
                                        .monospacedDigit()

                                    if let cachedWeather {
                                        Text(temperatureText(for: cachedWeather))
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.84))
                                            .monospacedDigit()
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: WeatherDesignTokens.popoverChipHeight)
                            .frame(minWidth: 116, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(selectedLocationID == location.id ? Color.white.opacity(0.18) : Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        selectedLocationID == location.id ? Color.white.opacity(0.24) : Color.white.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: openFullForecast) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.forward.app")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Forecast")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.90))
                        .padding(.horizontal, 14)
                        .frame(height: WeatherDesignTokens.popoverChipHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 1)
            }
        }
        .padding(WeatherDesignTokens.popoverCompactCardPadding)
        .quickStatusCard()
    }

    private func localTime(for location: SavedLocation, cachedWeather: CachedLocationWeather?) -> String? {
        let timeZone = cachedWeather?.timeZone ?? location.timeZone
        guard let timeZone else { return nil }
        return PopoverDateFormatterCache.shortTimeFormatter(for: timeZone).string(from: currentTime)
    }

    private func temperatureText(for cachedWeather: CachedLocationWeather) -> String {
        let source = Measurement(value: cachedWeather.temperature, unit: UnitTemperature.celsius)
        let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
        return "\(Int(source.converted(to: unit).value.rounded()))°"
    }
}

private struct PopoverWeatherSummary {
    let temperatureText: String
    let symbolName: String
    let conditionText: String
    let updatedText: String
    let isCached: Bool
    let isDaylight: Bool?
}

private struct PopoverMetricChip: Identifiable {
    let id: String
    let icon: String
    let text: String
}

private struct PopoverMetricChipView: View {
    let chip: PopoverMetricChip

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: chip.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.68))

            Text(chip.text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct MinuteBar: Identifiable {
    let id = UUID()
    let height: CGFloat
    let color: Color
}

private struct PopoverFormatting {
    let useCelsius: Bool

    func temperatureText(_ temperature: Measurement<UnitTemperature>) -> String {
        let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
        let value = temperature.converted(to: unit).value.rounded()
        return "\(Int(value))°"
    }

    func cachedTemperatureText(_ valueInCelsius: Double) -> String {
        let source = Measurement(value: valueInCelsius, unit: UnitTemperature.celsius)
        let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
        return temperatureText(source.converted(to: unit))
    }

    func timeText(_ date: Date, in timeZone: TimeZone) -> String {
        PopoverDateFormatterCache.shortTimeFormatter(for: timeZone).string(from: date)
    }

    func hourText(_ date: Date, in timeZone: TimeZone) -> String {
        PopoverDateFormatterCache.hourFormatter(for: timeZone).string(from: date)
    }

    func dayText(_ date: Date, in timeZone: TimeZone) -> String {
        PopoverDateFormatterCache.dayFormatter(for: timeZone).string(from: date)
    }
}

private struct PopoverTextButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(
                emphasized
                    ? WeatherDesignTokens.accent.opacity(configuration.isPressed ? 0.78 : 0.96)
                    : Color.white.opacity(configuration.isPressed ? 0.68 : 0.82)
            )
            .contentShape(Rectangle())
    }
}

private struct QuickStatusCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.black.opacity(0.12))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 6)
    }
}

private extension View {
    func quickStatusCard() -> some View {
        modifier(QuickStatusCardModifier())
    }
}
