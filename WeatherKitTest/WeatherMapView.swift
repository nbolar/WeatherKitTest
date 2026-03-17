import SwiftUI
import MapKit
import CoreLocation
import WeatherKit
import AppKit

// MARK: - Weather Map View

enum WeatherMapPresentationStyle {
    case embedded
    case destination

    var mapHeight: CGFloat {
        switch self {
        case .embedded:
            return 400
        case .destination:
            return 520
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .embedded:
            return 16
        case .destination:
            return 0
        }
    }

    var contentSpacing: CGFloat {
        switch self {
        case .embedded:
            return 12
        case .destination:
            return 16
        }
    }

    var showsInlineInfoPanel: Bool {
        switch self {
        case .embedded:
            return true
        case .destination:
            return false
        }
    }

    var keepsControlsVisible: Bool {
        switch self {
        case .embedded:
            return false
        case .destination:
            return true
        }
    }
}

struct WeatherMapView: View {
    private struct EquatableCoordinate: Equatable {
        let lat: CLLocationDegrees
        let lon: CLLocationDegrees
    }

    let location: CLLocation?
    let presentationStyle: WeatherMapPresentationStyle
    @ObservedObject var viewModel: WeatherViewModel
    @State private var region: MKCoordinateRegion
    @State private var mapType: MKMapType = .standard
    @State private var showControls = true
    @State private var isHoveringMap = false
    @State private var isHoveringControls = false
    @State private var showControlPill = false
    @State private var overlayStyle: WeatherOverlayStyle = .precipitation
    @State private var overlayOpacity: Double = 0.9
    @State private var isOverlayAvailable: Bool = true
    @State private var radarPath: String? = nil
    @State private var radarHost: String = "https://tilecache.rainviewer.com"
    @State private var isRadarLoading: Bool = false
    @State private var radarTask: Task<Void, Never>?
    @State private var lastRadarFetch: Date? = nil
    @State private var legendRange: ClosedRange<Double>? = nil
    @State private var legendUnit: String? = nil
    @State private var isLegendLoading: Bool = false
    @State private var legendTask: Task<Void, Never>?
    @State private var isHoveringScheduled = false
    
