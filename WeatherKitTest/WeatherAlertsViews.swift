import SwiftUI
import WeatherKit
import WebKit
import AppKit

// MARK: - Weather Alerts Views

// Helper extension for conditional view modifiers
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

struct WeatherAlertBanner: View {
    let alert: WeatherAlert
    let alertIndex: Int
    let totalAlerts: Int
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false
    @Namespace private var animation

    init(alert: WeatherAlert, alertIndex: Int = 0, totalAlerts: Int = 1) {
        self.alert = alert
        self.alertIndex = alertIndex
        self.totalAlerts = totalAlerts
    }

    var body: some View {
        bannerContent
            .background(backgroundShape)
            .overlay(borderShape)
            .scaleEffect(scaleAmount)
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }
    
    // MARK: - View Components
    
    private var bannerContent: some View {
        VStack(spacing: 0) {
            bannerHeader
            
            if isExpanded {
                expandedDivider
                expandedDetail
            }
        }
    }
    
    private var bannerHeader: some View {
        Button {
            withAnimation(.smooth(duration: 0.35, extraBounce: 0)) {
                isExpanded.toggle()
            }
        } label: {
            headerContent
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var headerContent: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.18))
                    .frame(width: 28, height: 28)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color.yellow.opacity(0.95))
                    .imageScale(.small)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                alertBadge
                headerText
            }
            
            Spacer()
            
            Image(systemName: "chevron.down")
                .foregroundColor(.white.opacity(0.6))
                .imageScale(.small)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(12)
        .contentShape(Rectangle())
    }
    
    private var headerText: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(alert.summary)
                    .font(.headline)
                    .foregroundColor(.white)
                if totalAlerts > 1 {
                    Text("(\(alertIndex + 1)/\(totalAlerts))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            Text(isExpanded ? "Alert details below" : "Tap to view details")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var expandedDivider: some View {
        GlassDivider(opacity: 0.12)
            .padding(.horizontal, 12)
            .transition(.opacity)
    }
    
    private var expandedDetail: some View {
        AlertDetailView(
            title: alert.summary,
            url: alert.detailsURL,
            alertIdentifier: alert.summary,
            alertID: extractAlertID(from: alert),
            alertIndex: alertIndex,
            totalAlerts: totalAlerts
        )
        .id("alert-detail-\(alertIndex)-\(extractAlertID(from: alert))")
        .padding(12)
        .background(detailBackground)
        .overlay(detailBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .transition(detailTransition)
    }
    
    // Extract the unique alert ID from the URL or metadata
    private func extractAlertID(from alert: WeatherAlert) -> String {
        // Use the alert summary as fallback ID
        let fallbackID = alert.summary
        
        // Parse the URL to extract the specific ID for this alert from the ids parameter
        guard let components = URLComponents(url: alert.detailsURL, resolvingAgainstBaseURL: false),
              let idsParam = components.queryItems?.first(where: { $0.name == "ids" })?.value else {
            print("⚠️ extractAlertID: No ids parameter found in URL, using fallback: '\(fallbackID)'")
            return fallbackID
        }
        
        // The ids parameter contains comma-separated IDs
        let allIDs = idsParam.split(separator: ",").map { String($0) }
        
        print("📋 extractAlertID: Found \(allIDs.count) IDs in URL for alert '\(fallbackID)' at index \(alertIndex)")
        print("   IDs: \(allIDs)")
        
        // Return the ID at the current alert index if possible, otherwise return fallback ID
        if alertIndex < allIDs.count {
            let selectedID = allIDs[alertIndex]
            print("   ✅ Using ID at index \(alertIndex): '\(selectedID)'")
            return selectedID
        }
        
        print("   ⚠️ Index \(alertIndex) out of range, using fallback: '\(fallbackID)'")
        return fallbackID
    }
    
    private var detailTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.98, anchor: .top).combined(with: .opacity),
            removal: .scale(scale: 0.98, anchor: .top).combined(with: .opacity)
        )
    }
    
    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(alertBackgroundGradient)
    }
    
    private var borderShape: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(borderOpacity, lineWidth: 1)
    }
    
    // MARK: - Computed Properties
    
    private var backgroundOpacity: Color {
        Color.white.opacity(isExpanded ? 0.12 : (isHovering ? 0.11 : 0.10))
    }
    
    private var borderOpacity: Color {
        Color.white.opacity(isExpanded ? 0.22 : (isHovering ? 0.18 : 0.14))
    }
    
    private var scaleAmount: CGFloat {
        isHovering && !isExpanded ? 1.005 : 1.0
    }
    
    private var shadowColor: Color {
        Color.black.opacity(isExpanded ? 0.25 : 0.15)
    }
    
    private var shadowRadius: CGFloat {
        isExpanded ? 16 : 8
    }
    
    private var shadowY: CGFloat {
        isExpanded ? 8 : 4
    }

    private var alertBadge: some View {
        Text("WEATHER ALERT")
            .font(.caption2.weight(.semibold))
            .foregroundColor(.yellow.opacity(0.95))
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(
                Capsule()
                    .fill(Color.yellow.opacity(0.16))
            )
    }

    private var alertBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.yellow.opacity(isExpanded ? 0.16 : 0.14),
                Color.orange.opacity(isExpanded ? 0.10 : 0.08),
                Color.white.opacity(isExpanded ? 0.06 : 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var detailBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.35),
                        Color.black.opacity(0.22),
                        Color.black.opacity(0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
    
    private var detailBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.white.opacity(0.16), lineWidth: 1)
    }
}

// MARK: - Alert Parsing Models

struct AlertLink: Codable {
    let href: String
    let text: String
}

struct AlertBlock: Codable, Identifiable {
    var id = UUID()
    let type: String
    let level: Int?
    let text: String?
    let links: [AlertLink]?
    let items: [String]?
    let label: String?  // For labeled sections like "Severity:", "Description", etc.
    let value: String?  // The value for the labeled section

    private enum CodingKeys: String, CodingKey {
        case type, level, text, links, items, label, value
    }
}

// MARK: - Elegant Divider
struct GlassDivider: View {
    var opacity: Double = 0.12
    var body: some View {
        ZStack {
            // Soft glow to give the divider presence on dark backgrounds
            Rectangle()
                .fill(Color.white.opacity(opacity * 0.10))
                .frame(height: 1)
                .blur(radius: 2)

            // Core hairline
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(opacity * 0.65),
                            Color.white.opacity(opacity * 0.35),
                            Color.white.opacity(opacity * 0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 1)

            // Subtle highlight at the top edge for a glass-like look
            Rectangle()
                .fill(Color.white.opacity(opacity * 0.35))
                .frame(height: 0.5)
                .offset(y: -0.25)
                .opacity(0.6)
        }
        .compositingGroup()
        .blendMode(.overlay)
    }
}

struct ParsedAlertView: View {
    let blocks: [AlertBlock]
    var isEmbedded: Bool = false

