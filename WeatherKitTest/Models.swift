import Foundation
import CoreLocation
import WeatherKit

// MARK: - Models

struct SavedLocation: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    
    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
    
    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Cached Weather Data for Locations

struct CachedLocationWeather: Codable, Equatable {
    let locationId: UUID
    let temperature: Double
    let condition: String
    let symbolName: String
    let date: Date
    let highTemperature: Double?
    let lowTemperature: Double?
    let isDaylight: Bool?
    
    init(locationId: UUID, weather: CurrentWeather, daily: DayWeather? = nil) {
        self.locationId = locationId
        self.temperature = weather.temperature.converted(to: .celsius).value
        self.condition = weather.condition.description
        self.symbolName = weather.symbolName
        self.date = weather.date
        self.isDaylight = weather.isDaylight
        if let daily {
            self.highTemperature = daily.highTemperature.converted(to: .celsius).value
            self.lowTemperature = daily.lowTemperature.converted(to: .celsius).value
        } else {
            self.highTemperature = nil
            self.lowTemperature = nil
        }
    }
}

// MARK: - Air Quality Models (Open-Meteo)

struct AirQualityUnits: Codable, Equatable {
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
    
    init(usAQI: String? = nil,
         europeanAQI: String? = nil,
         pm25: String? = nil,
         pm10: String? = nil,
         ozone: String? = nil,
         nitrogenDioxide: String? = nil,
         sulphurDioxide: String? = nil,
         carbonMonoxide: String? = nil,
         uvIndex: String? = nil,
         uvIndexClearSky: String? = nil,
         aerosolOpticalDepth: String? = nil) {
        self.usAQI = usAQI
        self.europeanAQI = europeanAQI
        self.pm25 = pm25
        self.pm10 = pm10
        self.ozone = ozone
        self.nitrogenDioxide = nitrogenDioxide
        self.sulphurDioxide = sulphurDioxide
        self.carbonMonoxide = carbonMonoxide
        self.uvIndex = uvIndex
        self.uvIndexClearSky = uvIndexClearSky
        self.aerosolOpticalDepth = aerosolOpticalDepth
    }
}

enum AirQualityScale: String, Equatable {
    case us
    case eu
}

struct AirQualitySnapshot: Equatable {
    let time: Date
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
    let units: AirQualityUnits
    let scale: AirQualityScale?
}

struct AirQualityHourPoint: Equatable, Identifiable {
    let id = UUID()
    let date: Date
    let usAQI: Double
    let scale: AirQualityScale
}
