import SwiftUI
import WeatherKit

private enum OverviewDetailSection: Hashable {
    case conditions
    case airQuality
    case astronomy
    case aiSummary
}

private struct OverviewInsetSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.10), radius: 10, x: 0, y: 8)
    }
}

private extension View {
    func overviewInsetSurface(cornerRadius: CGFloat) -> some View {
        modifier(OverviewInsetSurfaceModifier(cornerRadius: cornerRadius))
    }
}

struct OverviewForecastDashboard: View {
    let weather: CurrentWeather
    let locationName: String?
    let isCurrentLocation: Bool
    let dailyForecast: DayWeather?
    let dailyForecasts: [DayWeather]
    let alerts: [WeatherAlert]
    let locationTimeZone: TimeZone?
    let airQuality: AirQualitySnapshot?
    let hourlyForecast: [HourWeather]
    let minuteForecast: Forecast<MinuteWeather>?
    let aiSummaryStatus: String?
    let aiSummaryShort: String?
    let aiSummaryLong: String?
    let lastUpdated: Date?
    let expandedAlertKeys: Set<String>
    let toggleAlertExpansion: (String) -> Void
    let alertsSectionID: String

    @State private var expandedSections: Set<OverviewDetailSection> = [.conditions]
    @AppStorage("useCelsius") private var useCelsius: Bool = false

