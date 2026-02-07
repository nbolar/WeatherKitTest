import SwiftUI
import WeatherKit
import Charts

// MARK: - Current Weather View

struct CurrentWeatherView: View {
    let weather: CurrentWeather
    let locationName: String?
    let isCurrentLocation: Bool
    let dailyForecast: DayWeather?
    let alerts: [WeatherAlert]
    let locationTimeZone: TimeZone?
    let airQuality: AirQualitySnapshot?
    let hourlyForecast: [HourWeather]
    let minuteForecast: Forecast<MinuteWeather>?
    let aiSummaryStatus: String?
    let aiSummaryShort: String?
    let aiSummaryLong: String?

    @AppStorage("useCelsius") private var useCelsius: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            if !alerts.isEmpty {
                ForEach(Array(alerts.enumerated()), id: \.element.summary) { index, alert in
                    WeatherAlertBanner(alert: alert, alertIndex: index, totalAlerts: alerts.count)
                        .id("\(alert.summary)-\(index)")
                }
            }

            TodaySummaryCard(
                weather: weather,
                dailyForecast: dailyForecast,
                hourlyForecast: hourlyForecast,
                timeZone: locationTimeZone,
                aiShort: aiSummaryShort,
                aiLong: aiSummaryLong,
                aiStatus: aiSummaryStatus
            )

            mainTemperatureCard

            minutePrecipitationCard(minuteForecast)

            compactMetricsStack

            airQualityCard(airQuality)

