import SwiftUI
import WeatherKit

// MARK: - Weather Backdrop View

struct WeatherBackdropView: View {
    let weather: CurrentWeather
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = 0

    private var styleKey: String {
        let condition = weather.condition.description.lowercased()
        let tempBucket = Int(weather.temperature.value.rounded())
        return "\(condition)|\(weather.isDaylight ? "day" : "night")|\(tempBucket)"
    }

    var body: some View {
        ZStack {
            // Base gradient (animated subtly) based on time-of-day + conditions
            LinearGradient(
                colors: gradientColors,
                startPoint: UnitPoint(x: 0.15 + drift, y: 0.10),
                endPoint: UnitPoint(x: 0.85 - drift, y: 0.90)
            )
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.0), value: styleKey)

            // A second, softer layer to add depth like the macOS Weather popover
            LinearGradient(
                colors: depthColors,
                startPoint: UnitPoint(x: 0.85 - drift, y: 0.15),
                endPoint: UnitPoint(x: 0.10 + drift, y: 0.95)
            )
            .blendMode(.overlay)
            .opacity(weather.isDaylight ? 0.35 : 0.45)
            .animation(reduceMotion ? nil : .easeInOut(duration: 1.0), value: styleKey)

            // Atmospheric effects (always behind the main content)
            weatherEffects
                .allowsHitTesting(false)