    var body: some View {
        VStack(spacing: 22) {
            OverviewHeroCard(
                weather: weather,
                locationName: locationName,
                isCurrentLocation: isCurrentLocation,
                dailyForecast: dailyForecast,
                alerts: alerts,
                locationTimeZone: locationTimeZone,
                lastUpdated: lastUpdated,
                useCelsius: useCelsius
            )

            if !alerts.isEmpty {
                OverviewAlertsSection(
                    alerts: alerts,
                    expandedAlertKeys: expandedAlertKeys,
                    toggleAlertExpansion: toggleAlertExpansion,
                    alertsSectionID: alertsSectionID
                )
            }

            OverviewNextHourCard(
                minuteForecast: minuteForecast,
                hourlyForecast: hourlyForecast,
                locationTimeZone: locationTimeZone
            )

            OverviewHourlyStripSection(
                hourlyForecast: Array(hourlyForecast.prefix(24)),
                locationTimeZone: locationTimeZone,
                useCelsius: useCelsius
            )

            OverviewTenDayForecastSection(
                dailyForecasts: Array(dailyForecasts.prefix(10)),
                useCelsius: useCelsius
            )

            OverviewExpandableCard(
                icon: "thermometer.medium",
                title: "Conditions",
                summary: conditionsSummary,
                tint: .orange,
                isExpanded: expandedSections.contains(.conditions),
                action: { toggle(.conditions) }
            ) {
                OverviewConditionsContent(weather: weather, useCelsius: useCelsius)
            }

            OverviewExpandableCard(
                icon: "aqi.medium",
                title: "Air Quality",
                summary: airQualitySummary,
                tint: airQualityTint,
                isExpanded: expandedSections.contains(.airQuality),
                action: { toggle(.airQuality) }
            ) {
                OverviewAirQualityContent(airQuality: airQuality)
            }

            if let dailyForecast {
                OverviewExpandableCard(
                    icon: "sun.max.fill",
                    title: "Sun & Moon",
                    summary: astronomySummary(for: dailyForecast),
                    tint: .yellow,
                    isExpanded: expandedSections.contains(.astronomy),
                    action: { toggle(.astronomy) }
                ) {
                    OverviewAstronomyContent(
                        dailyForecast: dailyForecast,
                        locationTimeZone: locationTimeZone
                    )
                }
            }

            OverviewExpandableCard(
                icon: "sparkles",
                title: "AI Summary",
                summary: aiSummaryPreview,
                tint: .cyan,
                isExpanded: expandedSections.contains(.aiSummary),
                showsSummaryWhenExpanded: false,
                action: { toggle(.aiSummary) }
            ) {
                OverviewAISummaryContent(
                    dailyForecast: dailyForecast,
                    hourlyForecast: hourlyForecast,
                    aiSummaryStatus: aiSummaryStatus,
                    aiSummaryShort: aiSummaryShort,
                    aiSummaryLong: aiSummaryLong,
                    currentCondition: weather.condition.description,
                    useCelsius: useCelsius
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
    }

    private func toggle(_ section: OverviewDetailSection) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if expandedSections.contains(section) {
                expandedSections.remove(section)
            } else {
                expandedSections.insert(section)
            }
        }
    }

    private var conditionsSummary: String {
        let humidity = Int((weather.humidity * 100).rounded())
        return "Feels like \(OverviewFormatting.temperature(weather.apparentTemperature, useCelsius: useCelsius))°, humidity \(humidity)%, wind \(OverviewFormatting.speed(weather.wind.speed, useCelsius: useCelsius))."
    }

    private var airQualitySummary: String {
        guard let airQuality else {
            return "Air quality data is loading for this location."
        }

        let aqi = airQuality.usAQI ?? airQuality.europeanAQI
        guard let aqi else {
            return "AQI is unavailable right now."
        }

        let scale = airQuality.scale ?? (airQuality.usAQI != nil ? .us : .eu)
        return "AQI \(Int(aqi.rounded())) • \(OverviewFormatting.aqiCategory(aqi, scale: scale))."
    }

    private var airQualityTint: Color {
        guard let airQuality else { return .white.opacity(0.8) }
        let scale = airQuality.scale ?? (airQuality.usAQI != nil ? .us : .eu)
        if let aqi = airQuality.usAQI ?? airQuality.europeanAQI {
            return OverviewFormatting.aqiColor(aqi, scale: scale)
        }
        return .white.opacity(0.8)
    }

    private func astronomySummary(for dailyForecast: DayWeather) -> String {
        let sunrise = OverviewFormatting.time(dailyForecast.sun.sunrise, timeZone: locationTimeZone)
        let sunset = OverviewFormatting.time(dailyForecast.sun.sunset, timeZone: locationTimeZone)
        return "Sunrise \(sunrise), sunset \(sunset), moon \(dailyForecast.moon.phase.description.lowercased())."
    }

    private var aiSummaryPreview: String {
        if let aiSummaryShort, !aiSummaryShort.isEmpty {
            return aiSummaryShort
        }
        if let status = aiSummaryStatus, !status.isEmpty {
            return status
        }
        return "Forecast narrative will appear here when the summary is ready."
    }
}

private struct OverviewHeroCard: View {
    let weather: CurrentWeather
    let locationName: String?
    let isCurrentLocation: Bool
    let dailyForecast: DayWeather?
    let alerts: [WeatherAlert]
    let locationTimeZone: TimeZone?
    let lastUpdated: Date?
    let useCelsius: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: isCurrentLocation ? "location.fill" : "mappin.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.78))

                        Text(isCurrentLocation ? "Current Location" : "Saved Forecast")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .textCase(.uppercase)
                    }

                    Text(locationName ?? "Weather")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(OverviewFormatting.locationMetaLine(timeZone: locationTimeZone, lastUpdated: lastUpdated))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer(minLength: 16)

