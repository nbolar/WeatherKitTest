import SwiftUI
import MapKit

// MARK: - Search Components

struct SuggestionRow: View {
    let suggestion: MKLocalSearchCompletion
    let isHighlighted: Bool
    let onTap: () -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.white.opacity(0.85))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .foregroundColor(.white)
                        .font(.subheadline)
                    if !suggestion.subtitle.isEmpty {
                        Text(suggestion.subtitle)
                            .foregroundColor(.white.opacity(0.75))
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
        .background(isHighlighted ? Color.white.opacity(0.12) : Color.clear)
        .onHover { hovering in
            onHoverChange(hovering)
        }
    }
}
