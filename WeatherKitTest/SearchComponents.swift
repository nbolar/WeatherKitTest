import SwiftUI
import MapKit

// MARK: - Search Components

struct SuggestionRow: View {
    let suggestion: MKLocalSearchCompletion
    let isHighlighted: Bool
    let onTap: () -> Void
    let onHoverChange: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("energySaverMode") private var energySaverMode: Bool = false

    private var interactionAnimation: Animation {
        WeatherMotionTokens.interaction(reduceMotion: reduceMotion, energySaver: energySaverMode)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .foregroundStyle(.white)
                        .font(.subheadline)
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .foregroundStyle(.white.opacity(0.75))
                            .font(.caption)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isHighlighted ? Color.white.opacity(0.12) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(isHighlighted ? 0.10 : 0), lineWidth: 1)
        )
        .scaleEffect(isHighlighted && !reduceMotion && !energySaverMode ? 1.01 : 1.0)
        .offset(x: isHighlighted && !reduceMotion && !energySaverMode ? 2 : 0)
        .shadow(color: .black.opacity(isHighlighted ? 0.12 : 0), radius: isHighlighted ? 14 : 0, x: 0, y: 8)
        .animation(interactionAnimation, value: isHighlighted)
        .onHover { hovering in
            onHoverChange(hovering)
        }
    }
}