                HStack(spacing: 8) {
                    OverviewStatusChip(
                        icon: alerts.isEmpty ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        title: alerts.isEmpty ? "No Alerts" : "\(alerts.count) Alert\(alerts.count == 1 ? "" : "s")",
                        tint: alerts.isEmpty ? Color.green.opacity(0.82) : Color.yellow.opacity(0.92)
                    )

                    if let dailyForecast {
                        OverviewStatusChip(
                            icon: "sun.max.fill",
                            title: "UV \(dailyForecast.uvIndex.value)",
                            tint: .orange.opacity(0.9)
                        )
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 20) {
                    heroTemperature
                    Spacer(minLength: 12)
                    heroSymbol
                }

                VStack(alignment: .leading, spacing: 16) {
                    heroTemperature
                    heroSymbol
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(26)
        .background(heroBackground)
        .overlay(heroBorder)
        .shadow(color: .black.opacity(0.22), radius: 26, x: 0, y: 14)
    }

    private var heroTemperature: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(OverviewFormatting.temperature(weather.temperature, useCelsius: useCelsius))°")
                .font(.system(size: 84, weight: .thin))
                .foregroundStyle(.white)
                .monospacedDigit()

            Text(weather.condition.description)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))

            HStack(spacing: 12) {
                if let high = dailyForecast?.highTemperature,
                   let low = dailyForecast?.lowTemperature {
                    OverviewHeroFact(icon: "arrow.up", label: "High", value: "\(OverviewFormatting.temperature(high, useCelsius: useCelsius))°")
                    OverviewHeroFact(icon: "arrow.down", label: "Low", value: "\(OverviewFormatting.temperature(low, useCelsius: useCelsius))°")
                }

                OverviewHeroFact(
                    icon: "thermometer.medium",
                    label: "Feels Like",
                    value: "\(OverviewFormatting.temperature(weather.apparentTemperature, useCelsius: useCelsius))°"
                )

                OverviewHeroFact(
                    icon: "humidity.fill",
                    label: "Humidity",
                    value: "\(Int((weather.humidity * 100).rounded()))%"
                )
            }
        }
    }

    private var heroSymbol: some View {
        VStack(alignment: .trailing, spacing: 10) {
            Image(systemName: weather.symbolName)
                .font(.system(size: 92, weight: .thin))
                .foregroundStyle(.white.opacity(0.95))
                .symbolRenderingMode(.hierarchical)

            Text(OverviewFormatting.heroSupportLine(weather: weather, timeZone: locationTimeZone, useCelsius: useCelsius))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 220, alignment: .trailing)
        }
    }

    private var heroBackground: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(
                    colors: weather.isDaylight
                        ? [
                            Color(red: 0.22, green: 0.43, blue: 0.74),
                            Color(red: 0.31, green: 0.60, blue: 0.87),
                            Color(red: 0.57, green: 0.79, blue: 0.95)
                        ]
                        : [
                            Color(red: 0.08, green: 0.12, blue: 0.24),
                            Color(red: 0.11, green: 0.20, blue: 0.36),
                            Color(red: 0.16, green: 0.28, blue: 0.44)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black.opacity(weather.isDaylight ? 0.08 : 0.20))
            )
    }

    private var heroBorder: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .stroke(Color.white.opacity(0.14), lineWidth: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
            )
    }
}

private struct OverviewAlertsSection: View {
    let alerts: [WeatherAlert]
    let expandedAlertKeys: Set<String>
    let toggleAlertExpansion: (String) -> Void
    let alertsSectionID: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Alerts")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            ForEach(Array(alerts.enumerated()), id: \.offset) { index, alert in
                let alertTarget = alert.navigationTarget(at: index)
                WeatherAlertBanner(
                    alert: alert,
                    alertTarget: alertTarget,
                    alertIndex: index,
                    totalAlerts: alerts.count,
                    isExpanded: expandedAlertKeys.contains(alertTarget.key)
                ) {
                    toggleAlertExpansion(alertTarget.key)
                }
                .id(alertTarget.key)
            }
        }
        .id(alertsSectionID)
    }
}

private struct OverviewNextHourCard: View {
    let minuteForecast: Forecast<MinuteWeather>?
    let hourlyForecast: [HourWeather]
    let locationTimeZone: TimeZone?

    private var minuteSlice: [MinuteWeather] {
        guard let minuteForecast else { return [] }
        return Array(minuteForecast.prefix(60))
    }

    private var maxIntensity: Double {
        minuteSlice.map(\.precipitationIntensity.value).max() ?? 0
    }

