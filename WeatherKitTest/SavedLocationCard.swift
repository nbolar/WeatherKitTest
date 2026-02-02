import SwiftUI
import CoreLocation
import WeatherKit
import Combine

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
                        Image(systemName: "mappin.circle.fill")
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