    // Slightly more compact typography/padding so the whole alert card typically
    // fits without scrolling (while staying consistent with the rest of the UI).
    fileprivate enum Metrics {
        static let cardCorner: CGFloat = 16
        static let cardOuterHPadding: CGFloat = 12
        static let cardOuterVPadding: CGFloat = 8

        static let headerHPadding: CGFloat = 16
        static let headerVPadding: CGFloat = 12
        static let headerFontSize: CGFloat = 15
        static let chevronSize: CGFloat = 14

        static let rowHPadding: CGFloat = 10
        static let rowVPadding: CGFloat = 6
        static let sectionTitleSize: CGFloat = 13
        static let bodySize: CGFloat = 12
        static let lineSpacing: CGFloat = 2
        static let descriptionItemSpacing: CGFloat = 12
        static let dividerOpacity: Double = 0.08
    }

    // MARK: - Derived content

    private var alertTitle: String {
        // Prefer top-level heading if present
        if let h1 = blocks.first(where: { $0.type == "heading" && ($0.level ?? 1) == 1 })?.text, !h1.isEmpty {
            return h1
        }
        if let anyHeading = blocks.first(where: { $0.type == "heading" })?.text, !anyHeading.isEmpty {
            return anyHeading
        }
        return "Weather Alert"
    }

    private var allLinks: [AlertLink] {
        blocks.flatMap { $0.links ?? [] }
    }

    private var primarySourceLink: AlertLink? {
        // Prefer the "View Alert Source" link, otherwise first link
        if let explicit = allLinks.first(where: { $0.text.lowercased().contains("view alert source") }) {
            return explicit
        }
        return allLinks.first
    }

    private var rawParagraphText: String {
        blocks.first(where: { $0.type == "paragraph" })?.text ?? ""
    }

    private var labeledSectionsFromParser: [(String, String)] {
        var result: [(String, String)] = []
        for block in blocks {
            if block.type == "labeledSection", let label = block.label, let value = block.value {
                let cleanLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanLabel.isEmpty, !cleanValue.isEmpty {
                    result.append((cleanLabel, cleanValue))
                }
            }
        }
        return result
    }

    private var sections: [AlertSection] {
        // If the parser yielded labeled sections, use them.
        if !labeledSectionsFromParser.isEmpty {
            return buildSectionsFromLabeledPairs(labeledSectionsFromParser)
        }

        // Fallback: parse the single blob paragraph into sections.
        let normalized = normalizeRawAlertText(rawParagraphText)
        let pairs = splitIntoSections(normalized)
        if !pairs.isEmpty {
            return buildSectionsFromLabeledPairs(pairs)
        }

        // Last resort: just show the paragraph as Description.
        if !rawParagraphText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return [AlertSection(kind: .description, title: "Description", lines: descriptionLines(from: normalizeRawAlertText(rawParagraphText)))]
        }

