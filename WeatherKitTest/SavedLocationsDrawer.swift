import SwiftUI
import CoreLocation
import WeatherKit
import UniformTypeIdentifiers
import Combine

struct SavedLocationsDrawer: View {
    @Binding var locations: [SavedLocation]
    let selectedIndex: Int?
    let cachedWeather: [UUID: CachedLocationWeather]
    @Binding var isExpanded: Bool
    let onSelect: (Int) -> Void
    let onMove: (Int, Int) -> Void
    let onRemove: (SavedLocation) -> Void
    @State private var isReorderMode: Bool = false

    var body: some View {
        if locations.isEmpty {
            EmptyView()
        } else {
            VStack(spacing: 0) {
                drawerHeader
                    .layoutPriority(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) {
                        if isExpanded && isReorderMode {
                            Text("Reorder locations")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.16))
                                        .overlay(
                                            Capsule()
                                                .stroke(Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                )
                                .padding(.bottom, -10)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                if isExpanded {
                    SavedLocationsList(
                        locations: locations,
                        selectedIndex: selectedIndex,
                        cachedWeather: cachedWeather,
                        isReorderMode: isReorderMode,
                        isExpanded: isExpanded,
                        onSelect: { index in
                            onSelect(index)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                isExpanded = false
                                isReorderMode = false
                            }
                        },
                        onMove: onMove,
                        onRemove: { location in
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                onRemove(location)
                            }
                        }
                    )
                    .padding(.top, isReorderMode ? 8 : 0)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isReorderMode)
                    .transition(.opacity)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.spring(response: 0.32, dampingFraction: 0.9), value: isExpanded)
            .padding(.horizontal, 6)
        }
    }

    private var drawerHeader: some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                isExpanded.toggle()
                if !isExpanded {
                    isReorderMode = false
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "location.circle")
                    .foregroundColor(.white.opacity(0.85))
                Text("Saved Locations")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.92))
                Text("\(locations.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                    )
                Spacer()
                if isExpanded {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            isReorderMode.toggle()
                        }
                    } label: {
                        Image(systemName: isReorderMode ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(isReorderMode ? 0.95 : 0.75))
                    }
                    .buttonStyle(.plain)
                    .help("Reorder locations")
                }
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.7)
//                    .overlay(
//                        RoundedRectangle(cornerRadius: 12, style: .continuous)
//                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
//                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct SavedLocationsList: View {
    let locations: [SavedLocation]
    let selectedIndex: Int?
    let cachedWeather: [UUID: CachedLocationWeather]
    let isReorderMode: Bool
    let isExpanded: Bool
    let onSelect: (Int) -> Void
    let onMove: (Int, Int) -> Void
    let onRemove: (SavedLocation) -> Void
    @State private var currentTime = Date()
    private let timeTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(Array(locations.enumerated()), id: \.element.id) { index, location in
                    SavedLocationRow(
                        location: location,
                        isSelected: selectedIndex == index,
                        cachedWeather: cachedWeather[location.id],
                        currentTime: currentTime,
                        isActive: isExpanded,
                        onSelect: { onSelect(index) },
                        onRemove: { onRemove(location) },
                        isReorderMode: isReorderMode,
                        onDragStart: { NSItemProvider() },
                        onMoveUp: {
                            guard index > 0 else { return }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                onMove(index, index - 1)
                            }
                        },
                        onMoveDown: {
                            guard index < locations.count - 1 else { return }
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                onMove(index, index + 2)
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .trailing))
                    ))
                }
            }
            .padding(10)
            .padding(.bottom, 6)
        }
        .frame(maxHeight: 560, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: locations.count)
        .onReceive(timeTimer) { _ in
            guard isExpanded else { return }
            currentTime = Date()
        }
    }
}

private struct SavedLocationRow: View {
    let location: SavedLocation
    let isSelected: Bool
    let cachedWeather: CachedLocationWeather?
    let currentTime: Date
    let isActive: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    let isReorderMode: Bool
    let onDragStart: () -> NSItemProvider
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    @State private var timeZone: TimeZone?
    @State private var weatherIcon: String?
    @State private var temperature: Double?
    @State private var isLoadingWeather = false
    @AppStorage("useCelsius") private var useCelsius: Bool = false

    private let weatherService = WeatherService.shared