            uvIndexCard

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
            if let locationName {
                HStack {
                    if isCurrentLocation {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    Text(locationName)
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }

            Image(systemName: weather.symbolName)
                .font(.system(size: 60))
                .foregroundColor(.white)
                .symbolRenderingMode(.hierarchical)
                .padding(.vertical, 4)

            Text("\(formattedTemperature(weather.temperature))°")
                .font(.system(size: 56, weight: .thin))
                .foregroundColor(.white)

            Text(weather.condition.description)
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))

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
        .liquidGlassCard()
    }

    // MARK: - Minute-by-minute precipitation (Current tab)
    @ViewBuilder
    private func minutePrecipitationCard(_ minuteForecast: Forecast<MinuteWeather>?) -> some View {
        if let minuteForecast {
            let minutes = Array(minuteForecast.prefix(60))
            if !minutes.isEmpty {
                let maxIntensity = minutes.map { $0.precipitationIntensity.value }.max() ?? 0
                let showThreshold = 0.05
                let wetMinutes = minutes.filter { $0.precipitationIntensity.value >= showThreshold }
                if maxIntensity >= showThreshold, wetMinutes.count >= 2 {
                    minutePrecipContent(minutes: minutes, maxIntensity: maxIntensity)
                }
            }
        }
    }

    private func minutePrecipContent(minutes: [MinuteWeather], maxIntensity: Double) -> some View {
        let peak = minutes.max(by: { $0.precipitationIntensity.value < $1.precipitationIntensity.value })
        let statusText: String = {
            if let peak {
                return "Heaviest around \(formatTime(peak.date))."
            }
            return "Precipitation possible in the next hour."
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Next Hour Precipitation")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text(String(format: "%.2f mm/hr", maxIntensity))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(Color.cyan.opacity(0.25))
                    )
            }

            Text(statusText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))

            minutePrecipBarRow(minutes: minutes, maxIntensity: maxIntensity)
        }
        .padding(12)
        .liquidGlassCard()
    }

    private func minutePrecipBarRow(minutes: [MinuteWeather], maxIntensity: Double) -> some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                let height = proxy.size.height
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(minutes, id: \.date) { minute in
                        let value = minute.precipitationIntensity.value
                        let ratio = maxIntensity > 0 ? min(value / maxIntensity, 1.0) : 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.cyan.opacity(0.7))
                            .frame(height: max(2, height * ratio))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: 70)

            HStack {
                Text(formatHourLabel(minutes.first?.date))
                Spacer()
                Text(formatHourLabel(minutes.dropFirst(15).first?.date))
                Spacer()
                Text(formatHourLabel(minutes.dropFirst(30).first?.date))
                Spacer()
                Text(formatHourLabel(minutes.dropFirst(45).first?.date))
                Spacer()
                Text(formatHourLabel(minutes.last?.date))
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
        }
    }

    private func formatHourLabel(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = locationTimeZone ?? .current
        return formatter.string(from: date)
    }

    // MARK: - Compact metrics
    private var compactMetricsStack: some View {
        VStack(spacing: 8) {
            MetricRow(icon: "wind", label: "Wind", value: weather.wind.speed.formatted())
            MetricRow(icon: "thermometer.medium", label: "Feels Like", value: "\(formattedTemperature(weather.apparentTemperature))°")
            MetricRow(icon: "humidity.fill", label: "Humidity", value: "\(Int(weather.humidity * 100))%")
            MetricRow(icon: "eye.fill", label: "Visibility", value: formatVisibility(weather.visibility))
            MetricRow(icon: "gauge.with.dots.needle.33percent", label: "Pressure", value: formatPressure(weather.pressure))
        }
        .padding(12)
        .liquidGlassCard()
    }

    // MARK: - Sun & Moon Card
    private var sunMoonCard: some View {
        VStack(spacing: 12) {
            if let sun = dailyForecast?.sun {
                HStack(spacing: 12) {
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

            if let moonPhase = dailyForecast?.moon.phase {
                HStack(spacing: 8) {
                    Image(systemName: moonPhaseSymbol(phase: moonPhase))
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
        .liquidGlassCard()
    }

    // MARK: - Air Quality Card
    private func airQualityCard(_ air: AirQualitySnapshot?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let aqiValue = air?.usAQI ?? air?.europeanAQI
            let scale = air?.scale ?? (air?.usAQI != nil ? .us : (air?.europeanAQI != nil ? .eu : nil))

            HStack {
                Text("Air Quality")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let aqi = aqiValue {
                    let label = scale == .eu ? "EU AQI" : "US AQI"
                    Text("\(label) \(Int(aqi.rounded()))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(aqiColor(aqi, scale: scale ?? .us).opacity(0.35))
                        )
                }
            }

            if let aqi = aqiValue, let scale {
                Text(aqiCategory(aqi, scale: scale))
                    .font(.caption)
                    .foregroundColor(aqiColor(aqi, scale: scale))
                AQIBar(value: aqi, scale: scale)
            } else if air == nil {
                Text("Air quality loading…")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text("AQI unavailable for this location")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 12) {
                airMetric("PM2.5", air?.pm25, unit: air?.units.pm25)
                airMetric("PM10", air?.pm10, unit: air?.units.pm10)
                airMetric("O3", air?.ozone, unit: air?.units.ozone)
            }

            HStack(spacing: 12) {
                airMetric("NO2", air?.nitrogenDioxide, unit: air?.units.nitrogenDioxide)
                airMetric("SO2", air?.sulphurDioxide, unit: air?.units.sulphurDioxide)
                airMetric("CO", air?.carbonMonoxide, unit: air?.units.carbonMonoxide)
            }
        }
        .padding(12)
        .liquidGlassCard()
    }

    // MARK: - UV Index Card
    private var uvIndexCard: some View {
        let currentUV = weather.uvIndex.value
        let category = weather.uvIndex.category.description
        let peak = peakUVHour()
        let dailyPeak = dailyForecast?.uvIndex.value
        let clearSkyUV = airQuality?.uvIndexClearSky
        let hazeValue = airQuality?.aerosolOpticalDepth

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("UV Index")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(Int(currentUV))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        Capsule()
                            .fill(uvIndexColor(for: currentUV).opacity(0.30))
                    )
            }

            Text(category)
                .font(.caption)
                .foregroundColor(uvIndexColor(for: currentUV))

            uvGauge(value: Double(currentUV) / 11.0, color: uvIndexColor(for: currentUV))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Peak today")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    if let dailyPeak {
                        Text("\(Int(dailyPeak)) \(uvCategoryName(for: Int(dailyPeak)))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    } else {
                        Text("--")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Peak hour")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    if let peak {
                        Text("\(Int(peak.value)) around \(formatTime(peak.date))")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    } else {
                        Text("--")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                }
            }

            if let clearSkyUV {
                if clearSkyUV <= 0.1 {
                    Text("Clear-sky UV 0 • Nighttime")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                } else {
                    let reduction = max(0.0, min(1.0, (clearSkyUV - Double(currentUV)) / clearSkyUV))
                    Text("Clear-sky UV \(Int(clearSkyUV.rounded())) • Clouds reduce about \(Int((reduction * 100).rounded()))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
            } else {
                Text("Clear-sky UV unavailable")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            if let hazeValue {
                Text("Haze: \(hazeCategory(for: hazeValue)) (AOD \(String(format: "%.2f", hazeValue)))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            } else {
                Text("Haze data unavailable")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(uvGuidance(for: currentUV))
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(12)
        .liquidGlassCard()
    }

    // MARK: - Helper components
    private func airMetric(_ label: String, _ value: Double?, unit: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            Text(formatAirValue(value, unit: unit))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatAirValue(_ value: Double?, unit: String?) -> String {
        guard let value else { return "--" }
        if let unit {
            return String(format: "%.1f %@", value, unit)
        }
        return String(format: "%.1f", value)
    }

    private func aqiCategory(_ aqi: Double, scale: AirQualityScale) -> String {
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

    private func aqiColor(_ aqi: Double, scale: AirQualityScale) -> Color {
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

    private func uvGauge(value: Double, color: Color) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: width * min(max(value, 0), 1), height: 6)
            }
        }
        .frame(height: 6)
    }

    private func peakUVHour() -> (value: Double, date: Date)? {
        let upcoming = hourlyForecast.prefix(24)
        guard let best = upcoming.max(by: { $0.uvIndex.value < $1.uvIndex.value }) else {
            return nil
        }
        return (Double(best.uvIndex.value), best.date)
    }

    private func uvCategoryName(for value: Int) -> String {
        switch value {
        case 0...2: return "Low"
        case 3...5: return "Moderate"
        case 6...7: return "High"
        case 8...10: return "Very High"
        default: return "Extreme"
        }
    }

    private func uvGuidance(for value: Int) -> String {
        switch value {
        case 0...2: return "No extra protection needed. Enjoy your time outside."
        case 3...5: return "Wear sunglasses and SPF if you’ll be out for a while."
        case 6...7: return "Seek shade during midday and use SPF 30+."
        case 8...10: return "Limit midday sun, cover up, and reapply SPF."
        default: return "Avoid midday sun. Protective clothing and SPF are a must."
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

    private func hazeCategory(for value: Double) -> String {
        switch value {
        case ..<0.10: return "Very Clear"
        case 0.10..<0.20: return "Clear"
        case 0.20..<0.40: return "Hazy"
        case 0.40..<0.70: return "Smoky"
        default: return "Very Smoky"
        }
    }

    private func moonPhaseSymbol(phase: MoonPhase) -> String {
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

    private func formattedTemperature(_ temperature: Measurement<UnitTemperature>) -> Int {
        let value = useCelsius ? temperature.converted(to: .celsius).value : temperature.converted(to: .fahrenheit).value
        return Int(value.rounded())
    }

    private func formatVisibility(_ distance: Measurement<UnitLength>) -> String {
        let value = useCelsius ? distance.converted(to: .kilometers).value : distance.converted(to: .miles).value
        let unit = useCelsius ? "km" : "mi"
        return "\(String(format: "%.0f", value)) \(unit)"
    }

    private func formatPressure(_ pressure: Measurement<UnitPressure>) -> String {
        let value = pressure.converted(to: .hectopascals).value
        return "\(Int(value.rounded())) hPa"
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = locationTimeZone ?? .current
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views

struct TodaySummaryCard: View {
    let weather: CurrentWeather
    let dailyForecast: DayWeather?
    let hourlyForecast: [HourWeather]
    let timeZone: TimeZone?
    let aiShort: String?
    let aiLong: String?
    let aiStatus: String?

    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Today")
                        .font(.headline)
                        .foregroundColor(.white)

                    if isExpanded, aiLong != nil {
                        Image(systemName: "sparkles")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(shortSummary)
                    .font(.callout.weight(.medium))
                    .foregroundColor(.white.opacity(0.95))

                if isExpanded {
                    GlassDivider(opacity: 0.12)

                    aiExpandedContent
                    
                }
            }
            .padding(12)
            .contentShape(Rectangle())
            .liquidGlassCard()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var aiExpandedContent: some View {
        if let aiLong {
            Text(aiLong)
                .font(.callout)
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        } else if let aiShort, aiStatus == "AI summary ready." {
            Text(aiShort)
                .font(.callout)
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        } else if let status = aiStatus, status.lowercased().contains("failed") || status.lowercased().contains("unavailable") {
            Text("AI summary unavailable right now.")
                .font(.callout)
                .foregroundColor(.white.opacity(0.7))
            aiStatusLine
        } else {
            Text("Generating summary…")
                .font(.callout)
                .foregroundColor(.white.opacity(0.7))
            aiStatusLine
        }
    }

    private var aiStatusLine: some View {
        Group {
            if let status = aiStatus, !status.isEmpty {
                Text(status)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    private var shortSummary: String {
        if let aiShort, !aiShort.isEmpty {
            return aiShort
        }
        let condition = weather.condition.description
        if let dailyForecast {
            return "\(condition) today with a high around \(formatTemp(dailyForecast.highTemperature)) and a low near \(formatTemp(dailyForecast.lowTemperature))."
        }
        return "\(condition) today."
    }

    private var detailedSummary: String {
        var sentences: [String] = []

        if let dailyForecast {
            sentences.append("Expect a high around \(formatTemp(dailyForecast.highTemperature)) and a low near \(formatTemp(dailyForecast.lowTemperature)).")
        }

        if let precip = maxPrecipChance() {
            let window = precipTimeRange() ?? "today"
            sentences.append("Rain chances top out near \(Int(precip * 100))% \(window).")
        }

        if let wind = maxWindSpeed() {
            sentences.append("It gets breeziest around \(wind.time), topping out near \(wind.value).")
        }

        if sentences.isEmpty {
            sentences.append("Looks steady overall.")
        }

        return sentences.prefix(4).joined(separator: " ")
    }

    private func dailyHighLowText() -> String {
        guard let dailyForecast else { return "" }
        return "H \(formatTemp(dailyForecast.highTemperature)) / L \(formatTemp(dailyForecast.lowTemperature))"
    }

    private func nextPrecipWindow() -> String? {
        let next = hourlyForecast.prefix(12)
        guard let maxHour = next.max(by: { $0.precipitationChance < $1.precipitationChance }),
              maxHour.precipitationChance >= 0.2 else {
            return nil
        }
        return "\(Int(maxHour.precipitationChance * 100))% chance near \(formatHour(maxHour.date))"
    }

    private func maxPrecipChance() -> Double? {
        let next = hourlyForecast.prefix(24)
        return next.map(\.precipitationChance).max()
    }

    private func precipTimeRange() -> String? {
        let next = hourlyForecast.prefix(24)
        let threshold = 0.25
        let hours = next.filter { $0.precipitationChance >= threshold }
        guard let first = hours.first, let last = hours.last else { return nil }
        return "from \(formatHour(first.date)) to \(formatHour(last.date))"
    }

    private func maxWindSpeed() -> (value: String, time: String)? {
        let next = hourlyForecast.prefix(24)
        guard let maxHour = next.max(by: { $0.wind.speed.value < $1.wind.speed.value }) else { return nil }
        let speed = maxHour.wind.speed.formatted()
        let time = formatHour(maxHour.date)
        return (speed, time)
    }

    private func peakWindText() -> String? {
        guard let peak = maxWindSpeed() else { return nil }
        return "Wind peaks near \(peak.value) around \(peak.time)"
    }

    private func formatTemp(_ temp: Measurement<UnitTemperature>) -> Int {
        let celsius = temp.converted(to: .celsius).value
        let value = useCelsius ? celsius : (celsius * 9.0 / 5.0 + 32.0)
        return Int(value.rounded())
    }

    private var useCelsius: Bool {
        UserDefaults.standard.bool(forKey: "useCelsius")
    }

    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        formatter.timeZone = timeZone ?? .current
        return formatter.string(from: date)
    }
}

struct AQIBar: View {
    let value: Double
    let scale: AirQualityScale

    private var clamped: Double {
        min(max(value, 0), scale == .eu ? 100 : 500)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(width: width * (clamped / (scale == .eu ? 100.0 : 500.0)), height: 6)
            }
        }
        .frame(height: 6)
    }

    private var barColor: Color {
        switch scale {
        case .us:
            switch clamped {
            case ..<51: return .green
            case 51..<101: return .yellow
            case 101..<151: return .orange
            case 151..<201: return .red
            case 201..<301: return .purple
            default: return .brown
            }
        case .eu:
            switch clamped {
            case ..<20: return .green
            case 20..<40: return .yellow
            case 40..<60: return .orange
            case 60..<80: return .red
            case 80..<100: return .purple
            default: return .brown
            }
        }
    }
}

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
