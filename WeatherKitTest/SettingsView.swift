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

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case refresh
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "General"
        case .refresh:
            return "Refresh"
        case .about:
            return "About"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Units, launch behavior, and atmospheric effects."
        case .refresh:
            return "How often Weather updates and how to pull a fresh forecast."
        case .about:
            return "Version details, updates, attribution, and app controls."
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .refresh:
            return "arrow.clockwise"
        case .about:
            return "sparkles.rectangle.stack"
        }
    }

    var accent: Color {
        switch self {
        case .general:
            return Color(red: 0.48, green: 0.79, blue: 1.0)
        case .refresh:
            return Color(red: 0.57, green: 0.86, blue: 0.80)
        case .about:
            return Color(red: 0.98, green: 0.83, blue: 0.56)
        }
    }
}

private enum SettingsScrollTarget: Hashable {
    case top
    case section(SettingsSection)
}

private enum SettingsChromeTokens {
    static let toolbarBlurHeight: CGFloat = 112
    static let contentTopInset: CGFloat = 66
}

struct InAppSettingsView: View {
    @Binding var isPresented: Bool
    @ObservedObject var viewModel: WeatherViewModel
    private let showsPanelChrome: Bool
    private let showsCloseButton: Bool
    private let dismissHandler: (() -> Void)?

    @AppStorage("refreshIntervalMinutes") private var refreshIntervalMinutes: Int = 30
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    @AppStorage("energySaverMode") private var energySaverMode: Bool = false
    @SceneStorage("settings.selectedSection") private var selectedSectionID = SettingsSection.general.rawValue

    @StateObject private var launchManager: LaunchAtLoginManager
    @State private var contentHeight: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let refreshOptions = [5, 10, 15, 30, 60, 120, 180]

    init(
        isPresented: Binding<Bool>,
        viewModel: WeatherViewModel,
        showsPanelChrome: Bool = true,
        showsCloseButton: Bool = true,
        dismissHandler: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.viewModel = viewModel
        self.showsPanelChrome = showsPanelChrome
        self.showsCloseButton = showsCloseButton
        self.dismissHandler = dismissHandler
        _launchManager = StateObject(wrappedValue: LaunchAtLoginManager.shared)
    }