    private var wetMinutes: [MinuteWeather] {
        minuteSlice.filter { $0.precipitationIntensity.value >= 0.05 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Next Hour")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(summaryLine)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.76))
                }

                Spacer()

                OverviewStatusChip(
                    icon: wetMinutes.isEmpty ? "cloud.sun.fill" : "cloud.rain.fill",
                    title: wetMinutes.isEmpty ? "Dry" : peakLabel,
                    tint: wetMinutes.isEmpty ? .blue.opacity(0.75) : .cyan.opacity(0.85)
                )
            }

            if !minuteSlice.isEmpty {
                VStack(spacing: 8) {
                    GeometryReader { proxy in
                        let height = proxy.size.height
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(minuteSlice, id: \.date) { minute in
                                let ratio = maxIntensity > 0 ? min(minute.precipitationIntensity.value / maxIntensity, 1.0) : 0
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(minute.precipitationIntensity.value >= 0.05 ? Color.cyan.opacity(0.85) : Color.white.opacity(0.12))
                                    .frame(height: max(6, height * ratio))
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(height: 82)

                    HStack {
                        Text(OverviewFormatting.time(minuteSlice.first?.date, timeZone: locationTimeZone))
                        Spacer()
                        Text(OverviewFormatting.time(minuteSlice.dropFirst(15).first?.date, timeZone: locationTimeZone))
                        Spacer()
                        Text(OverviewFormatting.time(minuteSlice.dropFirst(30).first?.date, timeZone: locationTimeZone))
                        Spacer()
                        Text(OverviewFormatting.time(minuteSlice.dropFirst(45).first?.date, timeZone: locationTimeZone))
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .monospacedDigit()
                }
            } else {
                Text("Minute-by-minute precipitation isn’t available for this location yet.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }

    private var peakLabel: String {
        if maxIntensity > 0 {
            return String(format: "%.2f mm/hr", maxIntensity)
        }
        return "Tracking"
    }

    private var summaryLine: String {
        if let firstWet = wetMinutes.first, let peak = wetMinutes.max(by: { $0.precipitationIntensity.value < $1.precipitationIntensity.value }) {
            let start = OverviewFormatting.time(firstWet.date, timeZone: locationTimeZone)
            let peakTime = OverviewFormatting.time(peak.date, timeZone: locationTimeZone)
            if firstWet.date == peak.date {
                return "Precipitation builds around \(peakTime) and stays light afterward."
            }
            return "Rain starts near \(start) and peaks around \(peakTime)."
        }

        if let leadingHour = hourlyForecast.first, leadingHour.precipitationChance >= 0.2 {
            return "Hourly guidance still shows a \(Int((leadingHour.precipitationChance * 100).rounded()))% chance of precipitation soon."
        }

        return "No meaningful precipitation is expected in the next hour."
    }
}

private struct OverviewHourlyStripSection: View {
    let hourlyForecast: [HourWeather]
    let locationTimeZone: TimeZone?
    let useCelsius: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("24-Hour Forecast")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Text("Glanceable trend")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.54))
            }

            if hourlyForecast.isEmpty {
                Text("Hourly forecast is unavailable.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(hourlyForecast.enumerated()), id: \.element.date) { index, hour in
                            OverviewHourCard(
                                hour: hour,
                                timeLabel: index == 0
                                    ? "Now"
                                    : OverviewFormatting.hour(hour.date, timeZone: locationTimeZone),
                                isCurrentHour: index == 0,
                                useCelsius: useCelsius
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }
}

private struct OverviewHourCard: View {
    let hour: HourWeather
    let timeLabel: String
    let isCurrentHour: Bool
    let useCelsius: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text(timeLabel)
                .font(.system(size: 12, weight: isCurrentHour ? .bold : .semibold))
                .foregroundStyle(.white.opacity(isCurrentHour ? 0.96 : 0.72))
                .monospacedDigit()

            Image(systemName: hour.symbolName)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.92))
                .symbolRenderingMode(.hierarchical)

            Text("\(OverviewFormatting.temperature(hour.temperature, useCelsius: useCelsius))°")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()

            HStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("\(Int((hour.precipitationChance * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(hour.precipitationChance >= 0.2 ? Color.cyan.opacity(0.92) : Color.white.opacity(0.48))
        }
        .frame(width: 84)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isCurrentHour ? Color.white.opacity(0.06) : Color.clear)
        )
        .overviewInsetSurface(cornerRadius: 18)
    }
}

