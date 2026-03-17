import SwiftUI

enum WeatherDesignTokens {
    static let popoverWidth: CGFloat = 380
    static let popoverHeight: CGFloat = 500
    static let popoverCorner: CGFloat = 20
    static let shellCorner: CGFloat = 28
    static let cardCorner: CGFloat = 22
    static let sidebarWidth: CGFloat = 300
    static let mainWindowDefault = CGSize(width: 980, height: 720)
    static let mainWindowMin = CGSize(width: 860, height: 620)
    static let sectionSpacing: CGFloat = 18
    static let compactSpacing: CGFloat = 12
    static let shellPadding: CGFloat = 22
    static let popoverContentPadding: CGFloat = 14
    static let popoverSectionSpacing: CGFloat = 8
    static let popoverCardPadding: CGFloat = 12
    static let popoverCompactCardPadding: CGFloat = 10
    static let popoverIconButtonSize: CGFloat = 28
    static let popoverChipHeight: CGFloat = 46
    static let popoverRailSpacing: CGFloat = 8

    static let accent = Color(red: 0.84, green: 0.93, blue: 1.0)
    static let accentStrong = Color(red: 0.42, green: 0.74, blue: 0.98)
    static let panelBase = Color(red: 0.05, green: 0.08, blue: 0.14)
    static let panelFill = Color.black.opacity(0.28)
    static let panelStroke = Color.white.opacity(0.14)
    static let panelHighlight = Color.white.opacity(0.07)
}

enum WeatherEffectMode {
    case none
    case reduced
    case full
}

enum WeatherEffectPolicy {
    static func mode(isVisible: Bool, reduceMotion: Bool, energySaver: Bool) -> WeatherEffectMode {
        guard isVisible, !reduceMotion else {
            return .none
        }

        return energySaver ? .reduced : .full
    }

    static func reducedTimelineInterval(energySaver: Bool) -> TimeInterval {
        energySaver ? (1.0 / 12.0) : (1.0 / 18.0)
    }
}

enum WeatherMotionTokens {
    static let detailLiftOffset: CGFloat = 4
    static let detailLiftScale: CGFloat = 0.998
    static let maxScrollLinkedOffset: CGFloat = 12
    static let minimumScrollScale: CGFloat = 0.985
    static let minimumScrollOpacity: Double = 0.88

    private static let staggerDelays: [Double] = [0.00, 0.02, 0.04, 0.06]

    static func sidebarVisibility(
        isVisible: Bool,
        reduceMotion: Bool,
        energySaver: Bool
    ) -> Animation {
        if reduceMotion || energySaver {
            return .easeOut(duration: isVisible ? 0.12 : 0.10)
        }

        if isVisible {
            return .spring(response: 0.24, dampingFraction: 0.92)
        }

        return .easeOut(duration: 0.18)
    }

    static func interaction(reduceMotion: Bool, energySaver: Bool) -> Animation {
        if reduceMotion || energySaver {
            return .easeOut(duration: 0.14)
        }

        return .spring(response: 0.28, dampingFraction: 0.88)
    }

    static func staggerDelay(for index: Int) -> Double {
        let safeIndex = min(max(index, 0), staggerDelays.count - 1)
        return staggerDelays[safeIndex]
    }
}

private struct WeatherShellPanelModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let material: Material = reduceTransparency ? .regularMaterial : .thinMaterial
        let baseOpacity = reduceTransparency ? 0.92 : 0.58
        let materialOpacity = reduceTransparency ? 0.90 : 0.76

        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(WeatherDesignTokens.panelBase.opacity(baseOpacity))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(material)
                            .opacity(materialOpacity)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(WeatherDesignTokens.panelFill)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(WeatherDesignTokens.panelStroke, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                WeatherDesignTokens.panelHighlight,
                                Color.white.opacity(0.01)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            )
            .shadow(color: .black.opacity(0.24), radius: 24, x: 0, y: 16)
    }
}

extension View {
    func weatherShellPanel(cornerRadius: CGFloat = WeatherDesignTokens.shellCorner) -> some View {
        modifier(WeatherShellPanelModifier(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func weatherSoftTopScrollEdgeEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

struct WeatherActionButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.82 : 0.96))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(prominent ? WeatherDesignTokens.accentStrong.opacity(configuration.isPressed ? 0.55 : 0.72) : Color.white.opacity(configuration.isPressed ? 0.10 : 0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(prominent ? 0.20 : 0.12), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct WeatherCompactIconButtonStyle: ButtonStyle {
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.82 : 0.94))
            .frame(
                width: WeatherDesignTokens.popoverIconButtonSize,
                height: WeatherDesignTokens.popoverIconButtonSize
            )
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isActive
                            ? WeatherDesignTokens.accentStrong.opacity(configuration.isPressed ? 0.26 : 0.34)
                            : Color.white.opacity(configuration.isPressed ? 0.10 : 0.14)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(
                        isActive ? WeatherDesignTokens.accent.opacity(0.32) : Color.white.opacity(0.10),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
