import SwiftUI
import WeatherKit

struct AttributionFooter: View {
    let weatherAttribution: WeatherAttribution?
    let airQualitySourceName: String
    let airQualitySourceURL: URL
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let markURL = weatherAttribution?.combinedMarkLightURL {
                    AsyncImage(url: markURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Text(weatherAttribution?.serviceName ?? "Apple Weather")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .frame(height: 14)
                } else {
                    Text(weatherAttribution?.serviceName ?? "Apple Weather")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
                
                Link(airQualitySourceName, destination: airQualitySourceURL)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.75))
            }
            
            if let legal = weatherAttribution?.legalAttributionText {
                Text(legal)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }
}