    init(
        location: CLLocation?,
        viewModel: WeatherViewModel,
        presentationStyle: WeatherMapPresentationStyle = .embedded
    ) {
        self.location = location
        self.viewModel = viewModel
        self.presentationStyle = presentationStyle
        
        if let location = location {
            _region = State(initialValue: MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            ))
        } else {
            _region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            ))
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: presentationStyle.contentSpacing) {
            ZStack(alignment: .topTrailing) {
                WeatherMapRepresentable(
                    region: $region,
                    mapType: $mapType,
                    location: location,
                    weather: viewModel.currentWeather,
                    locationName: viewModel.locationName,
                    allowsScrollWheelZoom: presentationStyle == .destination,
                    overlayStyle: overlayStyle,
                    overlayOpacity: overlayOpacity,
                    radarPath: radarTemplateBase,
                    onOverlayAvailabilityChange: { available in
                        isOverlayAvailable = available
                    }
                )
                .frame(height: presentationStyle.mapHeight)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .onHover { hovering in
                    isHoveringMap = hovering
                    guard !presentationStyle.keepsControlsVisible else {
                        showControlPill = true
                        return
                    }
                    if !isHoveringScheduled {
                        isHoveringScheduled = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            isHoveringScheduled = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showControlPill = isHoveringMap || isHoveringControls
                            }
                        }
                    }
                }
                .onChange(of: location.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" }) { _, _ in
                    if let location = location {
                        region = MKCoordinateRegion(
                            center: location.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                        )
                    }
                }
                
                if showControls && (presentationStyle.keepsControlsVisible || isHoveringMap || isHoveringControls) {
                    VStack(spacing: 8) {
                        Button(action: {
                            if let location = location {
                                region = MKCoordinateRegion(
                                    center: location.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                                )
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Center on location")
                        
                        Button(action: {
                            var newSpan = region.span
                            newSpan.latitudeDelta *= 0.5
                            newSpan.longitudeDelta *= 0.5
                            region.span = newSpan
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Zoom in")
                        
                        Button(action: {
                            var newSpan = region.span
                            newSpan.latitudeDelta *= 2.0
                            newSpan.longitudeDelta *= 2.0
                            region.span = newSpan
                        }) {
                            Image(systemName: "minus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("Zoom out")
                    }
                    .padding(12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Menu {
                            Button("Standard") { mapType = .standard }
                            Button("Satellite") { mapType = .satellite }
                            Button("Hybrid") { mapType = .hybrid }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "map")
                                Text(mapTypeLabel)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .opacity(0.7)
                            }
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .frame(height: 14)
                            .overlay(Color.white.opacity(0.2))
                        
                        Menu {
                            ForEach(WeatherOverlayStyle.allCases) { style in
                                Button(style.title) { overlayStyle = style }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.3.layers.3d")
                                Text(overlayLabel)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .opacity(0.7)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
                    
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                )
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, 6)
                .onHover { hovering in
                    isHoveringControls = hovering
                    if presentationStyle.keepsControlsVisible {
                        showControlPill = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showControlPill = hovering || isHoveringMap
                        }
                    }
                }
                .opacity(presentationStyle.keepsControlsVisible ? 1 : (showControlPill ? 1 : 0))
                .animation(.easeInOut(duration: 0.2), value: showControlPill)
            }
            .padding(.horizontal, presentationStyle.horizontalPadding)
            .overlay(alignment: .bottomTrailing) {
                MapScaleView(region: region)
                    .padding(12)
                    .padding(.bottom, 6)
                    .padding(.trailing, 10)
            }
            .overlay(alignment: .bottomLeading) {
                if overlayStyle == .radar {
                    Text("Radar © RainViewer")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.leading, 14)
                        .padding(.bottom, 10)
                }
            }
            .overlay(alignment: .topLeading) {
                if overlayStyle.showsLegend {
                    WeatherOverlayLegend(
                        style: overlayStyle,
                        range: legendRange,
                        unit: legendUnit,
                        isLoading: isLegendLoading
                    )
                    .frame(maxWidth: 260, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .padding(.top, (presentationStyle.keepsControlsVisible || showControlPill) ? 56 : 12)
                    .padding(.leading, 14)
                }
            }
            
            if !isOverlayAvailable && overlayStyle != .none {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(overlayUnavailableText)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(8)
                .background(Color.black.opacity(0.45))
                .cornerRadius(8)
                .padding(.horizontal, presentationStyle.horizontalPadding)
            }
            
            if presentationStyle.showsInlineInfoPanel, let weather = viewModel.currentWeather {
                WeatherMapInfoPanel(weather: weather, location: location)
                    .padding(.horizontal, presentationStyle.horizontalPadding)
            } else if presentationStyle.showsInlineInfoPanel {
                Text("No weather data available")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, presentationStyle.horizontalPadding)
            }
        }
        .onChange(of: overlayStyle) { _, _ in
            scheduleLegendRefresh()
            if overlayStyle == .radar {
                scheduleRadarRefresh()
            }
        }
        .onChange(of: EquatableCoordinate(lat: region.center.latitude, lon: region.center.longitude)) { _, _ in
            scheduleLegendRefresh()
        }
        .onChange(of: radarPath) { _, _ in
            if overlayStyle == .radar {
                isOverlayAvailable = radarPath != nil
            }
        }
        .onAppear {
            showControlPill = presentationStyle.keepsControlsVisible
            scheduleLegendRefresh()
            if overlayStyle == .radar {
                scheduleRadarRefresh()
            }
        }
        .onDisappear {
            cancelBackgroundTasks()
        }
    }

    private func scheduleLegendRefresh() {
        legendTask?.cancel()
        legendTask = Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            await updateLegend()
        }
    }

    private func scheduleRadarRefresh() {
        radarTask?.cancel()
        radarTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await updateRadarPath()
        }
    }

    private func cancelBackgroundTasks() {
        legendTask?.cancel()
        legendTask = nil
        radarTask?.cancel()
        radarTask = nil
    }
    
    private func updateLegend() async {
        guard !Task.isCancelled else { return }
        guard overlayStyle.showsLegend else {
            DispatchQueue.main.async {
                legendRange = nil
                legendUnit = nil
                isLegendLoading = false
            }
            return
        }
        
        DispatchQueue.main.async {
            isLegendLoading = true
        }
        
        let points = gridPoints(for: region, rows: 3, columns: 3)
        let useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
        
        var values: [Double] = []
        var unit: String? = nil
        
        await withTaskGroup(of: LegendValue?.self) { group in
            for point in points {
                if Task.isCancelled { return }
                group.addTask {
                    await fetchLegendValue(
                        latitude: point.latitude,
                        longitude: point.longitude,
                        style: overlayStyle,
                        useCelsius: useCelsius
                    )
                }
            }
            
            for await result in group {
                if Task.isCancelled { return }
                if let result {
                    if let value = result.value {
                        values.append(value)
                    }
                    if unit == nil, let resultUnit = result.unit {
                        unit = resultUnit
                    }
                }
            }
        }
        
        let range: ClosedRange<Double>? = {
            guard let minValue = values.min(), let maxValue = values.max() else { return nil }
            return minValue...maxValue
        }()
        
        DispatchQueue.main.async {
            legendRange = range
            legendUnit = unit
            isLegendLoading = false
        }
    }

    private struct RainViewerResponse: Decodable {
        let host: String?
        let radar: Radar?

        struct Radar: Decodable {
            let past: [Frame]?
            let nowcast: [Frame]?
        }

        struct Frame: Decodable {
            let time: Int
            let path: String
        }
    }

    private func updateRadarPath() async {
        guard !Task.isCancelled else { return }
        guard overlayStyle == .radar else { return }
        if let lastRadarFetch, Date().timeIntervalSince(lastRadarFetch) < 300, radarPath != nil {
            return
        }
        DispatchQueue.main.async {
            isRadarLoading = true
        }
        do {
            let url = URL(string: "https://api.rainviewer.com/public/weather-maps.json")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(RainViewerResponse.self, from: data)
            let latest = decoded.radar?.past?.last
            DispatchQueue.main.async {
                if let host = decoded.host {
                    radarHost = host
                }
                radarPath = latest?.path
                lastRadarFetch = Date()
                isRadarLoading = false
                isOverlayAvailable = radarPath != nil
            }
        } catch {
            DispatchQueue.main.async {
                isRadarLoading = false
                radarPath = nil
                isOverlayAvailable = false
            }
        }
    }
    
    private func gridPoints(for region: MKCoordinateRegion, rows: Int, columns: Int) -> [CLLocationCoordinate2D] {
        let minLat = max(-85.0, region.center.latitude - region.span.latitudeDelta / 2)
        let maxLat = min(85.0, region.center.latitude + region.span.latitudeDelta / 2)
        let minLon = region.center.longitude - region.span.longitudeDelta / 2
        let maxLon = region.center.longitude + region.span.longitudeDelta / 2
        
        let rowCount = max(2, rows)
        let colCount = max(2, columns)
        
        var points: [CLLocationCoordinate2D] = []
        points.reserveCapacity(rowCount * colCount)
        
        for row in 0..<rowCount {
            let t = Double(row) / Double(rowCount - 1)
            let lat = minLat + (maxLat - minLat) * t
            for col in 0..<colCount {
                let u = Double(col) / Double(colCount - 1)
                let lon = minLon + (maxLon - minLon) * u
                points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
        }
        return points
    }
    
    private struct OpenMeteoCurrentResponse: Decodable {
        let current: Current?
        let currentUnits: Units?
        
        struct Current: Decodable {
            let temperature: Double?
            let windSpeed: Double?
            let precipitation: Double?
            let cloudCover: Double?
            let cloudCoverLegacy: Double?
            
            private enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m"
                case windSpeed = "wind_speed_10m"
                case precipitation = "precipitation"
                case cloudCover = "cloud_cover"
                case cloudCoverLegacy = "cloudcover"
            }
        }
        
        struct Units: Decodable {
            let temperature: String?
            let windSpeed: String?
            let precipitation: String?
            let cloudCover: String?
            
            private enum CodingKeys: String, CodingKey {
                case temperature = "temperature_2m"
                case windSpeed = "wind_speed_10m"
                case precipitation = "precipitation"
                case cloudCover = "cloud_cover"
            }
        }
    }
    
    private struct LegendValue {
        let value: Double?
        let unit: String?
    }
    
    private func fetchLegendValue(
        latitude: Double,
        longitude: Double,
        style: WeatherOverlayStyle,
        useCelsius: Bool
    ) async -> LegendValue? {
        guard let url = buildLegendURL(
            latitude: latitude,
            longitude: longitude,
            style: style,
            useCelsius: useCelsius
        ) else { return nil }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoCurrentResponse.self, from: data)
            let current = decoded.current
            let units = decoded.currentUnits
            
            switch style {
            case .temperature:
                return LegendValue(value: current?.temperature, unit: units?.temperature)
            case .wind:
                return LegendValue(value: current?.windSpeed, unit: units?.windSpeed)
            case .precipitation:
                return LegendValue(value: current?.precipitation, unit: units?.precipitation)
            case .clouds:
                let value = current?.cloudCover ?? current?.cloudCoverLegacy
                return LegendValue(value: value, unit: units?.cloudCover ?? "%")
            case .radar:
                return nil
            case .none:
                return nil
            }
        } catch {
            return nil
        }
    }
    
    private func buildLegendURL(
        latitude: Double,
        longitude: Double,
        style: WeatherOverlayStyle,
        useCelsius: Bool
    ) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        var items: [URLQueryItem] = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude))
        ]
        
        let currentVariable: String
        switch style {
        case .temperature:
            currentVariable = "temperature_2m"
            items.append(URLQueryItem(name: "temperature_unit", value: useCelsius ? "celsius" : "fahrenheit"))
        case .wind:
            currentVariable = "wind_speed_10m"
            items.append(URLQueryItem(name: "wind_speed_unit", value: useCelsius ? "kmh" : "mph"))
        case .precipitation:
            currentVariable = "precipitation"
            items.append(URLQueryItem(name: "precipitation_unit", value: useCelsius ? "mm" : "inch"))
        case .clouds:
            currentVariable = "cloud_cover"
        case .radar:
            return nil
        case .none:
            return nil
        }
        
        items.append(URLQueryItem(name: "current", value: currentVariable))
        items.append(URLQueryItem(name: "timezone", value: "auto"))
        components?.queryItems = items
        return components?.url
    }
    
    private var mapTypeLabel: String {
        switch mapType {
        case .standard: return "Standard"
        case .satellite: return "Satellite"
        case .hybrid: return "Hybrid"
        default: return "Standard"
        }
    }
    
    private var overlayLabel: String {
        overlayStyle.title
    }

    private var radarTemplateBase: String? {
        guard let radarPath else { return nil }
        let host = radarHost.hasSuffix("/") ? String(radarHost.dropLast()) : radarHost
        let path = radarPath.hasPrefix("/") ? radarPath : "/" + radarPath
        return host + path
    }

    private var overlayUnavailableText: String {
        if overlayStyle == .radar {
            return isRadarLoading ? "Loading radar data…" : "Radar overlay unavailable."
        }
        if overlayStyle.requiresOpenWeatherKey {
            return "Overlay unavailable (missing API key)"
        }
        return "Overlay unavailable."
    }
}

