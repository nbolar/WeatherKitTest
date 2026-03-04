import Foundation
import UserNotifications
import WeatherKit

final class WeatherNotificationManager {
    static let shared = WeatherNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let alertStorageKey = "notifiedWeatherAlertIDs"
    private let precipStorageKey = "lastPrecipNotification"
    private let precipStartKey = "lastPrecipStartTime"
    private let alertRetention: TimeInterval = 60 * 60 * 48
    private let precipitationLeadTime: TimeInterval = 10 * 60

    private init() {}

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func handleCurrentLocationNotifications(
        locationName: String?,
        currentWeather: CurrentWeather?,
        alerts: [WeatherAlert],
        minuteForecast: Forecast<MinuteWeather>?
    ) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        await scheduleSevereAlerts(alerts, locationName: locationName)
        await schedulePrecipitationIfNeeded(minuteForecast, currentWeather: currentWeather, locationName: locationName)
    }

    private func scheduleSevereAlerts(_ alerts: [WeatherAlert], locationName: String?) async {
        var seen = loadSeenAlertIDs()
        let now = Date().timeIntervalSince1970
        seen = seen.filter { now - $0.value < alertRetention }

        for alert in alerts {
            let identifier = alertIdentifier(alert)
            guard seen[identifier] == nil else { continue }

            let content = UNMutableNotificationContent()
            content.title = alert.summary
            if let locationName { content.subtitle = locationName }
            content.body = "Severe weather alert issued."
            content.sound = .default
            content.userInfo = ["alertURL": alert.detailsURL.absoluteString]

            let request = UNNotificationRequest(
                identifier: "weather.alert.\(safeNotificationID(identifier))",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )

            try? await center.add(request)
            seen[identifier] = now
        }

        saveSeenAlertIDs(seen)
    }

    private func schedulePrecipitationIfNeeded(_ minuteForecast: Forecast<MinuteWeather>?, currentWeather: CurrentWeather?, locationName: String?) async {
        guard let minuteForecast else { return }
        let minutes = Array(minuteForecast.prefix(60))
        let threshold = 0.1

        guard let first = minutes.first(where: { $0.precipitationIntensity.value >= threshold }) else { return }

        let startTime = first.date.timeIntervalSince1970
        let defaults = UserDefaults.standard
        let lastNotification = defaults.double(forKey: precipStorageKey)
        let lastStart = defaults.double(forKey: precipStartKey)
        let now = Date().timeIntervalSince1970

        if now - lastNotification < 60 * 30, abs(startTime - lastStart) < 60 * 10 {
            return
        }

        let precipType = classifyPrecipitationType(first, current: currentWeather)
        let maxIntensity = minutes.map { $0.precipitationIntensity.value }.max() ?? first.precipitationIntensity.value
        let intensityLabel = intensityDescription(maxIntensity, type: precipType)
        let peakMinute = minutes.max(by: { $0.precipitationIntensity.value < $1.precipitationIntensity.value }) ?? first
        let peakLabel = intensityDescription(peakMinute.precipitationIntensity.value, type: precipType)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let startString = formatter.string(from: first.date)
        let peakString = formatter.string(from: peakMinute.date)

        let content = UNMutableNotificationContent()
        content.title = "Precipitation expected"
        if let locationName { content.subtitle = locationName }
        content.body = "\(intensityLabel) starting around \(startString). Likely heaviest around \(peakString) (\(peakLabel.lowercased()))."
        content.sound = .default

        let nowDate = Date()
        let fireDelay = max(1, first.date.timeIntervalSince(nowDate) - precipitationLeadTime)

        let request = UNNotificationRequest(
            identifier: "weather.precip.\(Int(startTime))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: fireDelay, repeats: false)
        )

        try? await center.add(request)
        defaults.set(nowDate.timeIntervalSince1970, forKey: precipStorageKey)
        defaults.set(startTime, forKey: precipStartKey)
    }

    private enum PrecipitationType {
        case rain
        case snow
        case sleet
        case hail
        case freezing
        case mixed
    }

    private func classifyPrecipitationType(_ minute: MinuteWeather, current: CurrentWeather?) -> PrecipitationType {
        // MinuteWeather doesn't expose a precipitation-type enum.
        // Prefer the current condition when available, then fall back to temperature around freezing.
        if let current {
            let condition = current.condition.description.lowercased()
            if condition.contains("hail") { return .hail }
            if condition.contains("sleet") { return .sleet }
            if condition.contains("freezing") || condition.contains("ice") { return .freezing }
            if condition.contains("snow") { return .snow }
            if condition.contains("mix") { return .mixed }
            
            // Fall back to temperature-based classification
            let c = current.temperature.converted(to: .celsius).value
            if c <= 0.5 { return .snow }
            if c < 2.0 { return .mixed }
        }
        
        // Default to rain if no current weather is available
        return .rain
    }

    private func intensityDescription(_ mmPerHour: Double, type: PrecipitationType) -> String {
        let kind: String = {
            switch type {
            case .rain: return "rain"
            case .snow: return "snow"
            case .sleet: return "sleet"
            case .hail: return "hail"
            case .freezing: return "freezing rain"
            case .mixed: return "precipitation"
            }
        }()
        switch mmPerHour {
        case ..<0.5:
            return "Light \(kind)"
        case ..<2.0:
            return "Moderate \(kind)"
        case ..<10.0:
            return "Heavy \(kind)"
        default:
            return "Intense \(kind)"
        }
    }

    private func alertIdentifier(_ alert: WeatherAlert) -> String {
        let urlString = alert.detailsURL.absoluteString
        if !urlString.isEmpty {
            return urlString
        }
        return alert.summary
    }

    private func safeNotificationID(_ identifier: String) -> String {
        let cleaned = identifier.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
        return String(cleaned.prefix(120))
    }

    private func loadSeenAlertIDs() -> [String: TimeInterval] {
        UserDefaults.standard.dictionary(forKey: alertStorageKey) as? [String: TimeInterval] ?? [:]
    }

    private func saveSeenAlertIDs(_ ids: [String: TimeInterval]) {
        UserDefaults.standard.set(ids, forKey: alertStorageKey)
    }
}