private struct OverviewTenDayForecastSection: View {
    let dailyForecasts: [DayWeather]
    let useCelsius: Bool

    private var temperatureBounds: (low: Double, high: Double)? {
        let lows = dailyForecasts.map { $0.lowTemperature.converted(to: .celsius).value }
        let highs = dailyForecasts.map { $0.highTemperature.converted(to: .celsius).value }
        guard let minLow = lows.min(), let maxHigh = highs.max() else { return nil }
        return (minLow, maxHigh)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("10-Day Forecast")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            if dailyForecasts.isEmpty {
                Text("Daily forecast is unavailable.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dailyForecasts.enumerated()), id: \.element.date) { index, day in
                        OverviewDailyForecastRow(
                            day: day,
                            index: index,
                            bounds: temperatureBounds,
                            useCelsius: useCelsius
                        )

                        if index < dailyForecasts.count - 1 {
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 1)
                                .padding(.leading, 6)
                        }
                    }
                }
            }
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }
}

private struct OverviewDailyForecastRow: View {
    let day: DayWeather
    let index: Int
    let bounds: (low: Double, high: Double)?
    let useCelsius: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(index == 0 ? "Today" : day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, alignment: .leading)

            Image(systemName: day.symbolName)
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24)

            Text(day.condition.description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.74))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if day.precipitationChance >= 0.15 {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(Int((day.precipitationChance * 100).rounded()))%")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
                .foregroundStyle(Color.cyan.opacity(0.88))
                .frame(width: 48, alignment: .leading)
            } else {
                Spacer()
                    .frame(width: 48)
            }

            Text("\(OverviewFormatting.temperature(day.lowTemperature, useCelsius: useCelsius))°")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.62))
                .monospacedDigit()

            OverviewTemperatureRangeBar(day: day, bounds: bounds)
                .frame(width: 108)

            Text("\(OverviewFormatting.temperature(day.highTemperature, useCelsius: useCelsius))°")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.vertical, 12)
    }
}

private struct OverviewTemperatureRangeBar: View {
    let day: DayWeather
    let bounds: (low: Double, high: Double)?

    private var low: Double {
        day.lowTemperature.converted(to: .celsius).value
    }

    private var high: Double {
        day.highTemperature.converted(to: .celsius).value
    }

    var body: some View {
        GeometryReader { proxy in
            let total = max((bounds?.high ?? high) - (bounds?.low ?? low), 1)
            let leading = ((low - (bounds?.low ?? low)) / total) * proxy.size.width
            let width = ((high - low) / total) * proxy.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 6)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                WeatherDesignTokens.accentStrong.opacity(0.78),
                                Color.orange.opacity(0.82)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(width, 10), height: 6)
                    .offset(x: leading)
            }
        }
        .frame(height: 6)
    }
}

private struct OverviewExpandableCard<Content: View>: View {
    let icon: String
    let title: String
    let summary: String
    let tint: Color
    let isExpanded: Bool
    let showsSummaryWhenExpanded: Bool
    let action: () -> Void
    @ViewBuilder let content: Content