    private var selectedSection: SettingsSection {
        SettingsSection(rawValue: selectedSectionID) ?? .general
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchManager.isEnabled },
            set: { isEnabled in
                if isEnabled {
                    launchManager.enable()
                } else {
                    launchManager.disable()
                }
            }
        )
    }

    var body: some View {
        Group {
            if showsPanelChrome {
                overlayPanelLayout
            } else {
                settingsSceneLayout
            }
        }
        .environment(\.isDaylight, viewModel.currentWeather?.isDaylight)
        .onAppear {
            launchManager.updateStatus()
            ensureValidSelection()
        }
    }

    private var settingsSceneLayout: some View {
        ZStack {
            SettingsAmbientBackdrop(isDaylight: viewModel.currentWeather?.isDaylight ?? false)

            NavigationSplitView {
                settingsSidebar
                    .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 320)
            } detail: {
                settingsDetailColumn
            }
            .navigationSplitViewStyle(.balanced)
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .overlay(alignment: .top) {
                SettingsToolbarBackdrop()
            }
        }
    }

    private var overlayPanelLayout: some View {
        GeometryReader { proxy in
            let maxPanelHeight = min(proxy.size.height * 0.86, 700)
            let panelWidth = min(460, max(360, proxy.size.width - 32))

            ScrollView(showsIndicators: false) {
                overlayPanelContent
                    .background(
                        GeometryReader { geometry in
                            Color.clear
                                .preference(key: SettingsContentHeightKey.self, value: geometry.size.height)
                        }
                    )
            }
            .scrollDisabled(contentHeight <= maxPanelHeight)
            .onPreferenceChange(SettingsContentHeightKey.self) { newValue in
                contentHeight = newValue
            }
            .padding(18)
            .frame(width: panelWidth, alignment: .topLeading)
            .frame(maxHeight: min(maxPanelHeight, contentHeight + 36))
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous)
                            .fill(Color.black.opacity(0.16))
                    )
            )
            .overlay(panelChromeOverlay)
            .overlay(
                RoundedRectangle(cornerRadius: LiquidGlassTokens.panelCorner, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 26, x: 0, y: 18)
            .overlay(alignment: .topTrailing) {
                if showsCloseButton {
                    closeButton
                        .padding(12)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var settingsSidebar: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsSidebarHero(
                    appName: appDisplayName,
                    versionText: appVersionText
                )

                VStack(spacing: 8) {
                    ForEach(SettingsSection.allCases) { section in
                        Button {
                            select(section)
                        } label: {
                            SettingsSidebarRow(
                                section: section,
                                isSelected: selectedSection == section
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )

                Text("Changes apply instantly across the menu bar popover, full forecast window, and weather visuals.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.top, SettingsChromeTokens.contentTopInset)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.16))
                )
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1)
                }
        )
    }

    private var settingsDetailColumn: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear
                        .frame(height: 0)
                        .id(SettingsScrollTarget.top)

                    SettingsDetailHero(
                        appName: appDisplayName,
                        versionText: appVersionText,
                        selectedSection: selectedSection
                    )

                    ForEach(SettingsSection.allCases) { section in
                        sectionGroup(for: section, isSelected: selectedSection == section, compact: false)
                            .id(SettingsScrollTarget.section(section))
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, SettingsChromeTokens.contentTopInset)
                .padding(.bottom, 26)
                .frame(maxWidth: 760, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(detailColumnBackground)
            .onAppear {
                guard selectedSection != .general else { return }
                DispatchQueue.main.async {
                    scrollToSelectedSection(using: proxy, animated: false)
                }
            }
            .onChange(of: selectedSectionID) { _, _ in
                scrollToSelectedSection(using: proxy, animated: !reduceMotion)
            }
        }
    }

    private var overlayPanelContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCompactHeader(
                appName: appDisplayName,
                versionText: appVersionText
            )

            SettingsCompactSectionPicker(
                sections: SettingsSection.allCases,
                selectedSection: selectedSection,
                onSelect: select(_:)
            )

            sectionGroup(for: selectedSection, isSelected: true, compact: true)
        }
    }

    @ViewBuilder
    private func sectionGroup(for section: SettingsSection, isSelected: Bool, compact: Bool) -> some View {
        switch section {
        case .general:
            SettingsSectionCard(section: section, isSelected: isSelected, compact: compact) {
                SettingsPreferenceRow(
                    title: "Temperature Units",
                    subtitle: "Use the same unit in forecasts, charts, maps, and summaries."
                ) {
                    Picker("Temperature Units", selection: $useCelsius) {
                        Text("Fahrenheit").tag(false)
                        Text("Celsius").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: compact ? 220 : 240)
                    .labelsHidden()
                    .onChange(of: useCelsius) { _, _ in
                        viewModel.refreshCurrentWeather()
                    }
                }

                SettingsCardDivider()

                SettingsPreferenceRow(
                    title: "Launch at Login",
                    subtitle: "Open Weather automatically when you sign in to your Mac."
                ) {
                    Toggle("Enabled", isOn: launchAtLoginBinding)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }

                SettingsCardDivider()

                SettingsPreferenceRow(
                    title: "Energy Saver",
                    subtitle: "Reduce motion and tone down heavier atmospheric effects across the app."
                ) {
                    Toggle("Enabled", isOn: $energySaverMode)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

        case .refresh:
            SettingsSectionCard(section: section, isSelected: isSelected, compact: compact) {
                SettingsPreferenceRow(
                    title: "Refresh Interval",
                    subtitle: "Choose how often Weather fetches fresh data while the app is running."
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Refresh Interval", selection: $refreshIntervalMinutes) {
                            ForEach(refreshOptions, id: \.self) { minutes in
                                Text(refreshOptionLabel(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.menu)
                        .controlSize(.regular)

                        Text("\(refreshOptionLabel(refreshIntervalMinutes)) keeps background weather data on your preferred cadence.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }

                SettingsCardDivider()

                SettingsPreferenceRow(
                    title: "Manual Refresh",
                    subtitle: "Pull the latest conditions immediately without waiting for the timer."
                ) {
                    Button {
                        viewModel.manualRefresh()
                        dismissIfNeeded()
                    } label: {
                        Label("Refresh Now", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(WeatherActionButtonStyle(prominent: true))
                }
            }

        case .about:
            VStack(alignment: .leading, spacing: 14) {
                SettingsSectionCard(section: section, isSelected: isSelected, compact: compact) {
                    SettingsPreferenceRow(
                        title: "Check for Updates",
                        subtitle: "Look for a newer app version right now."
                    ) {
                        Button {
                            UpdateManager.shared.checkForUpdates()
                            dismissIfNeeded()
                        } label: {
                            Label("Check Now", systemImage: "sparkles")
                        }
                        .buttonStyle(WeatherActionButtonStyle(prominent: true))
                    }

                    SettingsCardDivider()

                    SettingsPreferenceRow(
                        title: "Version",
                        subtitle: "Build details for the app currently running on this Mac."
                    ) {
                        Text(appVersionText)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.84))
                            .monospacedDigit()
                    }

                    SettingsCardDivider()

                    SettingsPreferenceRow(
                        title: "Attribution",
                        subtitle: "Weather and air-quality data sources used throughout the app."
                    ) {
                        SettingsAttributionView(weatherAttribution: viewModel.weatherAttribution)
                    }
                }

                SettingsSubtleCard {
                    SettingsPreferenceRow(
                        title: "Quit App",
                        subtitle: "Close WeatherStatus and remove it from the menu bar until the next launch."
                    ) {
                        Button(role: .destructive) {
                            quitApp()
                        } label: {
                            Text("Quit")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.red.opacity(0.88))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.14))
                )
        }
        .buttonStyle(.plain)
        .help("Close Settings")
    }

    private var panelChromeOverlay: some View {
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

    private var detailColumnBackground: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.03),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "WeatherStatus"
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "Version \(version) (\(build))"
    }

    private func refreshOptionLabel(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) minutes"
        }

        let hours = minutes / 60
        return "\(hours) \(hours == 1 ? "hour" : "hours")"
    }

    private func ensureValidSelection() {
        guard SettingsSection(rawValue: selectedSectionID) == nil else { return }
        selectedSectionID = SettingsSection.general.rawValue
    }

    private func select(_ section: SettingsSection) {
        if reduceMotion {
            selectedSectionID = section.rawValue
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedSectionID = section.rawValue
            }
        }
    }

    private func scrollToSelectedSection(using proxy: ScrollViewProxy, animated: Bool) {
        let scrollAction = {
            switch selectedSection {
            case .general:
                proxy.scrollTo(SettingsScrollTarget.top, anchor: .top)
            case .refresh, .about:
                proxy.scrollTo(SettingsScrollTarget.section(selectedSection), anchor: .top)
            }
        }

        if animated {
            withAnimation(.easeInOut(duration: 0.22), scrollAction)
        } else {
            scrollAction()
        }
    }

    private func dismiss() {
        if let dismissHandler {
            dismissHandler()
            return
        }

        if reduceMotion {
            isPresented = false
        } else {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                isPresented = false
            }
        }
    }

    private func dismissIfNeeded() {
        guard showsPanelChrome else { return }
        dismiss()
    }
}