        return []
    }

    // MARK: - UI

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header (only show in embedded mode, as the banner already shows the title)
                if !isEmbedded {
                    HStack(alignment: .center) {
                        Text(alertTitle)
                            .font(.system(size: Metrics.headerFontSize, weight: .semibold))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, Metrics.headerHPadding)
                    .padding(.vertical, Metrics.headerVPadding)

                    GlassDivider(opacity: Metrics.dividerOpacity * 1.5)
                }

                // Sections
                VStack(spacing: 0) {
                    ForEach(sections.indices, id: \.self) { idx in
                        let section = sections[idx]
                        AlertSectionRow(section: section, sourceLink: section.kind == .issuedBy ? primarySourceLink : nil)

                        if idx < sections.count - 1 {
                            GlassDivider(opacity: Metrics.dividerOpacity * 1.5)
                                .padding(.horizontal, Metrics.rowHPadding)
                        }
                    }
                }
            }
            .if(!isEmbedded) { view in
                view
                    .background(
                        RoundedRectangle(cornerRadius: Metrics.cardCorner, style: .continuous)
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.20))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.cardCorner, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
                    .padding(.horizontal, Metrics.cardOuterHPadding)
                    .padding(.vertical, Metrics.cardOuterVPadding)
            }
        }
        .background(Color.clear)
    }

    // MARK: - Section building

    private func buildSectionsFromLabeledPairs(_ pairs: [(String, String)]) -> [AlertSection] {
        // Preserve the canonical order from the system alert UI.
        let preferredOrder: [AlertSection.Kind] = [
            .severity,
            .onset,
            .description,
            .actionRecommended,
            .urgency,
            .affectedArea,
            .issuedBy
        ]

        var mapped: [AlertSection] = []

        for (rawLabel, rawValue) in pairs {
            let kind = kindForLabel(rawLabel)
            let title = displayTitle(for: rawLabel, kind: kind)

            if kind == .description {
                mapped.append(AlertSection(kind: .description, title: title, lines: descriptionLines(from: normalizeRawAlertText(rawValue))))
            } else if kind == .severity {
                // Severity often includes an extra explanatory line in the blob; keep it as secondary.
                let normalized = normalizeRawAlertText(rawValue)
                let (first, rest) = splitFirstLine(normalized)
                var lines: [String] = []
                if !first.isEmpty { lines.append(first) }
                if !rest.isEmpty { lines.append(rest) }
                mapped.append(AlertSection(kind: .severity, title: title, lines: lines))
            } else {
                let normalized = normalizeRawAlertText(rawValue)
                let (first, rest) = splitFirstLine(normalized)
                var lines: [String] = []
                if !first.isEmpty { lines.append(first) }
                if !rest.isEmpty { lines.append(rest) }
                mapped.append(AlertSection(kind: kind, title: title, lines: lines))
            }
        }

        // Sort into preferred order when possible, otherwise keep original order.
        let orderIndex: [AlertSection.Kind: Int] = Dictionary(uniqueKeysWithValues: preferredOrder.enumerated().map { ($0.element, $0.offset) })
        mapped.sort {
            (orderIndex[$0.kind] ?? 999) < (orderIndex[$1.kind] ?? 999)
        }

        // De-duplicate by kind (some pages repeat headings)
        var seen = Set<AlertSection.Kind>()
        let deduped = mapped.filter { section in
            if seen.contains(section.kind) { return false }
            seen.insert(section.kind)
            return true
        }

        return deduped
    }

    private func kindForLabel(_ label: String) -> AlertSection.Kind {
        let l = label.lowercased()
        if l.contains("severity") { return .severity }
        if l.contains("onset") { return .onset }
        if l.contains("description") || l.contains("details") { return .description }
        if l.contains("action") { return .actionRecommended }
        if l.contains("urgency") { return .urgency }
        if l.contains("affected area") || l.contains("affected") { return .affectedArea }
        if l.contains("issued by") || l.contains("issuer") { return .issuedBy }
        return .generic
    }

    private func displayTitle(for rawLabel: String, kind: AlertSection.Kind) -> String {
        // Normalize titles to match the system card.
        switch kind {
        case .severity: return "Severity:"
        case .onset: return "Weather Event Onset"
        case .description: return "Description"
        case .actionRecommended: return "Action Recommended"
        case .urgency: return "Urgency"
        case .affectedArea: return "Affected Area"
        case .issuedBy: return "Issued By"
        default:
            // Remove trailing colon if present
            return rawLabel.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ":", with: "")
        }
    }

    // MARK: - Fallback parsing (single blob -> sections)

    private func splitIntoSections(_ text: String) -> [(String, String)] {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty { return [] }

        // Patterns as they tend to appear in the NWS pages / Weather app UI
        let labels: [(key: String, pattern: String)] = [
            ("Severity:", "Severity:"),
            ("Weather Event Onset", "Weather Event Onset"),
            ("Description", "Description"),
            ("Action Recommended", "Action Recommended"),
            ("Urgency", "Urgency"),
            ("Affected Area", "Affected Area"),
            ("Issued By", "Issued By")
        ]

        // Find the first occurrence of each label
        var hits: [(label: String, range: Range<String.Index>)] = []
        for item in labels {
            if let r = normalized.range(of: item.pattern, options: [.caseInsensitive]) {
                hits.append((label: item.key, range: r))
            }
        }
        hits.sort { $0.range.lowerBound < $1.range.lowerBound }

        // If we couldn't find any labels, treat as Description
        if hits.isEmpty {
            return [("Description", normalized)]
        }

        var result: [(String, String)] = []
        for i in 0..<hits.count {
            let current = hits[i]
            let start = current.range.upperBound
            let end = (i + 1 < hits.count) ? hits[i + 1].range.lowerBound : normalized.endIndex
            let value = String(normalized[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            result.append((current.label, value))
        }

        return result
    }

    // MARK: - Text normalization & formatting

    private func normalizeRawAlertText(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return "" }

        // Some sources arrive as a single run-on string; fix the common concatenations first.
        s = regexReplace(s, pattern: #"([a-z])([A-Z])"#, replacement: "$1 $2")      // SevereSignificant -> Severe Significant
        s = regexReplace(s, pattern: #"([A-Za-z])([0-9])"#, replacement: "$1 $2")   // Onset7:00 -> Onset 7:00
        s = regexReplace(s, pattern: #"([0-9])([A-Z])"#, replacement: "$1 $2")      // 25Description -> 25 Description
        s = regexReplace(s, pattern: #"([.!?])([A-Z])"#, replacement: "$1 $2")      // difficult.Action -> difficult. Action

        // Ensure "Description*" becomes "Description\n*"
        s = s.replacingOccurrences(of: "Description*", with: "Description\n*", options: [.caseInsensitive])

        // Make sure bullets start on their own lines when they appear as "* WHAT..."
        s = regexReplace(s, pattern: #"\s*\*\s*"#, replacement: "\n* ")

        // Keep single spaces within lines
        s = s.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)

        // Clean up too many newlines
        s = s.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)

        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func descriptionLines(from text: String) -> [String] {
        let s = normalizeRawAlertText(text)
        if s.isEmpty { return [] }

        // If it contains bullets, split on them but keep the "*" prefix.
        if s.contains("*") {
            let parts = s
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            return parts
        }

        // Otherwise, fall back to sentence-ish chunks with breathing room.
        let collapsed = s.replacingOccurrences(of: "\n", with: " ")
        let spaced = regexReplace(collapsed, pattern: #"([.!?])\s+"#, replacement: "$1\n")
        return spaced
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func splitFirstLine(_ text: String) -> (String, String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return ("", "") }
        if let r = t.range(of: "\n") {
            let first = String(t[..<r.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let rest = String(t[r.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (first, rest)
        }
        return (t, "")
    }

    private func regexReplace(_ input: String, pattern: String, replacement: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return input }
        let range = NSRange(location: 0, length: (input as NSString).length)
        return re.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: replacement)
    }
}

// MARK: - Alert Section UI Models

struct AlertSection: Identifiable {
    enum Kind: Hashable {
        case severity
        case onset
        case description
        case actionRecommended
        case urgency
        case affectedArea
        case issuedBy
        case generic
    }

    let id = UUID()
    let kind: Kind
    let title: String
    let lines: [String]
}

struct AlertSectionRow: View {
    let section: AlertSection
    let sourceLink: AlertLink?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch section.kind {
            case .severity:
                severityHeader
                if section.lines.count > 1 {
                    Text(section.lines[1])
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                }
            case .description:
                Text(section.title)
                    .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: ParsedAlertView.Metrics.descriptionItemSpacing) {
                    ForEach(section.lines.indices, id: \.self) { idx in
                        Text(section.lines[idx])
                            .font(.system(size: ParsedAlertView.Metrics.bodySize))
                            .foregroundColor(.white.opacity(0.60))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                    }
                }
                .padding(.top, 2)

            case .issuedBy:
                Text(section.title)
                    .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .semibold))
                    .foregroundColor(.white)

                if let first = section.lines.first {
                    Text(first)
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                }

                if let link = sourceLink, let url = URL(string: link.href) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Text(link.text)
                            .font(.system(size: ParsedAlertView.Metrics.bodySize))
                            .foregroundColor(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }

            default:
                Text(section.title)
                    .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .semibold))
                    .foregroundColor(.white)

                if let first = section.lines.first {
                    Text(first)
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                }
                if section.lines.count > 1 {
                    Text(section.lines[1])
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.60))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(ParsedAlertView.Metrics.lineSpacing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ParsedAlertView.Metrics.rowHPadding)
        .padding(.vertical, ParsedAlertView.Metrics.rowVPadding)
    }

    private var severityHeader: Text {
        let value = section.lines.first ?? ""
        // Match: "Severity: Moderate"
        return Text("Severity: ")
            .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .semibold))
            .foregroundColor(.white)
        + Text(value.isEmpty ? "" : value)
            .font(.system(size: ParsedAlertView.Metrics.sectionTitleSize, weight: .regular))
            .foregroundColor(.white)
    }
}

// A minimal WKWebView that loads the alert URL and parses content for native rendering
struct AlertWebView: NSViewRepresentable {
    let url: URL
    let alertIdentifier: String
    let alertID: String
    let alertIndex: Int
    let totalAlerts: Int
    @Binding var isLoading: Bool
    var onParsedBlocks: (([AlertBlock]) -> Void)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        
        // Enable developer extras for inspecting content
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        if #available(macOS 11.0, *) {
            config.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        let controller = WKUserContentController()
        
        // Add script message handler for alert parsing
        controller.add(context.coordinator, name: "alertsParser")
        
        // Add console message handler for debugging
        controller.add(context.coordinator, name: "consoleLog")
        
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        // Make the WebView invisible since we only use it for parsing
        webView.alphaValue = 0
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false

        // Start loading
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        webView.load(request)

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // No dynamic updates needed
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: AlertWebView
        init(_ parent: AlertWebView) { self.parent = parent }
        
