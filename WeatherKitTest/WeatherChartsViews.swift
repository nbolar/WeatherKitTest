import SwiftUI
import WeatherKit
import Charts

// MARK: - Weather Charts Views

struct WeatherChartsView: View {
    let hourlyForecast: [HourWeather]
    let minuteForecast: Forecast<MinuteWeather>?
    let airQuality: AirQualitySnapshot?
    let airQualityHourly: [AirQualityHourPoint]
    @AppStorage("useCelsius") private var useCelsius: Bool = false

    private var shouldShowMinutePrecip: Bool {
        guard let minuteForecast else { return false }
        let minutes = Array(minuteForecast.forecast.prefix(60))
        guard !minutes.isEmpty else { return false }
        let maxIntensity = minutes.map { $0.precipitationIntensity.value }.max() ?? 0
        let wetMinutes = minutes.filter { $0.precipitationIntensity.value >= 0.1 }
        return maxIntensity >= 0.1 && wetMinutes.count >= 2
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Weather Charts")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            if let airQuality {
                AirQualityChartCard(airQuality: airQuality, hourly: airQualityHourly)
            }
            
            // Temperature Chart
            TemperatureChartView(hourlyForecast: hourlyForecast, useCelsius: useCelsius)
            
            // Feels Like Temperature Chart
            FeelsLikeChartView(hourlyForecast: hourlyForecast, useCelsius: useCelsius)
            
            // Precipitation Chart
            PrecipitationChartView(hourlyForecast: hourlyForecast)
            
            // Minute-by-minute precipitation
            if shouldShowMinutePrecip, let minuteForecast = minuteForecast {
                MinutePrecipitationView(minuteForecast: minuteForecast)
            }
            
            // Wind Speed Chart
            WindSpeedChartView(hourlyForecast: hourlyForecast)
            
        }
        .padding(.bottom)
    }
}

struct AirQualityChartCard: View {
    let airQuality: AirQualitySnapshot
    let hourly: [AirQualityHourPoint]
    @State private var selectedDate: Date? = nil
    @State private var selectedElement: Date? = nil
    
    private var selectedPoint: AirQualityHourPoint? {
        guard let date = selectedElement ?? selectedDate else { return nil }
        return hourly.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let scale = hourly.first?.scale ?? airQuality.scale ?? .us
            let label = scale == .eu ? "EU AQI" : "US AQI"
            let accentValue = selectedPoint?.usAQI ?? airQuality.usAQI ?? airQuality.europeanAQI ?? hourly.last?.usAQI ?? 0
            let accentColor = aqiColor(accentValue, scale: scale)
            let segments = aqiSegments(for: hourly, scale: scale)
            
            HStack {
                Text("Air Quality (\(label))")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                if let aqi = airQuality.usAQI ?? airQuality.europeanAQI {
                    Text("Now \(Int(aqi.rounded()))")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            Capsule()
                                .fill(aqiColor(aqi, scale: scale).opacity(0.35))
                        )
                }
            }
            
            if hourly.isEmpty {
                Text(airQuality.usAQI == nil ? "AQI unavailable for this location" : "No air quality history available")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Chart {
                    // Severity-colored line segments.
                    ForEach(segments) { segment in
                        if segment.points.count >= 2 {
                            ForEach(segment.points) { point in
                                LineMark(
                                    x: .value("Time", point.date),
                                    y: .value("AQI", point.usAQI)
                                )
                                .foregroundStyle(segment.color.gradient)
                                .interpolationMethod(.catmullRom)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                            }
                        }
                    }
                    
                    // Severity-colored points.
                    ForEach(hourly) { point in
                        PointMark(
                            x: .value("Time", point.date),
                            y: .value("AQI", point.usAQI)
                        )
                        .foregroundStyle(aqiColor(point.usAQI, scale: scale))
                        .symbolSize(18)
                    }
                    
                    if let selected = selectedPoint {
                        RuleMark(x: .value("Time", selected.date))
                            .foregroundStyle(Color.white.opacity(0.3))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                            .annotation(position: .top, spacing: 16, overflowResolution: .init(x: .fit, y: .fit)) {
                                ChartPopover {
                                    VStack(spacing: 6) {
                                        Text(selected.date.formatted(date: .omitted, time: .shortened))
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.8))
                                        Text("\(Int(selected.usAQI.rounded()))")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(aqiColor(selected.usAQI, scale: scale))
                                    }
                                    .frame(width: 100)
                                }
                            }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 4)) { value in
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
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        let positions = hourly.compactMap { point -> (AirQualityHourPoint, CGPoint)? in
                            guard let x = proxy.position(forX: point.date),
                                  let y = proxy.position(forY: point.usAQI) else {
                                return nil
                            }
                            return (point, CGPoint(x: x, y: y))
                        }
                        
                        if positions.count >= 2 {
                            let baselineY = proxy.position(forY: 0) ?? geo.size.height
                            let stops = positions.map { entry -> Gradient.Stop in
                                let x = max(0, min(1, entry.1.x / max(1, geo.size.width)))
                                return Gradient.Stop(
                                    color: aqiColor(entry.0.usAQI, scale: scale).opacity(0.25),
                                    location: x
                                )
                            }
                            
                            let gradient = LinearGradient(
                                gradient: Gradient(stops: stops),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            
                            Path { path in
                                path.move(to: CGPoint(x: positions[0].1.x, y: baselineY))
                                for entry in positions {
                                    path.addLine(to: entry.1)
                                }
                                path.addLine(to: CGPoint(x: positions.last!.1.x, y: baselineY))
                                path.closeSubpath()
                            }
                            .fill(gradient)
                            .allowsHitTesting(false)
                        }
                    }
                }
                .chartXSelection(value: $selectedElement)
                .frame(height: 180)
                .padding(.top, 6)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal)
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
    
    private struct AQISegment: Identifiable {
        let id = UUID()
        let color: Color
        let points: [AirQualityHourPoint]
    }
    
    private func aqiSegments(for points: [AirQualityHourPoint], scale: AirQualityScale) -> [AQISegment] {
        var segments: [AQISegment] = []
        var currentColor: Color?
        var currentPoints: [AirQualityHourPoint] = []
        
        for point in points {
            let color = aqiColor(point.usAQI, scale: scale)
            if currentColor == nil || color != currentColor {
                if let currentColor, !currentPoints.isEmpty {
                    segments.append(AQISegment(color: currentColor, points: currentPoints))
                }
                currentColor = color
                currentPoints = [point]
            } else {
                currentPoints.append(point)
            }
        }
        
        if let currentColor, !currentPoints.isEmpty {
            segments.append(AQISegment(color: currentColor, points: currentPoints))
        }
        
        return segments
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