struct WeatherSettingsSceneView: View {
    @ObservedObject var viewModel: WeatherViewModel

    var body: some View {
        InAppSettingsView(
            isPresented: .constant(true),
            viewModel: viewModel,
            showsPanelChrome: false,
            showsCloseButton: false
        )
    }
}

private struct SettingsAmbientBackdrop: View {
    let isDaylight: Bool

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(isDaylight ? 0.14 : 0.10))
                    .frame(width: 320, height: 320)
                    .blur(radius: 90)
                    .offset(x: -92, y: -126)
            }
            .overlay(alignment: .bottomTrailing) {
                Ellipse()
                    .fill(WeatherDesignTokens.accentStrong.opacity(isDaylight ? 0.18 : 0.14))
                    .frame(width: 360, height: 240)
                    .blur(radius: 90)
                    .offset(x: 80, y: 80)
            }
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(isDaylight ? 0.06 : 0.14))
            )
            .ignoresSafeArea()
    }

    private var gradientColors: [Color] {
        if isDaylight {
            return [
                Color(red: 0.27, green: 0.38, blue: 0.67),
                Color(red: 0.34, green: 0.47, blue: 0.74),
                Color(red: 0.43, green: 0.57, blue: 0.81)
            ]
        }

        return [
            Color(red: 0.07, green: 0.11, blue: 0.22),
            Color(red: 0.10, green: 0.15, blue: 0.31),
            Color(red: 0.17, green: 0.24, blue: 0.40)
        ]
    }
}

private struct SettingsToolbarBackdrop: View {
    var body: some View {
        Rectangle()
            .fill(.regularMaterial)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
            }
            .mask(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.96),
                        Color.black.opacity(0.84),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: SettingsChromeTokens.toolbarBlurHeight)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
    }
}