    @State private var isHovering = false
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(formattedTime)
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.75))
                    }

                    Spacer()

                    Text(displayTemperatureText)
                        .font(.system(size: 20, weight: .semibold))
                        .monospacedDigit()
                        .foregroundColor(.white.opacity(0.92))
                }

                HStack {
                    Text(displayConditionText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    if let highLow = highLowText {
                        Text(highLow)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                if isReorderMode {
                    HStack(spacing: 8) {
                        Button { onMoveUp?() } label: {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                        Button { onMoveDown?() } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(6)
                                .background(Circle().fill(Color.black.opacity(0.25)))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(rowBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(isSelected ? 0.24 : 0.12), lineWidth: isSelected ? 1.3 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }

            if isReorderMode {
                Button(action: onRemove) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Delete")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.92))
                    .padding(.vertical, 10)
                    .frame(width: 64)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: isReorderMode)
        .contextMenu {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
        .onAppear {
            fetchTimeZone()
            if cachedWeather == nil {
                fetchWeatherIcon()
            }
        }
        .onChange(of: cachedWeather) { _, newValue in
            if let cached = newValue {
                weatherIcon = cached.symbolName
                temperature = cached.temperature
            }
        }
    }

    private var rowBackground: some View {
        ZStack {
            if let cachedWeather {
                MiniWeatherBackdrop(
                    condition: cachedWeather.condition,
                    temperature: cachedWeather.temperature,
                    isDaylight: cachedWeather.isDaylight ?? isDaylightNow,
                    isActive: isActive && isVisible
                )
            } else {
                Color.white.opacity(0.08)
            }

            if isDaylightNow {
                LinearGradient(
                    colors: [
                        Color.black.opacity(isSelected ? 0.10 : 0.18),
                        Color.black.opacity(isSelected ? 0.18 : 0.26)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                Color.black.opacity(isSelected ? 0.14 : 0.20)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var displayWeatherIcon: String? {
        cachedWeather?.symbolName ?? weatherIcon
    }

    private var displayTemperature: Double? {
        cachedWeather?.temperature ?? temperature
    }

    private func formattedTemperature(_ temp: Double) -> Int {
        let tempMeasurement = Measurement(value: temp, unit: UnitTemperature.celsius)
        if useCelsius {
            return Int(tempMeasurement.value)
        } else {
            return Int(tempMeasurement.converted(to: .fahrenheit).value)
        }
    }

    private var isDaylightNow: Bool {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.hour], from: currentTime)
        if let timeZone { components.timeZone = timeZone }
        let hour = components.hour ?? 12
        return hour >= 6 && hour < 18
    }

    private var displayConditionText: String {
        cachedWeather?.condition ?? "—"
    }

    private var displayTemperatureText: String {
        if let temp = displayTemperature {
            return "\(formattedTemperature(temp))°"
        }
        return "--"
    }

    private var highLowText: String? {
        guard let cachedWeather else { return nil }
        guard let high = cachedWeather.highTemperature, let low = cachedWeather.lowTemperature else { return nil }
        return "H:\(formattedTemperature(high))°  L:\(formattedTemperature(low))°"
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        if let timeZone = timeZone {
            formatter.timeZone = timeZone
        } else {
            formatter.timeZone = .current
        }

        return formatter.string(from: currentTime)
    }

    private func fetchTimeZone() {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)

        geocoder.reverseGeocodeLocation(clLocation) { placemarks, _ in
            if let placemark = placemarks?.first {
                self.timeZone = placemark.timeZone
            } else {
                self.timeZone = .current
            }
        }
    }

    private func fetchWeatherIcon() {
        isLoadingWeather = true

        Task {
            do {
                let clLocation = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let weather = try await weatherService.weather(for: clLocation)

                DispatchQueue.main.async {
                    self.weatherIcon = weather.currentWeather.symbolName
                    self.temperature = weather.currentWeather.temperature.converted(to: .celsius).value
                    self.isLoadingWeather = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.weatherIcon = nil
                    self.temperature = nil
                    self.isLoadingWeather = false
                }
            }
        }
    }
}

private struct SavedLocationDropDelegate: DropDelegate {
    let item: SavedLocation
    let locations: [SavedLocation]
    @Binding var draggingId: String?
    let onMove: (Int, Int) -> Void
    private let throttle: TimeInterval = 0.12
    @State private var lastMove: Date = .distantPast

    func dropEntered(info: DropInfo) {
        guard let draggingId,
              let fromIndex = locations.firstIndex(where: { $0.id.uuidString == draggingId }),
              let toIndex = locations.firstIndex(of: item),
              fromIndex != toIndex else { return }
        let now = Date()
        if now.timeIntervalSince(lastMove) > throttle {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                onMove(fromIndex, toIndex)
            }
            lastMove = now
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingId = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        draggingId = nil
    }
}




private struct MiniWeatherBackdrop: View {
    let condition: String
    let temperature: Double
    let isDaylight: Bool
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let localDrift: CGFloat = (isDaylight && isActive) ? drift : 0
            ZStack {
                if isDaylight {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: UnitPoint(x: 0.15 + localDrift, y: 0.10),
                        endPoint: UnitPoint(x: 0.85 - localDrift, y: 0.90)
                    )
                    .animation(reduceMotion || !isDaylight || !isActive ? nil : .easeInOut(duration: 1.0), value: condition)
                } else {
                    Color(red: 0.07, green: 0.09, blue: 0.15)
                }

                if isDaylight {
                    LinearGradient(
                        colors: depthColors,
                        startPoint: UnitPoint(x: 0.85 - drift, y: 0.15),
                        endPoint: UnitPoint(x: 0.10 + drift, y: 0.95)
                    )
                    .blendMode(.overlay)
                    .opacity(0.26)
                }

                if isActive {
                    effectsLayer(in: geo.size)
                }

                if !isDaylight, isClearNight {
                    MiniMoon()
                        .frame(width: 26, height: 26)
                        .padding(.top, 12)
                        .padding(.trailing, 110)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .opacity(0.9)
                        .blendMode(.screen)
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(isDaylight ? 0.03 : 0.08),
                                Color.black.opacity(isDaylight ? 0.08 : 0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(isDaylight ? .multiply : .normal)

                // no noise overlay
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .onAppear {
            guard !reduceMotion, isDaylight, isActive else { return }
            withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                drift = 0.08
            }
        }
        .onChange(of: isActive) { active in
            if !active {
                drift = 0
            } else if isDaylight && !reduceMotion {
                withAnimation(.easeInOut(duration: 14).repeatForever(autoreverses: true)) {
                    drift = 0.08
                }
            }
        }
    }

    private var depthColors: [Color] {
        if isDaylight {
            return [
                Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.18),
                Color(red: 0.90, green: 0.85, blue: 0.95).opacity(0.14),
                Color(red: 1.0, green: 0.92, blue: 0.80).opacity(0.12)
            ]
        }
        return [Color.white.opacity(0.08), Color.purple.opacity(0.10), Color.white.opacity(0.05)]
    }

    private var gradientColors: [Color] {
        let conditionText = condition.lowercased()
        let temp = temperature

        if !isDaylight {
            if conditionText.contains("clear") || conditionText.contains("sunny") {
                return [Color(red: 0.08, green: 0.12, blue: 0.25).opacity(0.95),
                        Color(red: 0.22, green: 0.12, blue: 0.35).opacity(0.85),
                        Color(red: 0.05, green: 0.08, blue: 0.18).opacity(0.95)]
            } else if conditionText.contains("cloud") {
                return [Color(red: 0.10, green: 0.12, blue: 0.20).opacity(0.95),
                        Color(red: 0.18, green: 0.18, blue: 0.26).opacity(0.90),
                        Color(red: 0.06, green: 0.08, blue: 0.14).opacity(0.95)]
            } else if conditionText.contains("rain") || conditionText.contains("drizzle") {
                return [Color(red: 0.06, green: 0.10, blue: 0.18).opacity(0.95),
                        Color(red: 0.10, green: 0.14, blue: 0.22).opacity(0.92),
                        Color(red: 0.05, green: 0.08, blue: 0.14).opacity(0.95)]
            } else if conditionText.contains("snow") || conditionText.contains("flurries") {
                return [Color(red: 0.12, green: 0.14, blue: 0.22).opacity(0.95),
                        Color(red: 0.18, green: 0.20, blue: 0.30).opacity(0.90),
                        Color(red: 0.08, green: 0.10, blue: 0.16).opacity(0.95)]
            } else if conditionText.contains("storm") || conditionText.contains("thunder") {
                return [Color(red: 0.06, green: 0.07, blue: 0.14).opacity(0.95),
                        Color(red: 0.14, green: 0.10, blue: 0.20).opacity(0.92),
                        Color(red: 0.05, green: 0.06, blue: 0.12).opacity(0.95)]
            } else if conditionText.contains("fog") || conditionText.contains("haze") {
                return [Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.95),
                        Color(red: 0.16, green: 0.18, blue: 0.22).opacity(0.90),
                        Color(red: 0.10, green: 0.12, blue: 0.16).opacity(0.95)]
            } else {
                return [Color(red: 0.08, green: 0.12, blue: 0.22).opacity(0.95),
                        Color(red: 0.16, green: 0.14, blue: 0.28).opacity(0.90),
                        Color(red: 0.06, green: 0.09, blue: 0.16).opacity(0.95)]
            }
        }

        if conditionText.contains("clear") || conditionText.contains("sunny") {
            return [
                Color(red: 0.20, green: 0.55, blue: 0.98),
                Color(red: 0.40, green: 0.75, blue: 1.0),
                Color(red: 0.60, green: 0.85, blue: 0.98)
            ]
        } else if conditionText.contains("cloud") {
            return temp > 21
                ? [Color.gray.opacity(0.48), Color.blue.opacity(0.36), Color.gray.opacity(0.36)]
                : [Color.gray.opacity(0.56), Color.blue.opacity(0.46), Color.gray.opacity(0.48)]
        } else if conditionText.contains("rain") || conditionText.contains("drizzle") {
            return [Color.blue.opacity(0.68), Color.gray.opacity(0.56), Color.blue.opacity(0.56)]
        } else if conditionText.contains("snow") || conditionText.contains("flurries") {
            return [Color.white.opacity(0.52), Color.blue.opacity(0.44), Color.white.opacity(0.44)]
        } else if conditionText.contains("storm") || conditionText.contains("thunder") {
            return [Color.purple.opacity(0.62), Color.gray.opacity(0.78), Color.blue.opacity(0.56)]
        } else if conditionText.contains("fog") || conditionText.contains("haze") {
            return [Color.gray.opacity(0.56), Color.white.opacity(0.44), Color.gray.opacity(0.46)]
        } else {
            return [Color.blue.opacity(0.50), Color.cyan.opacity(0.36), Color.blue.opacity(0.40)]
        }
    }


    @ViewBuilder
    private var weatherEffects: some View {
        let conditionText = condition.lowercased()
        let isClear = conditionText.contains("clear") || conditionText.contains("sunny")
        let isCloudy = conditionText.contains("cloud")
        let isFoggy = conditionText.contains("fog") || conditionText.contains("haze")
        let isWet = conditionText.contains("rain") || conditionText.contains("drizzle") || conditionText.contains("storm") || conditionText.contains("thunder") || conditionText.contains("snow")

        if !isDaylight, isClear {
            StarsEffect()
            ShootingStarsEffect()
            MoonRaysEffect()
        } else if !isDaylight {
            StarsEffect()
            if isCloudy || isFoggy || isWet {
                NightGlowEffect()
                    .opacity(0.45)
            }
        }

        if conditionText.contains("storm") || conditionText.contains("thunder") {
            LightningEffect(intensity: 0.7)
            RainEffect()
        } else if conditionText.contains("drizzle") {
            DrizzleEffect()
        } else if conditionText.contains("rain") {
            RainEffect()
        } else if conditionText.contains("snow") {
            SnowEffect()
        } else if conditionText.contains("fog") || conditionText.contains("haze") {
            FogEffect()
        } else if conditionText.contains("cloud") {
            CloudEffect()
        } else if isClear && isDaylight {
            ZStack {
                SunRaysEffect()
                LensFlareEffect(intensity: 0.7)
            }
        }
    }

    private func effectsLayer(in size: CGSize) -> some View {
        let scale = min(size.width / 380.0, size.height / 260.0)
        return weatherEffects
            .scaleEffect(max(0.34, min(scale, 0.55)))
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
            .opacity(isDaylight ? 0.8 : 0.6)
            .blendMode(isDaylight ? .screen : .normal)
            .compositingGroup()
    }

    private var isClearNight: Bool {
        let conditionText = condition.lowercased()
        return !isDaylight && (conditionText.contains("clear") || conditionText.contains("sunny"))
    }
}

private struct NoiseOverlay: View {
    @State private var image: Image?

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable(resizingMode: .tile)
            }
        }
        .onAppear {
            if image == nil {
                image = Image(decorative: NoiseOverlay.makeNoiseImage(), scale: 1.0, orientation: .up)
            }
        }
        .drawingGroup(opaque: false, colorMode: .linear)
    }

    private static func makeNoiseImage() -> CGImage {
        let size = 64
        let count = size * size
        var data = [UInt8](repeating: 0, count: count)
        for i in 0..<count {
            data[i] = UInt8.random(in: 0...255)
        }
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext(
            data: &data,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        return context.makeImage()!
    }
}

private struct MiniMoon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.white.opacity(0.65),
                            Color.white.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 12
                    )
                )
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                .blur(radius: 0.5)
        }
        .shadow(color: Color.white.opacity(0.25), radius: 6, x: 0, y: 0)
    }
}
