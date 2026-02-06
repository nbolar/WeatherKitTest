import SwiftUI
import AppKit
import WeatherKit
import Sparkle

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
        ZStack {
            GeometryReader { proxy in
                let maxPanelHeight = min(proxy.size.height * 0.82, 640)

                ViewThatFits(in: .vertical) {
                    settingsPanelContent
                    ScrollView(showsIndicators: false) {
                        settingsPanelContent
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 12)
                .padding(.horizontal, 16)
                .frame(width: LiquidGlassTokens.panelWidth, alignment: .topLeading)
                .frame(maxHeight: maxPanelHeight)
                .liquidGlassPanel()
                .overlay(panelChromeOverlay)
                .overlay(alignment: .topTrailing) {
                    closeButton
                        .padding(10)
                }
                .contentShape(RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous))
                .onTapGesture {}
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
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

            Text("Settings")
                .font(.title3.weight(.semibold))

            Spacer()
        }
        .padding(.bottom, 4)
    }

    private var settingsPanelContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(alignment: .leading, spacing: 9) {
                SettingsSectionSimple(title: "General") {
                    SettingsRow(title: "Temperature", subtitle: "Units for forecasts and charts.") {
                        Picker("", selection: $useCelsius) {
                            Text("Fahrenheit (°F)").tag(false)
                            Text("Celsius (°C)").tag(true)
                        }
                        .padding(.horizontal, -6)
                        .pickerStyle(.segmented)
                        .onChange(of: useCelsius) { _ in
                            viewModel.refreshCurrentWeather()
                        }
                    }

                        if #available(macOS 13.0, *) {
                            SettingsRowDivider()
                            SettingsRow(title: "Launch at Login", subtitle: "Start WeatherKitTest when you log in.") {
                                Toggle(isOn: Binding(
                                    get: { launchManager.isEnabled },
                                    set: { _ in launchManager.toggle() }
                                )) {
                                    Text("Open at login")
                                        .font(.subheadline.weight(.light))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                .toggleStyle(.switch)
                            }
                        }
                }
                SettingsRowDivider()
                SettingsSectionSimple(title: "Refresh") {
                    SettingsRow(title: "Auto‑Refresh", subtitle: "Update weather data automatically.") {
                        HStack(spacing: 6) {
                            Text("Every")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.65))
                            Picker("", selection: $refreshIntervalMinutes) {
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
                        }
                    }

                    SettingsRowDivider()
                    SettingsRow(title: "Manual Refresh", subtitle: "Fetch the latest data now.") {
                        Button {
                            viewModel.manualRefresh()
                            dismiss()
                        } label: {
                            Label("Refresh Now", systemImage: "arrow.clockwise")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.white.opacity(0.22))
                    }

                }
                SettingsRowDivider()
                SettingsSectionSimple(title: "About") {
                    SettingsRow(title: "Quit App", subtitle: "Close WeatherKitTest.") {
                        Button {
                            quitApp()
                        } label: {
                            Label("Quit", systemImage: "xmark")
                                .labelStyle(.titleOnly)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.white.opacity(0.22))
                    }
                    SettingsRowDivider()
                    SettingsRow(title: "Check for App Updates", subtitle: "Look for a newer version now.") {
                        Button {
                            UpdateManager.shared.checkForUpdates()
                            dismiss()
                        } label: {
                            Label("Check Now", systemImage: "")
                                .labelStyle(.titleOnly)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.white.opacity(0.22))
                    }
                    SettingsRowDivider()
                    SettingsRow(title: "Attribution", subtitle: "Data sources for weather and air quality.") {
                        SettingsAttributionView(weatherAttribution: viewModel.weatherAttribution)
                    }
                }
                

            }
            .padding(.bottom, 6)

            SettingsFooterVersion(text: appVersionText)
        }
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

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "Version \(version) (\(build))"
    }
}

private struct SettingsSectionSimple<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 6)
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }
}

private struct SettingsRowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
    }
}

private struct SettingsFooterVersion: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
            Spacer()
        }
        .padding(.top, 8)
    }
}

struct SettingsAttributionView: View {
    let weatherAttribution: WeatherAttribution?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isDaylight) private var isDaylight
    
    var body: some View {
        let mark = preferredMarkSelection()
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                

                
                Link("Open-Meteo", destination: URL(string: "https://open-meteo.com")!)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .frame(height: 10)
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.55))
                
                if let markURL = mark.url {
                    AsyncImage(url: markURL) { image in
                        image
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .opacity(0.95)
                            .foregroundStyle(mark.shouldInvert ? Color.white : Color.primary)
                    } placeholder: {
                        Text(weatherAttribution?.serviceName ?? "Apple Weather")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .frame(height: 10)
                } else {
                    Text(weatherAttribution?.serviceName ?? "Apple Weather")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                }

            }
            
//            if let legal = weatherAttribution?.legalAttributionText {
//                Text(legal)
//                    .font(.caption2)
//                    .foregroundColor(.white.opacity(0.55))
//                    .lineLimit(2)
//            }
        }
        .padding(.top, 2)
    }
    
    private func preferredMarkSelection() -> (url: URL?, shouldInvert: Bool) {
        let lightURL = weatherAttribution?.combinedMarkLightURL
        let darkURL = weatherAttribution?.combinedMarkDarkURL
        let prefersLight = isDaylight.map { !$0 } ?? (colorScheme == .dark)

        if prefersLight {
            if let lightURL {
                return (lightURL, false)
            }
            if let darkURL {
                return (darkURL, true)
            }
            return (nil, false)
        }

        if let darkURL {
            return (darkURL, false)
        }
        if let lightURL {
            return (lightURL, true)
        }
        return (nil, false)
    }
}
#Preview("In-App Settings") {
    // Provide required arguments for preview
    InAppSettingsView(
        isPresented: .constant(true),
        viewModel: WeatherViewModel()
    )
}
