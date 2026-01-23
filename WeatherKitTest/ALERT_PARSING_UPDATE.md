# Weather Alert Parsing Update

## Summary
I've enhanced the weather alert rendering system to parse the HTML content from Apple's weather alert pages and render them natively in SwiftUI instead of just displaying the raw HTML in a WebView.

## Key Changes

### 1. Enhanced JavaScript Parsing
The JavaScript parsing code now:
- **Automatically expands collapsible sections** by clicking all expandable buttons before parsing
- **Uses multiple fallback selectors** to find the alert content container, making it more robust
- **Recursively parses nested elements** (DIVs and SECTIONs) to capture all content
- **Supports definition lists** (DL/DT/DD elements) commonly used in weather alerts
- **Extracts all text elements** as a fallback if the primary parsing strategy doesn't find content
- **Delays execution** by 0.5 seconds after page load to allow dynamic content to settle

### 2. Improved Native Rendering
The `ParsedAlertView` now:
- Supports definition lists for better structured data display
- Uses proper text wrapping with `fixedSize(horizontal: false, vertical: true)`
- Adds better spacing and visual hierarchy
- Displays links with icons for better visual feedback
- Handles empty text gracefully to avoid rendering blank sections

### 3. New Settings Toggle
Added a new toggle in the settings panel:
- **"Render Alerts Natively"** - When enabled, weather alerts are parsed and displayed using native SwiftUI components instead of a WebView
- Both toggles are now enabled by default for the best user experience
- The native rendering provides:
  - Faster loading times
  - Better accessibility
  - Consistent styling with the rest of the app
  - No web rendering overhead

### 4. Supported Content Types
The parser now recognizes and renders:
- **Headings** (H1-H6) with appropriate font sizes
- **Paragraphs** with embedded links
- **Ordered lists** (numbered)
- **Unordered lists** (bulleted)
- **Definition lists** (term: definition pairs)

## How It Works

1. When a weather alert is expanded, the app loads the alert URL in a WKWebView
2. After the page loads, JavaScript is injected to:
   - Click all expandable buttons to reveal hidden content
   - Traverse the DOM tree and extract structured content
   - Send the parsed data back to the native app via message handlers
3. The native app receives the parsed blocks and stores them
4. If "Render Alerts Natively" is enabled, the `ParsedAlertView` renders the blocks using SwiftUI
5. Otherwise, the styled WebView is displayed (with optional theming)

## Benefits

- **Better Performance**: Native rendering is faster than web rendering
- **Improved Accessibility**: Native SwiftUI components work better with VoiceOver and other accessibility features
- **Consistent Design**: Alerts match the app's design language
- **More Reliable**: Multiple fallback strategies ensure content is captured even if Apple changes their HTML structure
- **Expandable Content**: Automatically handles collapsible sections in the alert pages

## User Controls

Users can toggle between three modes via the settings:
1. **Native rendering** (parseAlertsToNative = true) - Clean, fast, accessible
2. **Themed WebView** (useThemedAlertWebView = true) - Styled HTML with dark mode
3. **Standard WebView** (both false) - Raw HTML as provided by Apple

## Testing Recommendations

- Test with various types of weather alerts (severe weather, winter storms, heat advisories, etc.)
- Verify that expandable sections are properly revealed and parsed
- Check that links open correctly in the default browser
- Ensure the native rendering matches the visual hierarchy of the original content