    init(
        icon: String,
        title: String,
        summary: String,
        tint: Color,
        isExpanded: Bool,
        showsSummaryWhenExpanded: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.summary = summary
        self.tint = tint
        self.isExpanded = isExpanded
        self.showsSummaryWhenExpanded = showsSummaryWhenExpanded
        self.action = action
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 22)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)

                        if showsSummaryWhenExpanded || !isExpanded {
                            Text(summary)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.white.opacity(0.70))
                                .multilineTextAlignment(.leading)
                        }
                    }

                    Spacer(minLength: 16)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.62))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.top, 6)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                GlassDivider(opacity: 0.12)
                    .padding(.vertical, 14)

                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .liquidGlassCard(cornerRadius: 24)
    }
}

private struct OverviewConditionsContent: View {
    let weather: CurrentWeather
    let useCelsius: Bool

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            OverviewMetricTile(icon: "thermometer.medium", title: "Feels Like", value: "\(OverviewFormatting.temperature(weather.apparentTemperature, useCelsius: useCelsius))°")
            OverviewMetricTile(icon: "wind", title: "Wind", value: OverviewFormatting.speed(weather.wind.speed, useCelsius: useCelsius))
            OverviewMetricTile(icon: "humidity.fill", title: "Humidity", value: "\(Int((weather.humidity * 100).rounded()))%")
            OverviewMetricTile(icon: "eye.fill", title: "Visibility", value: OverviewFormatting.visibility(weather.visibility, useCelsius: useCelsius))
            OverviewMetricTile(icon: "gauge.with.dots.needle.33percent", title: "Pressure", value: OverviewFormatting.pressure(weather.pressure))
            OverviewMetricTile(icon: "sun.max.fill", title: "UV Index", value: "\(weather.uvIndex.value) \(weather.uvIndex.category.description)")
        }
    }
}

private struct OverviewMetricTile: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }

            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding(16)
        .overviewInsetSurface(cornerRadius: 18)
    }
}

private struct OverviewAirQualityContent: View {
    let airQuality: AirQualitySnapshot?

    var body: some View {
        if let airQuality {
            let scale = airQuality.scale ?? (airQuality.usAQI != nil ? .us : .eu)
            let aqiValue = airQuality.usAQI ?? airQuality.europeanAQI

            VStack(alignment: .leading, spacing: 16) {
                if let aqiValue {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Current AQI")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.62))

                            Spacer()

                            Text("\(Int(aqiValue.rounded()))")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(OverviewFormatting.aqiColor(aqiValue, scale: scale))
                        }

                        Text(OverviewFormatting.aqiCategory(aqiValue, scale: scale))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(OverviewFormatting.aqiColor(aqiValue, scale: scale))

                        AQIBar(value: aqiValue, scale: scale)
                    }
                } else {
                    Text("AQI is unavailable for this location right now.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.66))
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    OverviewPollutantTile(label: "PM2.5", value: OverviewFormatting.airValue(airQuality.pm25, unit: airQuality.units.pm25))
                    OverviewPollutantTile(label: "PM10", value: OverviewFormatting.airValue(airQuality.pm10, unit: airQuality.units.pm10))
                    OverviewPollutantTile(label: "O3", value: OverviewFormatting.airValue(airQuality.ozone, unit: airQuality.units.ozone))
                    OverviewPollutantTile(label: "NO2", value: OverviewFormatting.airValue(airQuality.nitrogenDioxide, unit: airQuality.units.nitrogenDioxide))
                    OverviewPollutantTile(label: "SO2", value: OverviewFormatting.airValue(airQuality.sulphurDioxide, unit: airQuality.units.sulphurDioxide))
                    OverviewPollutantTile(label: "CO", value: OverviewFormatting.airValue(airQuality.carbonMonoxide, unit: airQuality.units.carbonMonoxide))
                }
            }
        } else {
            Text("Air quality data is still loading.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.66))
        }
    }
}

private struct OverviewPollutantTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.56))

            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .overviewInsetSurface(cornerRadius: 16)
    }
}