struct WeatherOverlayLegend: View {
    let style: WeatherOverlayStyle
    let range: ClosedRange<Double>?
    let unit: String?
    let isLoading: Bool
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(legendLowLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
            
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(legendGradient)
                .frame(height: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            
            Text(legendHighLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    
    private var legendGradient: LinearGradient {
        switch style {
        case .precipitation:
            return LinearGradient(
                colors: [Color.white.opacity(0.2), Color.cyan, Color.blue, Color.purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .wind:
            return LinearGradient(
                colors: [Color.green.opacity(0.3), Color.green, Color.yellow, Color.orange, Color.red],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .temperature:
            return LinearGradient(
                colors: [Color.blue, Color.cyan, Color.yellow, Color.orange, Color.red],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .clouds:
            return LinearGradient(
                colors: [Color.white.opacity(0.2), Color.gray.opacity(0.6), Color.gray],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .radar:
            return LinearGradient(
                colors: [Color.cyan.opacity(0.4), Color.blue, Color.purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .none:
            return LinearGradient(colors: [Color.clear, Color.clear], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var legendLowLabel: String {
        if isLoading { return "Loading…" }
        guard let range else { return "—" }
        return formatValue(range.lowerBound)
    }
    
    private var legendHighLabel: String {
        if isLoading { return " " }
        guard let range else { return "—" }
        return formatValue(range.upperBound)
    }
    
    private func formatValue(_ value: Double) -> String {
        switch style {
        case .temperature:
            if let unit {
                return "\(Int(value.rounded()))\(unit)"
            }
            return formatTemp(value)
        case .wind:
            if let unit {
                return "\(Int(value.rounded())) \(unit)"
            }
            return formatWind(value)
        case .precipitation:
            if let unit {
                return String(format: "%.1f %@", value, unit)
            }
            return formatPrecip(value)
        case .clouds:
            return "\(Int(value.rounded()))%"
        case .radar:
            return ""
        case .none:
            return ""
        }
    }
    
    private func formatTemp(_ celsius: Double) -> String {
        if useCelsius {
            return "\(Int(celsius.rounded()))°C"
        }
        let f = celsius * 9 / 5 + 32
        return "\(Int(f.rounded()))°F"
    }
    
    private func formatWind(_ metersPerSecond: Double) -> String {
        if useCelsius {
            return "\(Int(metersPerSecond.rounded())) m/s"
        }
        let mph = metersPerSecond * 2.23694
        return "\(Int(mph.rounded())) mph"
    }
    
    private func formatPrecip(_ mmPerHour: Double) -> String {
        if useCelsius {
            return String(format: "%.1f mm/h", mmPerHour)
        }
        let inches = mmPerHour / 25.4
        return String(format: "%.2f in/h", inches)
    }
}

struct MapScaleView: View {
    let region: MKCoordinateRegion
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let metersPerPoint = metersPerPoint(for: region, width: max(1, width))
            let targetMeters = metersPerPoint * (width * 0.25)
            let niceMeters = niceDistance(targetMeters)
            let barWidth = niceMeters / metersPerPoint
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 6) {
                    Text(formatDistance(niceMeters))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.85))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.85))
                        .frame(width: max(40, min(barWidth, width * 0.6)), height: 4)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .frame(height: 30)
    }
    
    private func metersPerPoint(for region: MKCoordinateRegion, width: CGFloat) -> Double {
        let metersPerDegreeLon = 111_320.0 * cos(region.center.latitude * .pi / 180)
        let metersAcross = metersPerDegreeLon * region.span.longitudeDelta
        return metersAcross / Double(width)
    }
    
    private func niceDistance(_ meters: Double) -> Double {
        guard meters > 0 else { return 0 }
        let exponent = floor(log10(meters))
        let base = pow(10, exponent)
        let fraction = meters / base
        let niceFraction: Double
        switch fraction {
        case ..<1.5: niceFraction = 1
        case ..<3.5: niceFraction = 2
        case ..<7.5: niceFraction = 5
        default: niceFraction = 10
        }
        return niceFraction * base
    }
    
    private func formatDistance(_ meters: Double) -> String {
        if useCelsius {
            if meters >= 1000 {
                let km = meters / 1000
                return String(format: "%.0f km", km)
            }
            return String(format: "%.0f m", meters)
        } else {
            let miles = meters / 1609.344
            if miles >= 1 {
                return String(format: "%.0f mi", miles)
            }
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        }
    }
}

struct WeatherMapInfoPanel: View {
    let weather: CurrentWeather
    let location: CLLocation?
    @AppStorage("useCelsius") private var useCelsius: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    Image(systemName: weather.symbolName)
                        .font(.title3)
                        .foregroundColor(.white)
                        .symbolRenderingMode(.hierarchical)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(weather.condition.description)
                            .font(.subheadline)
                            .foregroundColor(.white)
                        Text("\(formattedTemperature(weather.temperature))°")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Image(systemName: "wind")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(weather.wind.speed.formatted())
                            .font(.caption2)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    VStack(spacing: 2) {
                        Image(systemName: "humidity.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(Int(weather.humidity * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 2) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(weather.visibility.formatted())
                            .font(.caption2)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            
            if let location = location {
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))
                        Text("Lat:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(String(format: "%.4f°", location.coordinate.latitude))
                            .font(.caption)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    HStack(spacing: 4) {
                        Text("Long:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        Text(String(format: "%.4f°", location.coordinate.longitude))
                            .font(.caption)
                            .foregroundColor(.white)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func formattedTemperature(_ temp: Measurement<UnitTemperature>) -> Int {
        if useCelsius {
            return Int(temp.converted(to: .celsius).value)
        } else {
            return Int(temp.converted(to: .fahrenheit).value)
        }
    }
}

// MARK: - Non-Scrolling MapView
class NonScrollingMapView: MKMapView {
    var allowsScrollWheelZoom = false

    override func scrollWheel(with event: NSEvent) {
        if allowsScrollWheelZoom {
            super.scrollWheel(with: event)
        } else {
            nextResponder?.scrollWheel(with: event)
        }
    }
}

// MARK: - Custom MapKit Representable
struct WeatherMapRepresentable: NSViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var mapType: MKMapType
    let location: CLLocation?
    let weather: CurrentWeather?
    let locationName: String?
    let allowsScrollWheelZoom: Bool
    let overlayStyle: WeatherOverlayStyle
    let overlayOpacity: Double
    let radarPath: String?
    let onOverlayAvailabilityChange: (Bool) -> Void
    
    func makeNSView(context: Context) -> MKMapView {
        let mapView = NonScrollingMapView()
        mapView.delegate = context.coordinator
        mapView.allowsScrollWheelZoom = allowsScrollWheelZoom
        mapView.mapType = mapType
        mapView.showsCompass = true
        mapView.showsScale = false
        mapView.showsZoomControls = false
        
        if let location = location {
            let region = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
            )
            mapView.setRegion(region, animated: false)
            
            let annotation = WeatherAnnotation(
                coordinate: location.coordinate,
                weather: weather,
                locationName: locationName
            )
            mapView.addAnnotation(annotation)
            
            let circle = MKCircle(center: location.coordinate, radius: 50000)
            mapView.addOverlay(circle)
        }
        
        if let overlay = makeTileOverlay(style: overlayStyle, radarPath: radarPath) {
            mapView.addOverlay(overlay, level: .aboveRoads)
            onOverlayAvailabilityChange(true)
        } else {
            onOverlayAvailabilityChange(overlayStyle == .none)
        }
        
        return mapView
    }
    
    func updateNSView(_ nsView: MKMapView, context: Context) {
        if let mapView = nsView as? NonScrollingMapView {
            mapView.allowsScrollWheelZoom = allowsScrollWheelZoom
        }

        if context.coordinator.lastMapType != mapType {
            nsView.mapType = mapType
            context.coordinator.lastMapType = mapType
        }
        
        if context.coordinator.shouldUpdateRegion(region) {
            nsView.setRegion(region, animated: true)
            context.coordinator.lastRegion = region
        }
        
        let locationKey = location.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" }
        if context.coordinator.lastLocationKey != locationKey {
            nsView.removeAnnotations(nsView.annotations)
            for overlay in nsView.overlays {
                if overlay is MKCircle {
                    nsView.removeOverlay(overlay)
                }
            }
            
            if let location = location {
                let annotation = WeatherAnnotation(
                    coordinate: location.coordinate,
                    weather: weather,
                    locationName: locationName
                )
                nsView.addAnnotation(annotation)
                
                let circle = MKCircle(center: location.coordinate, radius: 50000)
                nsView.addOverlay(circle)
            }
            context.coordinator.lastLocationKey = locationKey
        }
        
        if context.coordinator.lastOverlayStyle != overlayStyle {
            let desiredOverlay = makeTileOverlay(style: overlayStyle, radarPath: radarPath)
            if let existing = context.coordinator.tileOverlay {
                nsView.removeOverlay(existing)
            }
            if let desired = desiredOverlay {
                nsView.addOverlay(desired, level: .aboveRoads)
                context.coordinator.tileOverlay = desired
                context.coordinator.overlayOpacity = overlayOpacity
                onOverlayAvailabilityChange(true)
            } else {
                context.coordinator.tileOverlay = nil
                onOverlayAvailabilityChange(overlayStyle == .none)
            }
            context.coordinator.lastOverlayStyle = overlayStyle
        }

        if overlayStyle == .radar, context.coordinator.lastRadarPath != radarPath {
            let desiredOverlay = makeTileOverlay(style: overlayStyle, radarPath: radarPath)
            if let existing = context.coordinator.tileOverlay {
                nsView.removeOverlay(existing)
            }
            if let desired = desiredOverlay {
                nsView.addOverlay(desired, level: .aboveRoads)
                context.coordinator.tileOverlay = desired
                context.coordinator.overlayOpacity = overlayOpacity
                onOverlayAvailabilityChange(true)
            } else {
                context.coordinator.tileOverlay = nil
                onOverlayAvailabilityChange(false)
            }
            context.coordinator.lastRadarPath = radarPath
        }
        
        if context.coordinator.lastOverlayOpacity != overlayOpacity {
            context.coordinator.overlayOpacity = overlayOpacity
            if let existing = context.coordinator.tileOverlay,
               let renderer = nsView.renderer(for: existing) as? MKTileOverlayRenderer {
                renderer.alpha = overlayOpacity
            }
            context.coordinator.lastOverlayOpacity = overlayOpacity
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: WeatherMapRepresentable
        var tileOverlay: MKTileOverlay?
        var overlayOpacity: Double = 0.65
        var lastRegion: MKCoordinateRegion?
        var lastMapType: MKMapType?
        var lastLocationKey: String?
        var lastOverlayStyle: WeatherOverlayStyle?
        var lastOverlayOpacity: Double?
        var lastRadarPath: String?
        
        init(_ parent: WeatherMapRepresentable) { self.parent = parent }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async { self.parent.region = mapView.region }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "WeatherLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
                
                if let markerView = annotationView as? MKMarkerAnnotationView,
                   let weatherAnnotation = annotation as? WeatherAnnotation {
                    if let weather = weatherAnnotation.weather {
                        let color = colorForWeather(weather)
                        markerView.markerTintColor = color
                        markerView.glyphImage = NSImage(systemSymbolName: weather.symbolName, accessibilityDescription: "Weather")
                        let detailView = createWeatherDetailView(weather: weather)
                        markerView.detailCalloutAccessoryView = detailView
                    } else {
                        markerView.markerTintColor = .systemBlue
                        markerView.glyphImage = NSImage(systemSymbolName: "cloud.sun.fill", accessibilityDescription: "Weather Location")
                    }
                    markerView.titleVisibility = .visible
                    markerView.subtitleVisibility = .visible
                }
            } else {
                annotationView?.annotation = annotation
                if let markerView = annotationView as? MKMarkerAnnotationView,
                   let weatherAnnotation = annotation as? WeatherAnnotation {
                    if let weather = weatherAnnotation.weather {
                        let color = colorForWeather(weather)
                        markerView.markerTintColor = color
                        markerView.glyphImage = NSImage(systemSymbolName: weather.symbolName, accessibilityDescription: "Weather")
                        let detailView = createWeatherDetailView(weather: weather)
                        markerView.detailCalloutAccessoryView = detailView
                    }
                }
            }
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                if let weather = parent.weather {
                    let weatherColor = colorForWeather(weather)
                    renderer.fillColor = weatherColor.withAlphaComponent(0.15)
                    renderer.strokeColor = weatherColor.withAlphaComponent(0.4)
                } else {
                    renderer.fillColor = NSColor.systemBlue.withAlphaComponent(0.1)
                    renderer.strokeColor = NSColor.systemBlue.withAlphaComponent(0.3)
                }
                renderer.lineWidth = 2
                return renderer
            }
            if let tile = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tile)
                renderer.alpha = overlayOpacity
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        
        private func colorForWeather(_ weather: CurrentWeather) -> NSColor {
            let temp = weather.temperature.value
            let condition = weather.condition.description.lowercased()
            if condition.contains("clear") || condition.contains("sunny") {
                return temp > 75 ? .systemOrange : .systemYellow
            } else if condition.contains("rain") || condition.contains("drizzle") {
                return .systemBlue
            } else if condition.contains("snow") {
                return .systemCyan
            } else if condition.contains("storm") || condition.contains("thunder") {
                return .systemPurple
            } else if condition.contains("cloud") {
                return .systemGray
            } else {
                return .systemBlue
            }
        }
        
        private func createWeatherDetailView(weather: CurrentWeather) -> NSView {
            let useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
            let temp = useCelsius ? Int(weather.temperature.converted(to: .celsius).value) : Int(weather.temperature.converted(to: .fahrenheit).value)
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
            let tempLabel = NSTextField(labelWithString: "\(temp)°")
            tempLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
            tempLabel.frame = NSRect(x: 10, y: 50, width: 180, height: 30)
            view.addSubview(tempLabel)
            let conditionLabel = NSTextField(labelWithString: weather.condition.description)
            conditionLabel.font = NSFont.systemFont(ofSize: 12)
            conditionLabel.frame = NSRect(x: 10, y: 35, width: 180, height: 15)
            view.addSubview(conditionLabel)
            let infoLabel = NSTextField(labelWithString: "💨 \(weather.wind.speed.formatted())  💧 \(Int(weather.humidity * 100))%")
            infoLabel.font = NSFont.systemFont(ofSize: 11)
            infoLabel.frame = NSRect(x: 10, y: 15, width: 180, height: 15)
            view.addSubview(infoLabel)
            return view
        }
        
        func shouldUpdateRegion(_ region: MKCoordinateRegion) -> Bool {
            guard let lastRegion else { return true }
            return !regionsApproximatelyEqual(region, lastRegion)
        }
        
        private func regionsApproximatelyEqual(_ lhs: MKCoordinateRegion, _ rhs: MKCoordinateRegion) -> Bool {
            let eps = 0.0005
            return abs(lhs.center.latitude - rhs.center.latitude) < eps
                && abs(lhs.center.longitude - rhs.center.longitude) < eps
                && abs(lhs.span.latitudeDelta - rhs.span.latitudeDelta) < eps
                && abs(lhs.span.longitudeDelta - rhs.span.longitudeDelta) < eps
        }
    }
    
    private func makeTileOverlay(style: WeatherOverlayStyle, radarPath: String?) -> MKTileOverlay? {
        guard style != .none else { return nil }
        if style == .radar {
            guard let radarPath else { return nil }
            let template = "\(radarPath)/256/{z}/{x}/{y}/2/1_1.png"
            let overlay = MKTileOverlay(urlTemplate: template)
            overlay.canReplaceMapContent = false
            overlay.tileSize = CGSize(width: 256, height: 256)
            overlay.minimumZ = 0
            overlay.maximumZ = 7
            return overlay
        }
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "OWMAPIKey") as? String,
              !apiKey.isEmpty else {
            return nil
        }
        let template = "https://tile.openweathermap.org/map/\(style.owmLayer)/{z}/{x}/{y}.png?appid=\(apiKey)"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false
        overlay.tileSize = CGSize(width: 256, height: 256)
        overlay.minimumZ = 0
        overlay.maximumZ = 19
        return overlay
    }
}

// Custom annotation class with weather data
class WeatherAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?
    let weather: CurrentWeather?
    
    init(coordinate: CLLocationCoordinate2D, weather: CurrentWeather? = nil, locationName: String? = nil) {
        self.coordinate = coordinate
        self.weather = weather
        if let locationName = locationName {
            self.title = locationName
        } else {
            self.title = "Weather Location"
        }
        if let weather = weather {
            let useCelsius = UserDefaults.standard.bool(forKey: "useCelsius")
            let temp = useCelsius ? Int(weather.temperature.converted(to: .celsius).value) : Int(weather.temperature.converted(to: .fahrenheit).value)
            self.subtitle = "\(temp)° • \(weather.condition.description)"
        } else {
            self.subtitle = "Current forecast area"
        }
        super.init()
    }
}

enum WeatherOverlayStyle: String, CaseIterable, Identifiable {
    case none
    case precipitation
    case radar
    case wind
    case temperature
    case clouds
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .none: return "None"
        case .precipitation: return "Precip"
        case .radar: return "Radar"
        case .wind: return "Wind"
        case .temperature: return "Temp"
        case .clouds: return "Clouds"
        }
    }
    
    var owmLayer: String {
        switch self {
        case .none: return ""
        case .precipitation: return "precipitation_new"
        case .radar: return ""
        case .wind: return "wind_new"
        case .temperature: return "temp_new"
        case .clouds: return "clouds_new"
        }
    }

    var showsLegend: Bool {
        switch self {
        case .none, .radar:
            return false
        case .precipitation, .wind, .temperature, .clouds:
            return true
        }
    }

    var requiresOpenWeatherKey: Bool {
        switch self {
        case .precipitation, .wind, .temperature, .clouds:
            return true
        case .none, .radar:
            return false
        }
    }
}

// MARK: - View Extensions
extension View {
    func scrollDisabledWhenChartsVisible(_ isChartsTab: Bool) -> some View { self }
}
