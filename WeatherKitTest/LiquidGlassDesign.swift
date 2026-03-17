import SwiftUI

private struct DaylightKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}

extension EnvironmentValues {
    var isDaylight: Bool? {
        get { self[DaylightKey.self] }
        set { self[DaylightKey.self] = newValue }
    }
}

// MARK: - Liquid Glass (macOS Tahoe 26) styling helpers

enum LiquidGlassTokens {
    static let panelCorner: CGFloat = 26
    static let cardCorner: CGFloat = 18
    static let strokeOpacity: Double = 0.16
    static let innerGlowOpacity: Double = 0.10
    static let panelWidth: CGFloat = 340
    static let panelHeight: CGFloat = 600
}

struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = LiquidGlassTokens.cardCorner
    @Environment(\.isDaylight) private var isDaylight
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let daylight = isDaylight ?? false
        let strokeOpacity = reduceTransparency
            ? (daylight ? 0.14 : 0.18)
            : (daylight ? 0.10 : LiquidGlassTokens.strokeOpacity)
        let innerGlowOpacity = daylight ? 0.05 : LiquidGlassTokens.innerGlowOpacity
        let shadowOpacity = daylight ? 0.14 : 0.20
        let shadowRadius: CGFloat = daylight ? 14 : 18
        let material: Material = reduceTransparency ? .regularMaterial : (daylight ? .thinMaterial : .regularMaterial)
        let materialOpacity = reduceTransparency ? 0.92 : (daylight ? 0.78 : 0.68)
        let substrateOpacity = reduceTransparency ? (daylight ? 0.44 : 0.38) : (daylight ? 0.28 : 0.22)

        content
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(substrateOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(material)
                        .opacity(materialOpacity)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(strokeOpacity), lineWidth: 0.75)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(innerGlowOpacity),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .opacity(0.9)
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: daylight ? 6 : 10)
    }
}

extension View {
    func liquidGlassCard(cornerRadius: CGFloat = LiquidGlassTokens.cardCorner) -> some View {
        self.modifier(LiquidGlassCard(cornerRadius: cornerRadius))
    }
}

struct LiquidGlassPanelBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 26, x: -8, y: 14)
    }
}

extension View {
    func liquidGlassPanel() -> some View {
        self.modifier(LiquidGlassPanelBackground())
    }
}

struct LiquidGlassSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    init(_ title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            content
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .liquidGlassCard()
    }
}