private struct OverviewAstronomyContent: View {
    let dailyForecast: DayWeather
    let locationTimeZone: TimeZone?

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                OverviewAstronomyFact(icon: "sunrise.fill", label: "Sunrise", value: OverviewFormatting.time(dailyForecast.sun.sunrise, timeZone: locationTimeZone))
                OverviewAstronomyFact(icon: "sunset.fill", label: "Sunset", value: OverviewFormatting.time(dailyForecast.sun.sunset, timeZone: locationTimeZone))
                OverviewAstronomyFact(icon: "moonrise.fill", label: "Moonrise", value: OverviewFormatting.time(dailyForecast.moon.moonrise, timeZone: locationTimeZone))
                OverviewAstronomyFact(icon: "moonset.fill", label: "Moonset", value: OverviewFormatting.time(dailyForecast.moon.moonset, timeZone: locationTimeZone))
            }

            HStack(spacing: 10) {
                OverviewStatusChip(
                    icon: OverviewFormatting.moonPhaseSymbol(phase: dailyForecast.moon.phase),
                    title: dailyForecast.moon.phase.description,
                    tint: .yellow.opacity(0.90)
                )

                Spacer()
            }

            DayPartDetailRow(title: "Day", part: dailyForecast.daytimeForecast)
            DayPartDetailRow(title: "Night", part: dailyForecast.overnightForecast)

            SunPathView(
                sunrise: dailyForecast.sun.sunrise,
                sunset: dailyForecast.sun.sunset,
                timeZone: locationTimeZone
            )
        }
    }
}

private struct OverviewAstronomyFact: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.60))
            }

            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .padding(16)
        .overviewInsetSurface(cornerRadius: 18)
    }
}

private struct OverviewAISummaryContent: View {
    let dailyForecast: DayWeather?
    let hourlyForecast: [HourWeather]
    let aiSummaryStatus: String?
    let aiSummaryShort: String?
    let aiSummaryLong: String?
    let currentCondition: String
    let useCelsius: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(primaryNarrative)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            if let expandedNarrative {
                Text(expandedNarrative)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let status = visibleStatusText {
                Text(status)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
    }

    private var primaryNarrative: String {
        if let aiSummaryShort, !aiSummaryShort.isEmpty {
            return aiSummaryShort
        }
        if let dailyForecast {
            return "\(currentCondition) today with a high near \(OverviewFormatting.temperature(dailyForecast.highTemperature, useCelsius: useCelsius))° and a low near \(OverviewFormatting.temperature(dailyForecast.lowTemperature, useCelsius: useCelsius))°."
        }
        return "\(currentCondition) today."
    }

    private var expandedNarrative: String? {
        if let aiSummaryLong,
           !aiSummaryLong.isEmpty,
           normalized(aiSummaryLong) != normalized(primaryNarrative) {
            return aiSummaryLong
        }

        guard aiSummaryStatus == nil || aiSummaryStatus == "AI summary ready." else {
            return nil
        }

        let precipitationPeak = hourlyForecast.prefix(24).map(\.precipitationChance).max() ?? 0
        let windPeak = hourlyForecast.prefix(24)
            .map { $0.wind.speed }
            .max(by: { $0.value < $1.value })
            .map { OverviewFormatting.speed($0, useCelsius: useCelsius) }

        var fragments: [String] = []
        if precipitationPeak >= 0.2 {
            fragments.append("Rain chances rise to about \(Int((precipitationPeak * 100).rounded()))% later today.")
        }
        if let windPeak {
            fragments.append("Winds may peak around \(windPeak).")
        }

        guard !fragments.isEmpty else { return nil }
        return fragments.joined(separator: " ")
    }

    private func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private var visibleStatusText: String? {
        guard let aiSummaryStatus,
              !aiSummaryStatus.isEmpty,
              aiSummaryStatus != "AI summary ready." else {
            return nil
        }
        return aiSummaryStatus
    }
}

private struct OverviewHeroFact: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.78))

            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.64))

            Text(value)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
        )
    }
}