        private func isAppleDomain(_ host: String?) -> Bool {
            guard let host = host else { return false }
            return host == "apple.com" || host.hasSuffix(".apple.com")
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = false }
            
            // Inject JS to parse alert content and post message to native
            let alertIdentifier = parent.alertIdentifier
            let alertID = parent.alertID
            let alertIndex = parent.alertIndex
            let totalAlerts = parent.totalAlerts
            
            // Debug: Print what we're looking for
            print("🔍 AlertWebView: Looking for alert ID '\(alertID)' (title: '\(alertIdentifier)', index: \(alertIndex) of \(totalAlerts))")
            print("   URL: \(parent.url.absoluteString)")
            
            let parseScript = #"""
            (function(){
                // Intercept console.log for debugging
                const originalLog = console.log;
                console.log = function(...args) {
                    originalLog.apply(console, args);
                    try {
                        window.webkit.messageHandlers.consoleLog.postMessage(args.join(' '));
                    } catch(e) {
                        originalLog('Failed to send to native:', e);
                    }
                };
                
                try {
                    const targetAlertID = '\#(alertID)';
                    const targetAlertTitle = '\#(alertIdentifier.replacingOccurrences(of: "'", with: "\\'"))';
                    const targetAlertIndex = \#(alertIndex);
                    const expectedTotalAlerts = \#(totalAlerts);
                    
                    console.log('🔍 JS: Looking for alert ID "' + targetAlertID + '" (title: "' + targetAlertTitle + '", index: ' + targetAlertIndex + ' of ' + expectedTotalAlerts + ')');
                    
                    // First, expand all collapsible sections by clicking buttons
                    const expandButtons = document.querySelectorAll('button[aria-expanded="false"]');
                    expandButtons.forEach(btn => {
                        try {
                            btn.click();
                        } catch(e) {
                            // Ignore click errors
                        }
                    });
                    
                    // Wait a moment for content to expand, then parse
                    setTimeout(function() {
                        try {
                            // Debug: Log page structure
                            console.log('🔍 JS: Page structure analysis:');
                            console.log('  - .card elements:', document.querySelectorAll('.card').length);
                            console.log('  - article elements:', document.querySelectorAll('article').length);
                            console.log('  - section elements:', document.querySelectorAll('section').length);
                            console.log('  - main > children:', document.querySelector('main') ? document.querySelector('main').children.length : 0);
                            
                            // Helper function to get text from a DD element, handling nested structure
                            function getDDText(dd) {
                                const listItems = dd.querySelectorAll('li');
                                if (listItems.length > 0) {
                                    return Array.from(listItems).map(li => li.textContent.trim()).join(' * ');
                                }
                                return dd.textContent.trim();
                            }
                            
                            // Helper function to parse a single alert card
                            function parseAlertCard(card, index) {
                                const blocks = [];
                                
                                // Get the alert ID from data attributes or other markers
                                let cardID = card.getAttribute('data-id') || 
                                            card.getAttribute('id') || 
                                            card.getAttribute('data-alert-id') ||
                                            '';
                                
                                // Also check for IDs in links within the card - look for specific alert IDs
                                if (!cardID) {
                                    // Try to find a "View Alert Source" or similar link
                                    const links = card.querySelectorAll('a[href]');
                                    for (let link of links) {
                                        const href = link.getAttribute('href') || '';
                                        
                                        // Look for patterns like /weather-alerts/123456 or ids=123456
                                        let idMatch = href.match(/weather-alerts?\/([a-zA-Z0-9\-_]+)/);
                                        if (!idMatch) {
                                            idMatch = href.match(/[?&]ids?=([a-zA-Z0-9\-_,]+)/);
                                        }
                                        
                                        if (idMatch && idMatch[1]) {
                                            // If comma-separated, split and potentially use just one
                                            const potentialIDs = idMatch[1].split(',');
                                            if (potentialIDs.length > index) {
                                                cardID = potentialIDs[index];
                                            } else {
                                                cardID = potentialIDs[0]; // fallback to first
                                            }
                                            break;
                                        }
                                    }
                                }
                                
                                // Also search in the card's HTML for any obvious ID patterns
                                if (!cardID) {
                                    const html = card.innerHTML || '';
                                    // Look for NWS-style IDs (e.g., urn.OID.2.49.0.1.840.0.xxx)
                                    const urnMatch = html.match(/urn\.OID\.[\d\.]+/);
                                    if (urnMatch) {
                                        cardID = urnMatch[0];
                                    }
                                }
                                
                                console.log('📦 parseAlertCard[' + index + ']: Extracted card ID: "' + cardID + '"');
                                
                                // Get the alert title/heading from this card - try multiple strategies
                                let cardTitle = '';
                                
                                // Strategy 1: Look for h1-h4 headings
                                const headings = card.querySelectorAll('h1, h2, h3, h4');
                                for (let heading of headings) {
                                    const text = heading.textContent.trim();
                                    if (text && text.length > 5) {
                                        cardTitle = text;
                                        break;
                                    }
                                }
                                
                                // Strategy 2: Look for .headline .content-title (specific to weatherkit.apple.com)
                                if (!cardTitle) {
                                    const headline = card.querySelector('.headline .content-title');
                                    if (headline) {
                                        cardTitle = headline.textContent.trim();
                                    }
                                }
                                
                                // Strategy 3: Look for elements with "title" or "heading" classes
                                if (!cardTitle) {
                                    const titleElements = card.querySelectorAll('[class*="title"], [class*="heading"], [class*="summary"]');
                                    for (let elem of titleElements) {
                                        const text = elem.textContent.trim();
                                        if (text && text.length > 10) {
                                            cardTitle = text;
                                            break;
                                        }
                                    }
                                }
                                
                                // Strategy 4: Use first strong/bold text if still no title
                                if (!cardTitle) {
                                    const strongElements = card.querySelectorAll('strong, b, [class*="bold"]');
                                    for (let elem of strongElements) {
                                        const text = elem.textContent.trim();
                                        if (text && text.length > 10) {
                                            cardTitle = text;
                                            break;
                                        }
                                    }
                                }
                                
                                // Look for definition lists (DL) within this card - they contain the structured info
                                const definitionLists = card.querySelectorAll('dl');
                                
                                definitionLists.forEach(dl => {
                                    const dts = dl.querySelectorAll('dt');
                                    const dds = dl.querySelectorAll('dd');
                                    
                                    for (let i = 0; i < dts.length; i++) {
                                        const label = dts[i].textContent.trim().replace(/\*$/, '');
                                        const value = dds[i] ? getDDText(dds[i]) : '';
                                        
                                        if (label && value) {
                                            blocks.push({
                                                type: 'labeledSection',
                                                label: label,
                                                value: value
                                            });
                                        }
                                    }
                                });
                                
                                // Alternative structure: Look for .content > .content-title + .content-body
                                // This is the actual structure used by weatherkit.apple.com
                                if (blocks.length === 0) {
                                    const contentBlocks = card.querySelectorAll('.contents > .content');
                                    contentBlocks.forEach(contentBlock => {
                                        const titleElem = contentBlock.querySelector('.content-title');
                                        const bodyElem = contentBlock.querySelector('.content-body');
                                        
                                        if (titleElem && bodyElem) {
                                            let label = titleElem.textContent.trim();
                                            const value = bodyElem.textContent.trim();
                                            
                                            // Remove any trailing colon or *
                                            label = label.replace(/[:\\*]\\s*$/, '');
                                            
                                            if (label && value) {
                                                blocks.push({
                                                    type: 'labeledSection',
                                                    label: label,
                                                    value: value
                                                });
                                            }
                                        }
                                    });
                                }
                                
                                return { id: cardID, title: cardTitle, blocks: blocks, index: index, domIndex: index };
                            }
                            
                            // Try to find all alert cards on the page with multiple strategies
                            let allCards = [];
                            
                            // Strategy 1: Look for .card elements (most specific and common for weather.apple.com)
                            let elements = document.querySelectorAll('.card');
                            if (elements.length >= expectedTotalAlerts) {
                                allCards = Array.from(elements);
                                console.log('🎯 JS: Found ' + allCards.length + ' cards using .card selector');
                            }
                            
                            // Strategy 2: Look for article tags (common for alert cards)
                            if (allCards.length === 0) {
                                elements = document.querySelectorAll('article');
                                if (elements.length >= expectedTotalAlerts) {
                                    allCards = Array.from(elements);
                                    console.log('🎯 JS: Found ' + allCards.length + ' cards using article selector');
                                }
                            }
                            
                            // Strategy 3: Look for section tags with substantial content
                            if (allCards.length === 0) {
                                elements = document.querySelectorAll('section');
                                // Filter sections that have definition lists (typical alert structure)
                                const sectionsWithDL = Array.from(elements).filter(s => s.querySelector('dl'));
                                if (sectionsWithDL.length >= expectedTotalAlerts) {
                                    allCards = sectionsWithDL;
                                    console.log('🎯 JS: Found ' + allCards.length + ' cards using section+dl selector');
                                } else if (elements.length >= expectedTotalAlerts) {
                                    allCards = Array.from(elements);
                                    console.log('🎯 JS: Found ' + allCards.length + ' cards using section selector');
                                }
                            }
                            
                            // Strategy 4: Look for divs with specific classes
                            if (allCards.length === 0) {
                                elements = document.querySelectorAll('[class*="alert"], [class*="card"], [class*="weather"]');
                                if (elements.length >= expectedTotalAlerts) {
                                    allCards = Array.from(elements);
                                    console.log('🎯 JS: Found ' + allCards.length + ' cards using class-based selector');
                                }
                            }
                            
                            // Strategy 5: Look for main > direct children with content
                            if (allCards.length === 0) {
                                const main = document.querySelector('main');
                                if (main) {
                                    elements = main.querySelectorAll(':scope > div, :scope > article, :scope > section');
                                    // Filter for elements with substantial content (at least one dl element)
                                    const withContent = Array.from(elements).filter(el => el.querySelector('dl'));
                                    if (withContent.length >= expectedTotalAlerts) {
                                        allCards = withContent;
                                        console.log('🎯 JS: Found ' + allCards.length + ' cards using main>children with content');
                                    } else if (elements.length >= expectedTotalAlerts) {
                                        allCards = Array.from(elements);
                                        console.log('🎯 JS: Found ' + allCards.length + ' cards using main>children');
                                    }
                                }
                            }
                            
                            // Strategy 6: Exact match - if we find exactly the expected number
                            if (allCards.length === 0 && expectedTotalAlerts > 1) {
                                const selectors = ['.card', 'article', 'section', '[class*="alert"]'];
                                for (let selector of selectors) {
                                    elements = document.querySelectorAll(selector);
                                    if (elements.length === expectedTotalAlerts) {
                                        allCards = Array.from(elements);
                                        console.log('🎯 JS: Found exact match of ' + allCards.length + ' cards using ' + selector);
                                        break;
                                    }
                                }
                            }
                            
                            // Strategy 7: Relaxed - accept any reasonable number
                            if (allCards.length === 0 && expectedTotalAlerts > 1) {
                                const selectors = ['.card', 'article', 'section'];
                                for (let selector of selectors) {
                                    elements = document.querySelectorAll(selector);
                                    if (elements.length >= 2 && elements.length <= expectedTotalAlerts + 2) {
                                        allCards = Array.from(elements);
                                        console.log('🎯 JS: Found ' + allCards.length + ' cards using relaxed ' + selector);
                                        break;
                                    }
                                }
                            }
                            
                            // Strategy 8: Look for multiple DL elements as individual cards
                            // Each alert typically has its own definition list
                            if (allCards.length === 0 && expectedTotalAlerts > 1) {
                                // Find all DL elements that are likely top-level alert containers
                                const allDLs = Array.from(document.querySelectorAll('dl'));
                                console.log('🔍 JS: Found ' + allDLs.length + ' <dl> elements total');
                                
                                // Filter for DLs that contain alert-like content (have dt/dd pairs with labels like "Severity", "Description")
                                const alertDLs = allDLs.filter(dl => {
                                    const dts = Array.from(dl.querySelectorAll('dt')).map(dt => dt.textContent.toLowerCase());
                                    return dts.some(text => 
                                        text.includes('severity') || 
                                        text.includes('description') || 
                                        text.includes('onset') ||
                                        text.includes('urgency')
                                    );
                                });
                                
                                console.log('🔍 JS: Found ' + alertDLs.length + ' <dl> elements with alert content');
                                
                                if (alertDLs.length >= expectedTotalAlerts) {
                                    // Wrap each DL in a container that includes its heading
                                    allCards = alertDLs.map(dl => {
                                        // Try to find the heading associated with this DL
                                        let container = dl.parentElement;
                                        // Walk up to find a container that includes both heading and dl
                                        while (container && container !== document.body) {
                                            const heading = container.querySelector('h1, h2, h3, h4');
                                            if (heading && container.contains(dl)) {
                                                return container;
                                            }
                                            container = container.parentElement;
                                        }
                                        // Fallback: create a wrapper
                                        return dl.parentElement || dl;
                                    });
                                    console.log('🎯 JS: Using ' + allCards.length + ' DL-based card containers');
                                }
                            }
                            
                            // If no cards found, treat entire page as one card
                            if (allCards.length === 0) {
                                allCards = [document.body];
                                console.log('⚠️ JS: No cards found, using entire page as single card');
                            }
                            
                            // Parse all cards
                            const parsedCards = allCards.map((card, idx) => parseAlertCard(card, idx)).filter(c => c.blocks.length > 0);
                            
                            console.log('📊 JS: Found ' + allCards.length + ' total cards, ' + parsedCards.length + ' with content');
                            
                            // Debug: If no cards have content, log what's inside the first card
                            if (parsedCards.length === 0 && allCards.length > 0) {
                                const firstCard = allCards[0];
                                console.log('🔍 JS: Debugging first card structure:');
                                console.log('  - innerHTML length:', firstCard.innerHTML.length);
                                console.log('  - DL elements inside:', firstCard.querySelectorAll('dl').length);
                                console.log('  - All descendants:', firstCard.querySelectorAll('*').length);
                                console.log('  - Buttons:', firstCard.querySelectorAll('button').length);
                                console.log('  - First 500 chars:', firstCard.innerHTML.substring(0, 500));
                            }
                            
                            console.log('📊 JS: Expected ' + expectedTotalAlerts + ' alerts, target index: ' + targetAlertIndex);
                            parsedCards.forEach((c, i) => {
                                console.log('  Card ' + i + ': ID="' + c.id + '" Title="' + c.title + '" (' + c.blocks.length + ' blocks)');
                            });
                            
                            // Find the card matching our target alert
                            let targetCard = null;
                            let matchMethod = '';
                            
                            // Strategy 1: Match by alert ID in the card's DOM attributes or content
                            // This is the MOST RELIABLE method when IDs are present
                            if (targetAlertID && targetAlertID !== targetAlertTitle) {
                                console.log('🔍 JS: Attempting ID-based matching for alert ID: "' + targetAlertID + '"');
                                
                                // Check various attributes where the ID might be stored
                                for (let i = 0; i < allCards.length; i++) {
                                    const card = allCards[i];
                                    const cardElement = card;
                                    
                                    // Check data-id, id, data-alert-id attributes
                                    const dataId = cardElement.getAttribute('data-id') || '';
                                    const idAttr = cardElement.getAttribute('id') || '';
                                    const alertId = cardElement.getAttribute('data-alert-id') || '';
                                    
                                    // Also check for the ID in href attributes of links within the card
                                    const links = cardElement.querySelectorAll('a[href*="' + targetAlertID + '"]');
                                    
                                    // Also search within all text content of the card
                                    const cardHTML = cardElement.innerHTML || '';
                                    
                                    console.log('  Checking card ' + i + ':');
                                    console.log('    data-id: "' + dataId + '"');
                                    console.log('    id: "' + idAttr + '"');
                                    console.log('    data-alert-id: "' + alertId + '"');
                                    console.log('    links with ID: ' + links.length);
                                    console.log('    HTML contains ID: ' + cardHTML.includes(targetAlertID));
                                    
                                    if (dataId.includes(targetAlertID) || 
                                        idAttr.includes(targetAlertID) || 
                                        alertId.includes(targetAlertID) ||
                                        links.length > 0 ||
                                        cardHTML.includes(targetAlertID)) {
                                        targetCard = parsedCards[i];
                                        matchMethod = 'id-match (found in card ' + i + ')';
                                        console.log('✅ JS: Found ID match at card index ' + i);
                                        break;
                                    }
                                }
                                
                                // If we found a match by ID, use it and skip other strategies
                                if (targetCard) {
                                    console.log('✅ JS: Successfully matched by ID, skipping title-based matching');
                                }
                            }
                            
                            // Strategy 2: Try exact title match (only if ID matching failed)
                            if (!targetCard && targetAlertTitle) {
                                console.log('🔍 JS: Trying exact title match for: "' + targetAlertTitle + '"');
                                targetCard = parsedCards.find(c => c.title === targetAlertTitle);
                                if (targetCard) {
                                    matchMethod = 'exact-title';
                                    console.log('✅ JS: Found exact title match for "' + targetAlertTitle + '"');
                                }
                            }
                            
                            // Strategy 3: Try partial title match (both directions)
                            if (!targetCard && targetAlertTitle) {
                                targetCard = parsedCards.find(c => 
                                    c.title.includes(targetAlertTitle) || 
                                    targetAlertTitle.includes(c.title)
                                );
                                if (targetCard) {
                                    matchMethod = 'partial-title';
                                    console.log('✅ JS: Found partial match for "' + targetAlertTitle + '" -> "' + targetCard.title + '"');
                                }
                            }
                            
                            // Strategy 4: Smart word-based title matching
                            if (!targetCard && targetAlertTitle && parsedCards.length > 0) {
                                // Find the card with the best title match score
                                let bestMatch = null;
                                let bestScore = 0;
                                
                                for (let card of parsedCards) {
                                    if (!card.title) continue;
                                    
                                    const targetWords = targetAlertTitle.toLowerCase().split(/\\s+/).filter(w => w.length > 3);
                                    const cardWords = card.title.toLowerCase().split(/\\s+/).filter(w => w.length > 3);
                                    let matchCount = 0;
                                    
                                    for (let word of targetWords) {
                                        if (cardWords.some(cw => cw.includes(word) || word.includes(cw))) {
                                            matchCount++;
                                        }
                                    }
                                    
                                    const matchRatio = matchCount / Math.max(targetWords.length, 1);
                                    
                                    if (matchRatio > bestScore) {
                                        bestScore = matchRatio;
                                        bestMatch = card;
                                    }
                                }
                                
                                if (bestMatch && bestScore >= 0.5) {
                                    targetCard = bestMatch;
                                    matchMethod = 'word-match (score: ' + bestScore.toFixed(2) + ')';
                                    console.log('✅ JS: Using word-based match with score ' + bestScore.toFixed(2) + ' for "' + bestMatch.title + '"');
                                }
                            }
                            
                            // Strategy 5: If card count matches AND index-based title looks good, use index
                            if (!targetCard && parsedCards.length === expectedTotalAlerts) {
                                if (targetAlertIndex >= 0 && targetAlertIndex < parsedCards.length) {
                                    const candidateCard = parsedCards[targetAlertIndex];
                                    // Only use index if title is at least somewhat similar
                                    if (targetAlertTitle && candidateCard.title) {
                                        const targetWords = targetAlertTitle.toLowerCase().split(/\\s+/).filter(w => w.length > 3);
                                        const cardWords = candidateCard.title.toLowerCase().split(/\\s+/).filter(w => w.length > 3);
                                        let matchCount = 0;
                                        for (let word of targetWords) {
                                            if (cardWords.some(cw => cw.includes(word) || word.includes(cw))) {
                                                matchCount++;
                                            }
                                        }
                                        const matchRatio = matchCount / Math.max(targetWords.length, 1);
                                        
                                        if (matchRatio >= 0.4) {
                                            targetCard = candidateCard;
                                            matchMethod = 'index-with-title-verification (match ratio: ' + matchRatio.toFixed(2) + ')';
                                            console.log('✅ JS: Using index ' + targetAlertIndex + ' with title verification (match ratio: ' + matchRatio.toFixed(2) + ')');
                                        } else {
                                            console.log('⚠️ JS: Title mismatch at index ' + targetAlertIndex + ': expected "' + targetAlertTitle + '" but found "' + candidateCard.title + '" (match ratio: ' + matchRatio.toFixed(2) + ')');
                                        }
                                    }
                                }
                            }
                            
                            // Strategy 6: Last resort partial match with lower threshold
                            // Strategy 6: Last resort partial match with lower threshold
                            if (!targetCard && targetAlertTitle) {
                                targetCard = parsedCards.find(c => 
                                    c.title && (c.title.includes(targetAlertTitle) || targetAlertTitle.includes(c.title))
                                );
                                if (targetCard) {
                                    matchMethod = 'low-threshold-partial-title';
                                    console.log('✅ JS: Found low-threshold partial match for "' + targetAlertTitle + '" -> "' + targetCard.title + '"');
                                }
                            }
                            
                            // Strategy 7: Fallback to index if valid
                            if (!targetCard && parsedCards.length > 0) {
                                console.log('⚠️ JS: No ID or title match found, using fallback logic');
                                if (parsedCards.length === 1) {
                                    targetCard = parsedCards[0];
                                    matchMethod = 'single-card';
                                    console.log('📌 JS: Using only card: "' + targetCard.title + '"');
                                } else if (targetAlertIndex >= 0 && targetAlertIndex < parsedCards.length) {
                                    targetCard = parsedCards[targetAlertIndex];
                                    matchMethod = 'fallback-index';
                                    console.log('📌 JS: Using card at index ' + targetAlertIndex + ': "' + targetCard.title + '"');
                                } else {
                                    // Use first card as last resort
                                    targetCard = parsedCards[0];
                                    matchMethod = 'first-card';
                                    console.log('📌 JS: Using first card as fallback: "' + targetCard.title + '"');
                                }
                            }
                            
                            // If we found a matching card, return its blocks
                            if (targetCard && targetCard.blocks.length > 0) {
                                console.log('✅ JS: Returning ' + targetCard.blocks.length + ' blocks for "' + targetCard.title + '" (method: ' + matchMethod + ')');
                                window.webkit.messageHandlers.alertsParser.postMessage({ 
                                    ok: true, 
                                    blocks: targetCard.blocks,
                                    matchedTitle: targetCard.title || '',
                                    targetTitle: targetAlertTitle || '',
                                    targetIndex: targetAlertIndex,
                                    matchMethod: matchMethod
                                });
                                return;
                            }
                            
                            // Last resort: Try to parse DL elements directly as separate alerts
                            console.log('⚠️ JS: Using last resort parsing');
                            const allDLs = Array.from(document.querySelectorAll('dl'));
                            
                            // Parse each DL as a potential alert
                            const dlAlerts = allDLs.map((dl, idx) => {
                                const blocks = [];
                                const dts = dl.querySelectorAll('dt');
                                const dds = dl.querySelectorAll('dd');
                                
                                for (let i = 0; i < dts.length; i++) {
                                    const label = dts[i].textContent.trim().replace(/\\*$/, '');
                                    const value = dds[i] ? getDDText(dds[i]) : '';
                                    
                                    if (label && value) {
                                        blocks.push({
                                            type: 'labeledSection',
                                            label: label,
                                            value: value
                                        });
                                    }
                                }
                                
                                // Try to find a heading near this DL
                                let title = '';
                                let searchNode = dl.previousElementSibling;
                                while (searchNode && !title) {
                                    if (searchNode.matches('h1, h2, h3, h4')) {
                                        title = searchNode.textContent.trim();
                                        break;
                                    }
                                    searchNode = searchNode.previousElementSibling;
                                }
                                
                                return { blocks, title, index: idx };
                            }).filter(alert => alert.blocks.length > 0);
                            
                            console.log('🔍 JS: Found ' + dlAlerts.length + ' DL-based alerts');
                            
                            if (dlAlerts.length >= expectedTotalAlerts && targetAlertIndex < dlAlerts.length) {
                                const selectedAlert = dlAlerts[targetAlertIndex];
                                console.log('✅ JS: Using DL alert at index ' + targetAlertIndex);
                                window.webkit.messageHandlers.alertsParser.postMessage({ 
                                    ok: true, 
                                    blocks: selectedAlert.blocks,
                                    matchedTitle: selectedAlert.title || 'dl-alert-' + targetAlertIndex,
                                    targetTitle: targetAlertTitle || '',
                                    targetIndex: targetAlertIndex,
                                    matchMethod: 'dl-fallback'
                                });
                                return;
                            }
                            
                            // Ultimate fallback: parse entire page as text
                            console.log('⚠️ JS: Using ultimate text fallback');
                            const container = document.querySelector('main') || document.body;
                            const allText = container.textContent;
                            const lines = allText.split('\\n').filter(l => l.trim());
                            let currentLabel = null;
                            let currentValue = [];
                            const fallbackBlocks = [];
                            
                            for (let line of lines) {
                                line = line.trim();
                                
                                if (line.match(/^[A-Z][^:*]+[:\\*]\\s*$/)) {
                                    if (currentLabel && currentValue.length > 0) {
                                        fallbackBlocks.push({
                                            type: 'labeledSection',
                                            label: currentLabel,
                                            value: currentValue.join(' ').trim()
                                        });
                                    }
                                    currentLabel = line.replace(/[:\\*]\\s*$/, '').trim();
                                    currentValue = [];
                                } else if (currentLabel && line) {
                                    currentValue.push(line);
                                }
                            }
                            
                            if (currentLabel && currentValue.length > 0) {
                                fallbackBlocks.push({
                                    type: 'labeledSection',
                                    label: currentLabel,
                                    value: currentValue.join(' ').trim()
                                });
                            }
                            
                            if (fallbackBlocks.length > 0) {
                                window.webkit.messageHandlers.alertsParser.postMessage({ 
                                    ok: true, 
                                    blocks: fallbackBlocks,
                                    matchedTitle: 'fallback-text-parse',
                                    targetTitle: targetAlertTitle || '',
                                    targetIndex: targetAlertIndex,
                                    matchMethod: 'text-fallback'
                                });
                            } else {
                                // Ultimate fallback
                                fallbackBlocks.push({
                                    type: 'paragraph',
                                    text: allText.trim()
                                });
                                window.webkit.messageHandlers.alertsParser.postMessage({ 
                                    ok: true, 
                                    blocks: fallbackBlocks,
                                    matchedTitle: 'fallback-raw-text',
                                    targetTitle: targetAlertTitle || '',
                                    targetIndex: targetAlertIndex,
                                    matchMethod: 'raw-text-fallback'
                                });
                            }
                        } catch(e) {
                            window.webkit.messageHandlers.alertsParser.postMessage({ ok: false, error: e.message });
                        }
                    }, 300);
                    
                } catch(e) {
                    window.webkit.messageHandlers.alertsParser.postMessage({ ok: false, error: e.message });
                }
            })();
            """#
            webView.evaluateJavaScript(parseScript, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }

        // Keep the embedded view focused on the original alert content; open new links externally.
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let targetURL = navigationAction.request.url {
                // Allow javascript: URLs to execute inline for in-page controls
                if targetURL.scheme == "javascript" {
                    decisionHandler(.allow)
                    return
                }
                
                // Allow same-document fragment navigation explicitly
                if let current = webView.url,
                   targetURL.scheme == current.scheme,
                   targetURL.host == current.host,
                   targetURL.path == current.path,
                   targetURL.fragment != nil {
                    decisionHandler(.allow)
                    return
                }

                // Allow in-page fragment changes and same-origin navigations (enable interactive toggles)
                if let currentURL = webView.url,
                   currentURL.scheme?.hasPrefix("http") == true,
                   targetURL.scheme?.hasPrefix("http") == true {
                    if currentURL.host == targetURL.host {
                        decisionHandler(.allow)
                        return
                    }
                }

                // Handle target=_blank: allow same-origin inline, external in browser
                if navigationAction.targetFrame == nil {
                    if let current = webView.url {
                        // Allow about:blank new windows inline (used by some expanders)
                        if targetURL.scheme == "about" && targetURL.absoluteString == "about:blank" {
                            decisionHandler(.allow)
                            return
                        }
                        // Allow inline for same-origin or Apple-owned hosts
                        if current.host == targetURL.host || isAppleDomain(targetURL.host) {
                            webView.load(URLRequest(url: targetURL))
                            decisionHandler(.cancel)
                            return
                        }
                    }
                    // Fallback: open externally
                    NSWorkspace.shared.open(targetURL)
                    decisionHandler(.cancel)
                    return
                }

                // Non-http(s) schemes open externally
                if targetURL.scheme != "http" && targetURL.scheme != "https" {
                    NSWorkspace.shared.open(targetURL)
                    decisionHandler(.cancel)
                    return
                }

                // External domains open in default browser, unless Apple domain
                if targetURL.host != parent.url.host && !isAppleDomain(targetURL.host) {
                    NSWorkspace.shared.open(targetURL)
                    decisionHandler(.cancel)
                    return
                }
            }

            // Default allow
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // If the site attempts to open a new window (target=_blank), keep same-origin and Apple domains inside, and allow about:blank
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                if url.scheme == "about" && url.absoluteString == "about:blank" {
                    return nil // let WebKit handle about:blank inline
                }
                if let current = webView.url {
                    if current.host == url.host || isAppleDomain(url.host) {
                        webView.load(URLRequest(url: url))
                        return nil
                    }
                }
            }
            return nil
        }

        // MARK: - WKScriptMessageHandler
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "consoleLog" {
                if let logMessage = message.body as? String {
                    print("🌐 JS Console: \(logMessage)")
                }
                return
            }
            
            if message.name == "alertsParser" {
                guard let dict = message.body as? [String: Any] else {
                    print("❌ AlertWebView: Received invalid message body")
                    return
                }
                
                if let ok = dict["ok"] as? Bool, ok, let blocksArray = dict["blocks"] as? [[String: Any]] {
                    let matchedTitle = dict["matchedTitle"] as? String ?? "unknown"
                    let targetTitle = dict["targetTitle"] as? String ?? "unknown"
                    let targetIndex = dict["targetIndex"] as? Int ?? -1
                    let matchMethod = dict["matchMethod"] as? String ?? "unknown"
                    
                    print("✅ AlertWebView: Received \(blocksArray.count) blocks")
                    print("   Target: '\(targetTitle)' [index \(targetIndex)]")
                    print("   Matched: '\(matchedTitle)' (method: \(matchMethod))")
                    
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: blocksArray, options: [])
                        let blocks = try JSONDecoder().decode([AlertBlock].self, from: jsonData)
                        DispatchQueue.main.async {
                            self.parent.onParsedBlocks(blocks)
                        }
                    } catch {
                        print("❌ AlertWebView: Failed to decode blocks: \(error)")
                    }
                } else if let error = dict["error"] as? String {
                    print("❌ AlertWebView: JS error: \(error)")
                }
            }
        }
    }
}

struct AlertDetailView: View {
    let title: String
    let url: URL
    let alertIdentifier: String
    let alertID: String
    let alertIndex: Int
    let totalAlerts: Int
    @State private var isLoading: Bool = true
    @State private var parsedBlocks: [AlertBlock] = []

    var body: some View {
        VStack(spacing: 0) {
            // Embedded header
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(2)
                Spacer()
                if isLoading && parsedBlocks.isEmpty {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.bottom, 6)

            if parsedBlocks.isEmpty {
                // Placeholder while parsing
                VStack(alignment: .leading, spacing: 8) {
                    GlassDivider(opacity: 0.08)
                    Text("Loading alert details…")
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.6))
                        .redacted(reason: .placeholder)
                    Text("Parsing source page…")
                        .font(.system(size: ParsedAlertView.Metrics.bodySize))
                        .foregroundColor(.white.opacity(0.6))
                        .redacted(reason: .placeholder)
                }
            } else {
                ParsedAlertView(blocks: parsedBlocks, isEmbedded: true)
            }
        }
        .overlay(
            // Hidden web view that performs parsing and calls back with blocks
            AlertWebView(
                url: url,
                alertIdentifier: alertIdentifier,
                alertID: alertID,
                alertIndex: alertIndex,
                totalAlerts: totalAlerts,
                isLoading: $isLoading,
                onParsedBlocks: { blocks in
                    self.parsedBlocks = blocks
                }
            )
            .frame(width: 0, height: 0)
            .opacity(0)
        )
    }
}

#Preview("AlertDetailView Preview") {
    let sampleBlocks: [AlertBlock] = [
        AlertBlock(type: "labeledSection", level: nil, text: nil, links: nil, items: nil, label: "Severity:", value: "Moderate"),
        AlertBlock(type: "labeledSection", level: nil, text: nil, links: nil, items: nil, label: "Weather Event Onset", value: "Today 3:00 PM"),
        AlertBlock(type: "labeledSection", level: nil, text: nil, links: nil, items: nil, label: "Description", value: "* WHAT... Heavy rain expected. * WHERE... Portions of the area. * WHEN... Through this evening."),
        AlertBlock(type: "labeledSection", level: nil, text: nil, links: [AlertLink(href: "https://example.com", text: "View Alert Source")], items: nil, label: "Issued By", value: "National Weather Service")
    ]

    return ZStack {
        Color.black.edgesIgnoringSafeArea(.all)
        AlertDetailView(
            title: "Flood Watch",
            url: URL(string: "https://weatherkit.apple.com/weather-alerts?ids=example")!,
            alertIdentifier: "Flood Watch",
            alertID: "example",
            alertIndex: 0,
            totalAlerts: 1
        )
        .onAppear {
            // Simulate parsed content for the preview
            // Note: In previews, the web view won't run; we inject sample blocks.
        }
    }
}
