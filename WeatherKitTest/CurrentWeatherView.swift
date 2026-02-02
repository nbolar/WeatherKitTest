import SwiftUI
import WeatherKit

// MARK: - Current Weather View

struct CurrentWeatherView: View {
    let weather: CurrentWeather
    let locationName: String?
    let dailyForecast: DayWeather?
    let alerts: [WeatherAlert]
    let locationTimeZone: TimeZone?
    let airQuality: AirQualitySnapshot?
    let hourlyForecast: [HourWeather]
    let aiSummaryShort: String?
    let aiSummaryLong: String?
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    var body: some View {
        VStack(spacing: 12) {
            // Weather Alerts
            if !alerts.isEmpty {
                ForEach(Array(alerts.enumerated()), id: \.element.summary) { index, alert in
                    WeatherAlertBanner(alert: alert, alertIndex: index, totalAlerts: alerts.count)
                        .id("\(alert.summary)-\(index)")
                }
            }

            // Today's Summary
            TodaySummaryCard(
                weather: weather,
                dailyForecast: dailyForecast,
                hourlyForecast: hourlyForecast,
                timeZone: locationTimeZone,
                aiShort: aiSummaryShort,
                aiLong: aiSummaryLong
            )

            mainTemperatureCard

            // Weather Metrics
            compactMetricsStack

            // Air Quality
            airQualityCard(airQuality)
            
            // UV Index
            uvIndexCard

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
        .background(GlassMorphicBackground())
        .cornerRadius(16)
    }

    private var uvIndexCard: some View {
        let currentUV = weather.uvIndex.value
        let category = weather.uvIndex.category.description
        let peak = peakUVHour()
        let dailyPeak = dailyForecast?.uvIndex.value
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 8) {
                    Text("UV Index")
                        .font(.headline)
                        .foregroundColor(.white)
                }
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
            
            Text(uvGuidance(for: currentUV))
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(12)
        .background(GlassMorphicBackground())
        .cornerRadius(16)
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
        case 0...2:
            return "No extra protection needed. Enjoy your time outside."
        case 3...5:
            return "Wear sunglasses and SPF if you’ll be out for a while."
        case 6...7:
            return "Seek shade during midday and use SPF 30+."
        case 8...10:
            return "Limit midday sun, cover up, and reapply SPF."
        default:
            return "Avoid midday sun. Protective clothing and SPF are a must."
        }
    }
    
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
    
    private func moonPhaseIcon(for phase: WeatherKit.MoonPhase) -> String {
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

struct TodaySummaryCard: View {
    let weather: CurrentWeather
    let dailyForecast: DayWeather?
    let hourlyForecast: [HourWeather]
    let timeZone: TimeZone?
    let aiShort: String?
    let aiLong: String?
    @State private var isExpanded = false
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
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
                    
                    Text(aiLong ?? detailedSummary)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background(GlassMorphicBackground())
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    private var shortSummary: String {
        let condition = weather.condition.description
        let highLow = dailyHighLowText()
        let precip = nextPrecipWindow()
        let wind = peakWindText()
        
        var parts: [String] = []
        parts.append(condition)
        if !highLow.isEmpty { parts.append(highLow) }
        if let precip { parts.append(precip) }
        if let wind { parts.append(wind) }
        
        return parts.joined(separator: " • ")
    }
    
    private var detailedSummary: String {
        var sentences: [String] = []
        
        if let dailyForecast {
            sentences.append("Expect a high around \(formatTemp(dailyForecast.highTemperature)) and a low near \(formatTemp(dailyForecast.lowTemperature)).")
        }
        
        if let trend = temperatureTrendText() {
            sentences.append(trend)
        }
        
        if let precip = maxPrecipChance() {
            let window = precipTimeRange() ?? "today"
            sentences.append("Rain chances top out near \(Int(precip * 100))% \(window).")
        }
        
        if let wind = maxWindSpeed() {
            sentences.append("It gets breeziest around \(wind.time), topping out near \(wind.value).")
        }
        
        if let parts = dayPartSummaryText() {
            sentences.append(parts)
        }
        
        if sentences.isEmpty {
            sentences.append("Looks steady overall.")
        }
        
        let trimmed = Array(sentences.prefix(4))
        return trimmed.isEmpty ? "Looks steady overall." : trimmed.joined(separator: " ")
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
        let threshold = 0.2
        let hours = next.filter { $0.precipitationChance >= threshold }
        guard let first = hours.first, let last = hours.last else { return nil }
        return "between \(formatHour(first.date)) and \(formatHour(last.date))"
    }
    
    private func peakWindText() -> String? {
        let next = hourlyForecast.prefix(12)
        guard let maxHour = next.max(by: { $0.wind.speed.value < $1.wind.speed.value }),
              maxHour.wind.speed.value > 5 else {
            return nil
        }
        return "Wind up to \(maxHour.wind.speed.formatted())"
    }
    
    private func maxWindSpeed() -> (value: String, time: String)? {
        let next = hourlyForecast.prefix(24)
        guard let maxHour = next.max(by: { $0.wind.speed.value < $1.wind.speed.value }) else { return nil }
        return (maxHour.wind.speed.formatted(), formatHour(maxHour.date))
    }
    
    private func temperatureTrendText() -> String? {
        let next = hourlyForecast.prefix(24)
        guard let minHour = next.min(by: { $0.temperature.value < $1.temperature.value }),
              let maxHour = next.max(by: { $0.temperature.value < $1.temperature.value }) else { return nil }
        
        let minTime = formatHour(minHour.date)
        let maxTime = formatHour(maxHour.date)
        let minTemp = formatTemp(minHour.temperature)
        let maxTemp = formatTemp(maxHour.temperature)
        
        if minHour.date < maxHour.date {
            return "You’ll start cooler around \(minTime) near \(minTemp), then warm up to about \(maxTemp) by \(maxTime)."
        } else {
            return "It starts warmer around \(maxTime) near \(maxTemp), then eases down toward \(minTemp) by \(minTime)."
        }
    }
    
    private func dayPartSummaryText() -> String? {
        guard !hourlyForecast.isEmpty else { return nil }
        let morning = nearestHour(to: 9)
        let afternoon = nearestHour(to: 15)
        let evening = nearestHour(to: 21)
        
        var parts: [String] = []
        if let morning {
            parts.append("Morning looks \(morning.condition.description.lowercased()) around \(formatTemp(morning.temperature)).")
        }
        if let afternoon {
            parts.append("By afternoon it’s \(afternoon.condition.description.lowercased()) near \(formatTemp(afternoon.temperature)).")
        }
        if let evening {
            parts.append("Evening stays \(evening.condition.description.lowercased()) around \(formatTemp(evening.temperature)).")
        }
        return parts.isEmpty ? nil : parts.prefix(2).joined(separator: " ")
    }
    
    private func nearestHour(to hour: Int) -> HourWeather? {
        let calendar = Calendar(identifier: .gregorian)
        var cal = calendar
        cal.timeZone = timeZone ?? .current
        return hourlyForecast.prefix(24).min(by: {
            abs(cal.component(.hour, from: $0.date) - hour) < abs(cal.component(.hour, from: $1.date) - hour)
        })
    }
    
    private func formatTemp(_ temp: Measurement<UnitTemperature>) -> String {
        if useCelsius {
            return "\(Int(temp.converted(to: .celsius).value.rounded()))°C"
        }
        return "\(Int(temp.converted(to: .fahrenheit).value.rounded()))°F"
    }
    
    private func formatHour(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        formatter.timeZone = timeZone ?? .current
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
