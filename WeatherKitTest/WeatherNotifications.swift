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

    private init() {}

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func handleCurrentLocationNotifications(
        locationName: String?,
        alerts: [WeatherAlert],
        minuteForecast: Forecast<MinuteWeather>?
    ) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        await scheduleSevereAlerts(alerts, locationName: locationName)
        await schedulePrecipitationIfNeeded(minuteForecast, locationName: locationName)
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

    private func schedulePrecipitationIfNeeded(_ minuteForecast: Forecast<MinuteWeather>?, locationName: String?) async {
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

        let maxIntensity = minutes.map { $0.precipitationIntensity.value }.max() ?? first.precipitationIntensity.value
        let intensityLabel = intensityDescription(maxIntensity)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let startString = formatter.string(from: first.date)

        let content = UNMutableNotificationContent()
        content.title = "Precipitation expected"
        if let locationName { content.subtitle = locationName }
        content.body = "\(intensityLabel) starting around \(startString)."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "weather.precip.\(Int(startTime))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        try? await center.add(request)
        defaults.set(now, forKey: precipStorageKey)
        defaults.set(startTime, forKey: precipStartKey)
    }

    private func intensityDescription(_ mmPerHour: Double) -> String {
        switch mmPerHour {
        case ..<0.5:
            return "Light rain"
        case ..<2.0:
            return "Moderate rain"
        case ..<10.0:
            return "Heavy rain"
        default:
            return "Intense rain"
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