private struct OverviewStatusChip: View {
    let icon: String
    let title: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(tint)
                .overlay(
                    Capsule()
                        .fill(Color.black.opacity(0.12))
                )
        )
    }
}

private enum OverviewFormatting {
    static func temperature(_ temperature: Measurement<UnitTemperature>, useCelsius: Bool) -> Int {
        let unit: UnitTemperature = useCelsius ? .celsius : .fahrenheit
        return Int(temperature.converted(to: unit).value.rounded())
    }

    static func visibility(_ distance: Measurement<UnitLength>, useCelsius: Bool) -> String {
        let value = useCelsius ? distance.converted(to: .kilometers).value : distance.converted(to: .miles).value
        let unit = useCelsius ? "km" : "mi"
        return "\(String(format: "%.0f", value)) \(unit)"
    }

    static func speed(_ speed: Measurement<UnitSpeed>, useCelsius: Bool) -> String {
        let unit: UnitSpeed = useCelsius ? .kilometersPerHour : .milesPerHour
        let value = speed.converted(to: unit).value
        return "\(String(format: "%.1f", value)) \(useCelsius ? "km/h" : "mph")"
    }

    static func pressure(_ pressure: Measurement<UnitPressure>) -> String {
        "\(Int(pressure.converted(to: .hectopascals).value.rounded())) hPa"
    }

    static func time(_ date: Date?, timeZone: TimeZone?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone ?? .current
        return formatter.string(from: date)
    }

    static func hour(_ date: Date, timeZone: TimeZone?) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        formatter.timeZone = timeZone ?? .current
        return formatter.string(from: date).lowercased()
    }

    static func locationMetaLine(timeZone: TimeZone?, lastUpdated: Date?) -> String {
        let localTime = time(Date(), timeZone: timeZone)
        if let lastUpdated {
            let updatedFormatter = RelativeDateTimeFormatter()
            updatedFormatter.unitsStyle = .short
            let updatedString = updatedFormatter.localizedString(for: lastUpdated, relativeTo: Date())
            return "Local time \(localTime) • Updated \(updatedString)"
        }
        return "Local time \(localTime)"
    }

    static func heroSupportLine(weather: CurrentWeather, timeZone: TimeZone?, useCelsius: Bool) -> String {
        "Wind \(speed(weather.wind.speed, useCelsius: useCelsius))"
    }

    static func airValue(_ value: Double?, unit: String?) -> String {
        guard let value else { return "--" }
        if let unit, !unit.isEmpty {
            return String(format: "%.1f %@", value, unit)
        }
        return String(format: "%.1f", value)
    }

    static func aqiCategory(_ aqi: Double, scale: AirQualityScale) -> String {
        switch scale {
        case .us:
            switch aqi {
            case ..<51: return "Good"
            case 51..<101: return "Moderate"
            case 101..<151: return "Unhealthy for Sensitive Groups"
            case 151..<201: return "Unhealthy"
            case 201..<301: return "Very Unhealthy"
            default: return "Hazardous"
            }
        case .eu:
            switch aqi {
            case ..<20: return "Good"
            case 20..<40: return "Fair"
            case 40..<60: return "Moderate"
            case 60..<80: return "Poor"
            case 80..<100: return "Very Poor"
            default: return "Extremely Poor"
            }
        }
    }

    static func aqiColor(_ aqi: Double, scale: AirQualityScale) -> Color {
        switch scale {
        case .us:
            switch aqi {
            case ..<51: return .green
            case 51..<101: return .yellow
            case 101..<151: return .orange
            case 151..<201: return .red
            case 201..<301: return .purple
            default: return .brown
            }
        case .eu:
            switch aqi {
            case ..<20: return .green
            case 20..<40: return .yellow
            case 40..<60: return .orange
            case 60..<80: return .red
            case 80..<100: return .purple
            default: return .brown
            }
        }
    }

    static func moonPhaseSymbol(phase: MoonPhase) -> String {
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
}
