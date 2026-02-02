import SwiftUI
import AppKit
import WeatherKit

#if canImport(WeatherKit)
// WeatherAttribution is provided by WeatherKit on supported platforms.
#else
// Fallback to allow building on platforms/SDKs without WeatherKit.
public typealias WeatherAttribution = Any
#endif

@inline(__always)
func quitApp() {
    NSApplication.shared.terminate(nil) // no confirmation
}

// MARK: - In-app Settings Panel (Liquid Glass redesign)

struct InAppSettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: WeatherViewModel

    @AppStorage("refreshIntervalMinutes") private var refreshIntervalMinutes: Int = 30
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    private let options = [5, 10, 15, 30, 60, 120, 180]
    
    @StateObject private var launchManager: LaunchAtLoginManager
    
    init(isPresented: Binding<Bool>, viewModel: WeatherViewModel) {
        self._isPresented = isPresented
        self.viewModel = viewModel
        if #available(macOS 13.0, *) {
            _launchManager = StateObject(wrappedValue: LaunchAtLoginManager.shared)
        } else {
            _launchManager = StateObject(wrappedValue: LaunchAtLoginManager.shared)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Panel content
            VStack(alignment: .leading, spacing: 14) {
                header

                VStack(alignment: .leading, spacing: 12) {
                    LiquidGlassSection("Temperature", subtitle: "Choose your preferred unit.") {
                        Picker("", selection: $useCelsius) {
                            Text("Fahrenheit (°F)").tag(false)
                            Text("Celsius (°C)").tag(true)
                        }
                        .padding(.horizontal, -8)
                        .pickerStyle(.segmented)
                        .onChange(of: useCelsius) { _ in
                            viewModel.refreshCurrentWeather()
                        }
                        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.leading)
                        
                    }
                    

                    LiquidGlassSection("Auto‑Refresh", subtitle: "Refresh weather data automatically.") {
                        Picker("Refresh every", selection: $refreshIntervalMinutes) {
                            ForEach(options, id: \.self) { minutes in
                                if minutes < 60 {
                                    Text("\(minutes) minutes").tag(minutes)
                                } else {
                                    let hours = minutes / 60
                                    Text("\(hours) \(hours == 1 ? "hour" : "hours")").tag(minutes)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.leading)
                    }

                    LiquidGlassSection("Manual Refresh", subtitle: "Fetch the latest weather data immediately.") {
                        Button {
                            viewModel.manualRefresh()
                            dismiss()
                        } label: {
                            Label("Refresh Now", systemImage: "arrow.clockwise")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.white.opacity(0.20))
                        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.leading)
                    }
                    
                    
                    HStack() {
                        if #available(macOS 13.0, *) {
                            LiquidGlassSection("Launch at Login", subtitle: "Automatically start the app when you log in.") {
                                Toggle(isOn: Binding(
                                    get: { launchManager.isEnabled },
                                    set: { _ in launchManager.toggle() }
                                )) {
                                    Text("Open at login")
                                }
                                .toggleStyle(.switch)
                                .frame(maxWidth: CGFloat.infinity, alignment: Alignment.leading)
                            }
                            .frame(maxWidth: CGFloat.infinity, alignment: Alignment.leading)
                        }
                        Spacer()
                        LiquidGlassSection("Quit App", subtitle: "Close WeatherKitTest.") {
                            Button {
                                quitApp()
                            } label: {
                                Label("Quit", systemImage: "xmark.circle")
                                    .labelStyle(.titleOnly)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.white.opacity(0.20))
                            .frame(maxWidth: CGFloat.infinity, maxHeight: 115, alignment: Alignment.center)
                        }
                        .frame(maxWidth: CGFloat.infinity, maxHeight: 115, alignment: Alignment.leading)
                    }
                }
                .padding(.top, 6)
                .padding(.horizontal, 14)
                
                LiquidGlassSection("Attribution", subtitle: "Data sources for weather and air quality.") {
                    SettingsAttributionView(weatherAttribution: viewModel.weatherAttribution)
                        .frame(maxWidth: CGFloat.infinity, alignment: Alignment.leading)
                }
                .padding(.horizontal, 14)
                
                #if DEBUG
                LiquidGlassSection("AI Summary", subtitle: "Apple Intelligence status (debug only).") {
                    Text(viewModel.aiSummaryStatus ?? "No status")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(3)
                }
                .padding(.horizontal, 14)
                #endif
                
                

            }
            .padding(.top, 14)
            .padding(.bottom, 10)
            .frame(width: LiquidGlassTokens.panelWidth, alignment: .topLeading)
            .liquidGlassPanel()
            .overlay(panelChromeOverlay)
            .contentShape(RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous))
            .onTapGesture {}
            
            // Close button floats slightly above, like Tahoe sheets/panels.
            closeButton
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 12)
        .padding(.trailing, 12)
        .onAppear {
            if #available(macOS 13.0, *) {
                launchManager.updateStatus()
            }
        }
        
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 30, height: 30)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary.opacity(0.92))
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.title3.weight(.semibold))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }

    private var closeButton: some View {
        
        Button {
            dismiss()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 28, height: 28)

                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary.opacity(0.92))
            }
            .accessibilityHidden(true)

        }
        .buttonStyle(.plain)
        .padding(.horizontal, 7)
        .padding(.top, 5)
    }


    private var panelChromeOverlay: some View {
        // A subtle top highlight to separate the panel from busy backgrounds.
        RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.14),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
    }

    private func dismiss() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.34, dampingFraction: 0.86)) {
            isPresented = false
        }
    }
}

struct SettingsAttributionView: View {
    let weatherAttribution: WeatherAttribution?
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let markURL = preferredMarkURL() {
                    AsyncImage(url: markURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .opacity(0.95)
                    } placeholder: {
                        Text(weatherAttribution?.serviceName ?? "Apple Weather")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(height: 14)
                } else {
                    Text(weatherAttribution?.serviceName ?? "Apple Weather")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
                
                Link("Open-Meteo", destination: URL(string: "https://open-meteo.com")!)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            if let legal = weatherAttribution?.legalAttributionText {
                Text(legal)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)
            }
        }
        .padding(.top, 2)
    }
    
    private func preferredMarkURL() -> URL? {
        if colorScheme == .dark {
            return weatherAttribution?.combinedMarkLightURL
        }
        return weatherAttribution?.combinedMarkDarkURL ?? weatherAttribution?.combinedMarkLightURL
    }
}