private struct SettingsSidebarHero: View {
    let appName: String
    let versionText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)
                .clipShape(.rect(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            Text(appName)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)

            Text("Shape the menu bar forecast, refresh cadence, and atmospheric polish so the app feels at home on your Mac.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            Text(versionText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.54))
                .monospacedDigit()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct SettingsSidebarRow: View {
    let section: SettingsSection
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(section.accent.opacity(isSelected ? 0.22 : 0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: section.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 0.96 : 0.76))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(section.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(isSelected ? 0.98 : 0.84))

                Text(section.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(isSelected ? 0.72 : 0.54))
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected ? section.accent.opacity(0.40) : Color.white.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
}

private struct SettingsDetailHero: View {
    let appName: String
    let versionText: String
    let selectedSection: SettingsSection

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SETTINGS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.56))

                Text("Weather preferences")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white)

                Text("Fine-tune \(appName) without leaving the forecast flow. The current focus is \(selectedSection.title.lowercased()).")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }

//            Spacer(minLength: 12)

//            VStack(alignment: .trailing, spacing: 8) {
//                SettingsFocusBadge(section: selectedSection)
//
//                Text(versionText)
//                    .font(.system(size: 11, weight: .semibold))
//                    .foregroundStyle(.white.opacity(0.56))
//                    .monospacedDigit()
//            }
        }
    }
}

private struct SettingsFocusBadge: View {
    let section: SettingsSection

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: section.systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(section.title)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.94))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(section.accent.opacity(0.24))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(section.accent.opacity(0.36), lineWidth: 1)
        )
    }
}

private struct SettingsCompactHeader: View {
    let appName: String
    let versionText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)

            Text("A compact view of the same preferences window, tuned for overlays and previews.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))

            Text("\(appName) • \(versionText)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.52))
                .monospacedDigit()
        }
    }
}

private struct SettingsCompactSectionPicker: View {
    let sections: [SettingsSection]
    let selectedSection: SettingsSection
    let onSelect: (SettingsSection) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(sections) { section in
                Button {
                    onSelect(section)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.systemImage)
                            .font(.system(size: 11, weight: .semibold))

                        Text(section.title)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(selectedSection == section ? 0.96 : 0.74))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule(style: .continuous)
                            .fill(selectedSection == section ? Color.white.opacity(0.14) : Color.white.opacity(0.06))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(
                                selectedSection == section ? section.accent.opacity(0.38) : Color.white.opacity(0.10),
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct SettingsSectionCard<Content: View>: View {
    let section: SettingsSection
    let isSelected: Bool
    let compact: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 16 : 20) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(section.accent.opacity(0.20))
                        .frame(width: compact ? 40 : 46, height: compact ? 40 : 46)

                    Image(systemName: section.systemImage)
                        .font(.system(size: compact ? 15 : 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.title)
                        .font(.system(size: compact ? 21 : 24, weight: .bold))
                        .foregroundStyle(.white)

                    Text(section.subtitle)
                        .font(.system(size: compact ? 12 : 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                content
            }
        }
        .padding(compact ? 18 : 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous)
                        .fill(Color.black.opacity(isSelected ? 0.14 : 0.18))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            isSelected ? section.accent.opacity(0.44) : Color.white.opacity(0.14),
                            Color.white.opacity(isSelected ? 0.18 : 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isSelected ? 1.15 : 1
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 24 : 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 16)
    }
}

private struct SettingsSubtleCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

private struct SettingsPreferenceRow<Control: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let control: Control

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                labels
                Spacer(minLength: 16)
                control
                    .frame(maxWidth: 260, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 12) {
                labels
                control
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 16)
    }

    private var labels: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.64))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct SettingsCardDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
    }
}

private struct SettingsContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct SettingsAttributionView: View {
    let weatherAttribution: WeatherAttribution?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isDaylight) private var isDaylight

    var body: some View {
        let mark = preferredMarkSelection()

        HStack(spacing: 6) {
            Link("Open-Meteo", destination: URL(string: "https://open-meteo.com")!)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.82))
                .frame(height: 10)

            Text("•")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))

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
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(height: 10)
            } else {
                Text(weatherAttribution?.serviceName ?? "Apple Weather")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

#Preview("Settings Scene") {
    WeatherSettingsSceneView(viewModel: WeatherViewModel())
}

#Preview("Settings Overlay") {
    InAppSettingsView(
        isPresented: .constant(true),
        viewModel: WeatherViewModel()
    )
}
