import SwiftUI
import WeatherKit

// MARK: - Forecast Views

struct HourlyForecastView: View {
    let hourlyForecast: [HourWeather]
    @State private var expandedDate: Date? = nil
    
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
                        let isExpanded = expandedDate == hour.date
                        VStack(spacing: 0) {
                            HourlyWeatherRow(hourWeather: hour, isExpanded: isExpanded)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                                        expandedDate = isExpanded ? nil : hour.date
                                    }
                                }
                            if isExpanded {
                                GlassDivider(opacity: 0.16)
                                    .padding(.horizontal, 10)
                                    .transition(.opacity)
                                HourlyWeatherDetailRow(hourWeather: hour)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 8)
                                    .padding(.bottom, 10)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                                    ))
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
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
    let isExpanded: Bool
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
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.65))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: isExpanded)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
    
    private func formattedTemperature(_ temp: Measurement<UnitTemperature>) -> Int {
        if useCelsius {
            return Int(temp.converted(to: .celsius).value)
        } else {
            return Int(temp.converted(to: .fahrenheit).value)
        }
    }
}

struct HourlyWeatherDetailRow: View {
    let hourWeather: HourWeather
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            DetailPill(icon: "thermometer.medium", text: "Feels \(formattedTemperature(hourWeather.apparentTemperature))°")
            DetailPill(icon: "drop.fill", text: "Hum \(percentString(hourWeather.humidity))")
            DetailPill(icon: "cloud.fill", text: "Cloud \(percentString(hourWeather.cloudCover))")
            DetailPill(icon: "eye.fill", text: "Vis \(formatVisibility(hourWeather.visibility))")
            DetailPill(icon: "cloud.rain.fill", text: "Precip \(formatPrecip(hourWeather.precipitationAmount))")
            DetailPill(icon: "sun.max.fill", text: "UV \(hourWeather.uvIndex.value)")
        }
        .padding(.horizontal, 12)
    }
    
    private func formattedTemperature(_ temp: Measurement<UnitTemperature>) -> Int {
        if useCelsius {
            return Int(temp.converted(to: .celsius).value)
        } else {
            return Int(temp.converted(to: .fahrenheit).value)
        }
    }
    
    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
    
    private func formatVisibility(_ visibility: Measurement<UnitLength>) -> String {
        let km = visibility.converted(to: .kilometers).value
        if km >= 10 {
            return String(format: "%.0f km", km)
        } else {
            return String(format: "%.1f km", km)
        }
    }
    
    private func formatPrecip(_ amount: Measurement<UnitLength>) -> String {
        let mm = amount.converted(to: .millimeters).value
        if mm >= 10 {
            return String(format: "%.0f mm", mm)
        } else {
            return String(format: "%.1f mm", mm)
        }
    }
}

struct DetailPill: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.10))
        )
    }
}

struct DailyForecastView: View {
    let dailyForecast: [DayWeather]
    let hourlyForecast: [HourWeather]
    let locationTimeZone: TimeZone?
    @State private var expandedDate: Date? = nil
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
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
                        let isExpanded = expandedDate == day.date
                        VStack(spacing: 0) {
                            DailyWeatherRow(dayWeather: day, isExpanded: isExpanded)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                                        expandedDate = isExpanded ? nil : day.date
                                    }
                                }
                            
                            if isExpanded {
                                GlassDivider(opacity: 0.16)
                                    .padding(.horizontal, 10)
                                    .transition(.opacity)
                                
                                DailySunMoonDetail(
                                    dayWeather: day,
                                    timeZone: locationTimeZone,
                                    feelsLikeText: feelsLikeRangeText(for: day)
                                )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.top, 8)
                                    .padding(.bottom, 10)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                                        removal: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
                                    ))
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func feelsLikeRangeText(for day: DayWeather) -> String? {
        let calendar = Calendar(identifier: .gregorian)
        var calendarWithZone = calendar
        calendarWithZone.timeZone = locationTimeZone ?? .current
        
        let dayComponents = calendarWithZone.dateComponents([.year, .month, .day], from: day.date)
        let matchingHours = hourlyForecast.filter { hour in
            let hourComponents = calendarWithZone.dateComponents([.year, .month, .day], from: hour.date)
            return hourComponents.year == dayComponents.year
                && hourComponents.month == dayComponents.month
                && hourComponents.day == dayComponents.day
        }
        
        guard !matchingHours.isEmpty else { return nil }
        
        let values = matchingHours.map { hour -> Double in
            let temp = hour.apparentTemperature
            if useCelsius {
                return temp.converted(to: .celsius).value
            }
            return temp.converted(to: .fahrenheit).value
        }
        
        guard let minValue = values.min(), let maxValue = values.max() else { return nil }
        let low = Int(minValue.rounded())
        let high = Int(maxValue.rounded())
        return "Feels \(low)° / \(high)°"
    }
}