            // Subtle vignette for contrast + readability (keeps accessibility strong)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(weather.isDaylight ? 0.05 : 0.28),
                            Color.black.opacity(weather.isDaylight ? 0.15 : 0.40)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.multiply)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            // Gentle parallax drift so the background feels alive without being distracting.
            withAnimation(.easeInOut(duration: 18).repeatForever(autoreverses: true)) {
                drift = 0.08
            }
        }
    }

    private var depthColors: [Color] {
        if weather.isDaylight {
            // Enhanced depth colors for sunny days with more vibrant overlays
            return [
                Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.22),
                Color(red: 0.90, green: 0.85, blue: 0.95).opacity(0.18),
                Color(red: 1.0, green: 0.92, blue: 0.80).opacity(0.15)
            ]
        } else {
            return [Color.white.opacity(0.10), Color.purple.opacity(0.12), Color.white.opacity(0.06)]
        }
    }

    private var gradientColors: [Color] {
        let temp = weather.temperature.value
        let condition = weather.condition.description.lowercased()
        let isDay = weather.isDaylight

        // Night palette first — we keep it calm, deep, and contrast-friendly.
        if !isDay {
            if condition.contains("clear") || condition.contains("sunny") {
                // Clear night
                return [Color(red: 0.08, green: 0.12, blue: 0.25).opacity(0.95),
                        Color(red: 0.22, green: 0.12, blue: 0.35).opacity(0.85),
                        Color(red: 0.05, green: 0.08, blue: 0.18).opacity(0.95)]
            } else if condition.contains("cloud") {
                return [Color(red: 0.10, green: 0.12, blue: 0.20).opacity(0.95),
                        Color(red: 0.18, green: 0.18, blue: 0.26).opacity(0.90),
                        Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.95)]
            } else if condition.contains("rain") || condition.contains("drizzle") {
                return [Color(red: 0.06, green: 0.10, blue: 0.18).opacity(0.95),
                        Color(red: 0.10, green: 0.14, blue: 0.22).opacity(0.92),
                        Color(red: 0.05, green: 0.08, blue: 0.14).opacity(0.95)]
            } else if condition.contains("snow") || condition.contains("flurries") {
                return [Color(red: 0.12, green: 0.14, blue: 0.22).opacity(0.95),
                        Color(red: 0.18, green: 0.20, blue: 0.30).opacity(0.90),
                        Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.95)]
            } else if condition.contains("storm") || condition.contains("thunder") {
                return [Color(red: 0.06, green: 0.07, blue: 0.14).opacity(0.95),
                        Color(red: 0.14, green: 0.10, blue: 0.20).opacity(0.92),
                        Color(red: 0.05, green: 0.06, blue: 0.12).opacity(0.95)]
            } else if condition.contains("fog") || condition.contains("haze") {
                return [Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.95),
                        Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.90),
                        Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.95)]
            } else {
                return [Color(red: 0.08, green: 0.12, blue: 0.22).opacity(0.95),
                        Color(red: 0.16, green: 0.14, blue: 0.28).opacity(0.90),
                        Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.95)]
            }
        }

        // Day palette - VIBRANT sunny skies with dramatic, noticeable colors
        if condition.contains("clear") || condition.contains("sunny") {
            if temp > 85 {
                // Hot sunny day - INTENSE warm golden/orange sky
                return [
                    Color(red: 1.0, green: 0.60, blue: 0.15),  // Deep warm orange top
                    Color(red: 1.0, green: 0.82, blue: 0.35),  // Bright golden middle
                    Color(red: 0.98, green: 0.92, blue: 0.60)  // Soft golden-cream bottom
                ]
            } else if temp > 70 {
                // Pleasant sunny day - VIBRANT azure blue with golden horizon
                return [
                    Color(red: 0.20, green: 0.55, blue: 0.98),  // Deep azure blue top
                    Color(red: 0.40, green: 0.75, blue: 1.0),   // Bright sky blue middle
                    Color(red: 0.95, green: 0.88, blue: 0.50)   // Golden-yellow horizon
                ]
            } else if temp > 50 {
                // Mild sunny day - CRISP bright blue sky
                return [
                    Color(red: 0.15, green: 0.50, blue: 0.95),  // Rich sky blue top
                    Color(red: 0.35, green: 0.70, blue: 1.0),   // Brilliant cyan middle
                    Color(red: 0.60, green: 0.85, blue: 0.98)   // Light cyan-blue horizon
                ]
            } else {
                // Cool sunny day - VIVID cool blue with purple accents
                return [
                    Color(red: 0.25, green: 0.45, blue: 0.90),  // Deep cool blue top
                    Color(red: 0.45, green: 0.60, blue: 0.95),  // Bright periwinkle middle
                    Color(red: 0.55, green: 0.75, blue: 0.98)   // Cool cyan-blue bottom
                ]
            }
        } else if condition.contains("cloud") {
            if temp > 70 {
                return [Color.gray.opacity(0.48), Color.blue.opacity(0.36), Color.gray.opacity(0.36)]
            } else {
                return [Color.gray.opacity(0.56), Color.blue.opacity(0.46), Color.gray.opacity(0.48)]
            }
        } else if condition.contains("rain") || condition.contains("drizzle") {
            return [Color.blue.opacity(0.68), Color.gray.opacity(0.56), Color.blue.opacity(0.56)]
        } else if condition.contains("snow") || condition.contains("flurries") {
            return [Color.white.opacity(0.52), Color.blue.opacity(0.44), Color.white.opacity(0.44)]
        } else if condition.contains("storm") || condition.contains("thunder") {
            return [Color.purple.opacity(0.62), Color.gray.opacity(0.78), Color.blue.opacity(0.56)]
        } else if condition.contains("fog") || condition.contains("haze") {
            return [Color.gray.opacity(0.56), Color.white.opacity(0.44), Color.gray.opacity(0.46)]
        } else {
            return [Color.blue.opacity(0.50), Color.cyan.opacity(0.36), Color.blue.opacity(0.40)]
        }
    }

    @ViewBuilder
    private var weatherEffects: some View {
        let condition = weather.condition.description.lowercased()
        let isDay = weather.isDaylight

        // Night gets stars + either moon (clear) or subtle glow (other conditions)
        if !isDay {
            StarsEffect()
            ShootingStarsEffect()
            // Show moon with rays on clear nights, otherwise just a subtle glow
            if condition.contains("clear") || condition.contains("sunny") {
                MoonRaysEffect()
            } else {
                NightGlowEffect()
            }
        }

        if condition.contains("storm") || condition.contains("thunder") {
            // Lightning + optional rain gives the right drama.
            LightningEffect(intensity: isDay ? 0.9 : 1.0)
            RainEffect()
        } else if condition.contains("drizzle") {
            DrizzleEffect()
        } else if condition.contains("rain") {
            RainEffect()
        } else if condition.contains("snow") {
            SnowEffect()
        } else if condition.contains("fog") || condition.contains("haze") {
            FogEffect()
        } else if condition.contains("cloud") {
            CloudEffect()
        } else if (condition.contains("clear") || condition.contains("sunny")) && isDay {
            ZStack {
                SunRaysEffect()
                // Subtle lens flare artifacts for sunny days
                LensFlareEffect(intensity: 0.9)
                    .opacity(0.9)
            }
        }
    }
}