struct DailyWeatherRow: View {
    let dayWeather: DayWeather
    let isExpanded: Bool
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
                if dayWeather.precipitationChance > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "drop.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(Int(dayWeather.precipitationChance * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.white)
                    }
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
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.65))
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .animation(.easeInOut(duration: 0.15), value: isExpanded)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
    
    private func formattedTemperature(_ temp: Measurement<UnitTemperature>) -> Int {
        if useCelsius {
            return Int(temp.converted(to: .celsius).value)
        } else {
            return Int(temp.converted(to: .fahrenheit).value)
        }
    }
    
}

struct DailySunMoonDetail: View {
    let dayWeather: DayWeather
    let timeZone: TimeZone?
    let feelsLikeText: String?
    
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                detailItem(
                    icon: "sunrise.fill",
                    label: "Sunrise",
                    value: formattedTime(dayWeather.sun.sunrise)
                )
                detailItem(
                    icon: "sunset.fill",
                    label: "Sunset",
                    value: formattedTime(dayWeather.sun.sunset)
                )
            }
            
            HStack(spacing: 12) {
                detailItem(
                    icon: "moonrise.fill",
                    label: "Moonrise",
                    value: formattedTime(dayWeather.moon.moonrise)
                )
                detailItem(
                    icon: "moonset.fill",
                    label: "Moonset",
                    value: formattedTime(dayWeather.moon.moonset)
                )
            }
            
            HStack(spacing: 10) {
                detailBadge(
                    icon: moonPhaseIcon(for: dayWeather.moon.phase),
                    text: dayWeather.moon.phase.description,
                    tint: .yellow
                )
                Spacer()
                // Removed illumination badge as MoonEvents has no illumination
            }
            
            HStack(spacing: 10) {
                detailBadge(
                    icon: "wind",
                    text: formatWind(dayWeather.wind),
                    tint: .cyan
                )
                detailBadge(
                    icon: "sun.max.fill",
                    text: "UV \(dayWeather.uvIndex.value) \(dayWeather.uvIndex.category.description)",
                    tint: .yellow
                )
                if let feelsLikeText {
                    detailBadge(
                        icon: "thermometer.medium",
                        text: feelsLikeText,
                        tint: .orange
                    )
                }
                Spacer()
            }
            
            VStack(spacing: 8) {
                DayPartDetailRow(title: "Day", part: dayWeather.daytimeForecast)
                DayPartDetailRow(title: "Night", part: dayWeather.overnightForecast)
            }
            
            SunPathView(
                sunrise: dayWeather.sun.sunrise,
                sunset: dayWeather.sun.sunset,
                timeZone: timeZone
            )
        }
        .padding(.horizontal, 12)
    }
    
    @ViewBuilder
    private func detailItem(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .opacity(0.5)
        )
    }
    
    private func detailBadge(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(tint)
                .symbolRenderingMode(.hierarchical)
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
        )
    }
    
    private func formattedTime(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone ?? .current
        return formatter.string(from: date)
    }
    
    private func formatWind(_ wind: Wind) -> String {
        let speed = wind.speed.formatted()
        let directionDegrees = wind.direction.converted(to: .degrees).value
        let direction = compassDirection(from: directionDegrees)
        if let gust = wind.gust {
            return "\(speed) \(direction) • Gust \(gust.formatted())"
        }
        return "\(speed) \(direction)"
    }
    
    private func compassDirection(from degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let normalized = (degrees.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        let index = Int((normalized / 22.5).rounded()) % directions.count
        return directions[index]
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
}

struct DayPartDetailRow: View {
    let title: String
    let part: DayPartForecast
    
    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 42, alignment: .leading)
            
            Text(part.condition.description)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 10) {
                labelValue(icon: "drop.fill", value: percentString(part.precipitationChance))
                labelValue(icon: "wind", value: part.wind.speed.formatted())
                labelValue(icon: "cloud.fill", value: percentString(part.cloudCover))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    private func labelValue(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
            Text(value)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }
}

struct SunPathView: View {
    let sunrise: Date?
    let sunset: Date?
    let timeZone: TimeZone?
    
    private var progress: Double {
        guard
            let sunrise,
            let sunset,
            sunset > sunrise
        else { return 0 }
        let now = Date()
        if now <= sunrise { return 0 }
        if now >= sunset { return 1 }
        return now.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sun path")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
            
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                
                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 4, y: height - 4))
                        path.addQuadCurve(
                            to: CGPoint(x: width - 4, y: height - 4),
                            control: CGPoint(x: width / 2, y: 4)
                        )
                    }
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    
                    if sunrise != nil, sunset != nil {
                        let progressValue = CGFloat(progress)
                        let x = 4 + (width - 8) * progressValue
                        let y = (height - 4) - (height - 8) * CGFloat(sin(.pi * Double(progressValue)))
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                            .shadow(color: .orange.opacity(0.5), radius: 4, x: 0, y: 0)
                    }
                }
            }
            .frame(height: 28)
            
            HStack {
                Text(formattedTime(sunrise))
                Spacer()
                Text(formattedTime(sunset))
            }
            .font(.caption2)
            .foregroundColor(.white.opacity(0.7))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    private func formattedTime(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = timeZone ?? .current
        return formatter.string(from: date)
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
