# App Name Rename to WeatherStatus

## Checklist
- [x] Update Xcode product naming so the shipped app bundle resolves to `WeatherStatus` while keeping the target and scheme as `WeatherKitTest`
- [x] Replace remaining runtime-visible `WeatherKitTest` strings that should show the shipped app name
- [x] Rebuild the macOS target, inspect the built bundle metadata, and capture review notes plus any durable lesson

## Review
- `project.pbxproj` now keeps the `WeatherKitTest` target and scheme intact while changing the built product reference, target product name, and Debug/Release `PRODUCT_NAME` values to `WeatherStatus`, so the app now builds as `WeatherStatus.app` without disrupting existing build commands.
- Runtime-visible copy was updated in `Info.plist` and `SettingsView.swift`, covering the location permission description, the Settings quit subtitle, and the fallback bundle-name display path.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 16, 2026, and the build output now lands at `/tmp/WeatherKitTestDerivedData/Build/Products/Debug/WeatherStatus.app`.
- Built-bundle verification succeeded: `CFBundleName` resolves to `WeatherStatus`, `NSLocationUsageDescription` resolves to `WeatherStatus uses your location to show local weather.`, and the compiled app binary contains the updated `Close WeatherStatus and remove it from the menu bar until the next launch.` Settings copy.
- Runtime smoke verification succeeded at a basic level: `open -n /tmp/WeatherKitTestDerivedData/Build/Products/Debug/WeatherStatus.app` launched the rebuilt app, and `ps -axo pid,ppid,%cpu,%mem,etime,command | rg "WeatherStatus"` showed the running process from the new app bundle path.
- Remaining warnings were unchanged from baseline: App Intents metadata extraction is still skipped because there is no `AppIntents.framework` dependency, the app icon set still reports unassigned children, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.

# Alerts Panel Detail Fix

## Checklist
- [x] Inspect the overview and dedicated alerts rendering paths to isolate why multiple alerts reuse the same detail content
- [x] Patch the dedicated alerts detail flow so each selected alert gets its own parsing state and WebKit load
- [x] Rebuild the macOS target and confirm the fix compiles cleanly
- [x] Add a review summary here and capture any new lesson in `tasks/lessons.md`

## Review
- Root cause: the dedicated alerts destination reused a single `AlertDetailView` instance as the selected alert changed, but that view owned parser state plus a hidden `WKWebView`. Because the stateful subtree never got a new identity, the first parsed payload could be reused for later selections even though the overview cards behaved correctly.
- `WeatherAlertsViews.swift` now makes `AlertDetailView` a thin keyed wrapper around a private `AlertDetailContent` view. The key is derived from the selected alert's ID, index, total-alert context, URL, and title, so switching alerts recreates the parser-backed subtree and forces a fresh WebKit load with clean local state.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 16, 2026.
- Remaining warnings were unchanged from baseline: App Intents metadata extraction is still skipped because there is no `AppIntents.framework` dependency, the app icon set still reports unassigned children, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not run an interactive GUI smoke test in the main alerts destination this turn, so the next direct check is to open a location with multiple active alerts and confirm each selection now shows its own bulletin content instead of reusing the first parsed alert.

# Offscreen CPU Investigation

## Checklist
- [x] Inspect the main-window visibility model, backdrop animation policy, and any always-on map/effect rendering paths
- [x] Tighten visibility tracking so offscreen or occluded windows do not keep the app in a live-render state
- [x] Suspend heavyweight main-window rendering when no forecast surface is actually visible
- [x] Rebuild the macOS target and record verification results plus any remaining runtime gaps
- [x] Add a review summary here and capture any new lessons in `tasks/lessons.md`

## Review
- Live-process finding: the hot process was the Xcode-run debug app (`pid 58014` at about 94% CPU), while the separately installed desktop build (`pid 30008`) was close to idle. That immediately narrowed the issue to the current debug window shell instead of a general always-on background fetch loop.
- Sampled root cause: the main thread was stuck in a SwiftUI/AppKit toolbar layout cycle centered on `ToolbarItemHostingView` and `SystemSegmentedControl._overrideSizeThatFits`, which points at the principal segmented `Picker` in `MainWeatherWindowView.swift` rather than the weather-effect stack.
- `MainWeatherWindowView.swift` no longer treats SwiftUI `onAppear`/`onDisappear` as the source of truth for actual window visibility. The app now relies on the AppKit-backed visibility observer instead of optimistically flipping `isMainWindowVisible` to `true` just because the scene hierarchy exists.
- The window observer now also resyncs visibility after move and live-resize events, which makes the occlusion-backed state less likely to drift while the user is repositioning the window or changing what is actually exposed on screen.
- `MainWeatherDetailView` now suspends heavyweight detail rendering entirely when the main window is not actually visible. When the window is fully occluded or miniaturized, the app falls back to a cheap static gradient instead of continuing to drive the animated backdrop, overview stack, or map destination offscreen.
- To eliminate the confirmed layout hot spot, the toolbar’s principal segmented `Picker` was replaced with a simpler destination `Menu` in the automatic toolbar group. That preserves toolbar-based destination switching without relying on the AppKit segmented control that the sample showed repeatedly recalculating its size.
- Follow-up sample on March 8, 2026 of the relaunched debug process (`pid 59266`, about 98% CPU) showed a second hot path inside our own sidebar rows: `WeatherSidebarSavedLocationItem.formattedLocalTime` was creating a new `DateFormatter` during repeated row body/layout evaluation, and the row subtree was still alive even when the main window was not visible.
- The main-window shell now suspends the entire `NavigationSplitView` while the window is offscreen instead of only suspending the detail pane, which prevents hidden sidebar rows from continuing to participate in layout and update cycles.
- `WeatherSidebarSavedLocationItem` now caches its short time formatter by time-zone identifier instead of constructing a brand-new `DateFormatter` for every row/body pass.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is still skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: the already-running debug process does not pick up rebuilt code, so the next runtime check is to stop the current Xcode run, relaunch the freshly built debug app, then confirm `WeatherKitTest` CPU falls back near idle when the app is inactive or the main window is not frontmost. If it does not, the next step is another `sample` on the relaunched PID to see whether any row-scroll effects are still keeping the sidebar hot.

# Weather-Branded Settings Redesign

## Checklist
- [x] Inspect the current settings implementation, app shell styling, and relevant macOS/SwiftUI guidance
- [x] Rebuild `SettingsView.swift` around a two-pane weather-branded settings shell with shared section content
- [x] Preserve existing settings behavior and storage keys while reorganizing the information architecture
- [x] Update the dedicated `Settings` scene sizing in `WeatherKitTestApp.swift`
- [x] Build the macOS target and record verification results plus remaining risks
- [x] Add a review summary here and capture any new lessons in `tasks/lessons.md`

## Review
- `SettingsView.swift` now uses a weather-branded `NavigationSplitView` settings shell for the live Settings scene, with a left rail for section navigation and a scrollable detail column containing three large cards: General, Refresh, and About.
- The old overlay path was kept as a compact wrapper, but it now reuses the same section/card content instead of maintaining a separate stacked-divider design.
- The app entry point no longer routes the Settings scene through `WeatherSettingsSceneView`; `WeatherKitTestApp.swift` now instantiates `InAppSettingsView` directly to avoid wrapper-symbol lookup issues during compilation.
- Existing settings behavior and storage keys were preserved: temperature units still trigger `viewModel.refreshCurrentWeather()`, refresh interval stays bound to `refreshIntervalMinutes`, energy saver and launch-at-login toggles persist, and the existing update/refresh/quit actions still call the same underlying logic.
- `WeatherKitTestApp.swift` now gives the Settings scene a wider ideal size and default window size so the split layout has enough room to breathe.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 7, 2026.
- Remaining warnings were unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not perform an interactive GUI smoke test of the resized Settings window, `Cmd+,`, toolbar `SettingsLink`, or the popover settings entry in this turn.

# Premium Sidebar Motion Polish

## Checklist
- [x] Inspect the main window shell, sidebar implementation, motion/accessibility policy, and relevant SwiftUI animation guidance
- [x] Add shared sidebar motion tokens in `WeatherDesignSystem.swift`
- [x] Drive the main window shell animation from a derived sidebar-visibility signal in `MainWeatherWindowView.swift`
- [x] Choreograph sidebar panel reveal timing and detail-surface response while keeping `NavigationSplitView`
- [x] Add scroll-linked sidebar panel and row polish without storing scroll position in view state
- [x] Improve suggestion-list, selection, hover, and row interaction motion while preserving existing behavior
- [x] Rebuild the macOS target and document verification results plus any remaining risks

## Review
- `WeatherDesignSystem.swift` now defines shared motion tokens for sidebar reveal, interaction timing, stagger delays, detail lift, and scroll-linked transform limits, plus an availability-safe soft top scroll-edge helper.
- `MainWeatherWindowView.swift` now derives a single sidebar-visibility signal from `NavigationSplitView` state, uses it for the search-triggered reopen animation, stages sidebar panels on reveal, and gives the detail destination stack a coordinated lift and highlight when the sidebar is visible.
- The sidebar scroll region now uses `LazyVStack`, applies scroll-linked panel transforms with `visualEffect`, and gently compresses non-selected rows at the scroll edges with `scrollTransition` while keeping selected rows prominent.
- Saved-location rows and suggestion rows now animate full-row emphasis instead of only changing trailing chrome, so hover, selection, and suggestion appearance feel consistent with the new shell motion.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 7, 2026.
- Remaining build warnings are pre-existing project warnings: the target still includes `Info.plist` in Copy Bundle Resources, and App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency.
- Remaining verification gap: I did not run an interactive manual smoke test for sidebar toggling, `Command-L` reopening, or live scroll feel in the macOS app window in this turn.

# Current Location Reliability Fix

## Checklist
- [x] Inspect the current-location authorization/request state machine and failure paths
- [x] Fix permission-prompt timeout handling so location requests survive the auth decision flow
- [x] Relax immediate-location fallback selection for coarse but still useful desktop locations
- [x] Rebuild the macOS target and record verification results plus remaining risks

## Review
- `WeatherViewModel.swift` no longer starts the 12-second location timeout before the user answers the permission prompt. The timeout now begins only after the app is actually authorized and a real location request is underway.
- A non-user-initiated startup fetch no longer silently forces an authorization prompt path. If the app has a usable cached/current system location it uses it immediately; otherwise it waits for an explicit user-triggered location request.
- The immediate-location fallback now accepts older/coarser desktop locations when they are still reasonable for weather, and persisted current-location data now preserves the recorded horizontal accuracy instead of pretending every cached point is equally precise.
- Authorized location requests now warm the location manager with `startUpdatingLocation()` alongside the one-shot request so macOS has a better chance of returning a fix before the timeout expires.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 7, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not perform an interactive permission-flow smoke test in the running macOS app in this turn, so the next best check is to trigger `Use Current Location` and confirm the app either resolves promptly or shows a permission-denied message instead of waiting indefinitely.

# Current Location Loading-State Follow-up

## Checklist
- [x] Inspect why current-location UI can keep animating after the request should have ended
- [x] Fix stale loading-state mutations for fast current-location resolution and refresh fallbacks
- [x] Rebuild the macOS target and record verification results plus remaining risks

## Review
- `WeatherViewModel.swift` no longer schedules current-location loading-flag changes with `DispatchQueue.main.async` inside the start path. The request state now updates synchronously, so an immediate cached/system location cannot finish and then have a queued block turn the “finding current location” spinner back on afterward.
- The current-location retry path now uses the same shared loading-state helper, which keeps the retry UI consistent with the main lookup lifecycle.
- `manualRefresh()` now only raises the foreground loading overlay when there is an actual active location to refresh. If the app has no current coordinates yet and is still waiting for the user to grant location access, refresh no longer leaves the UI spinning indefinitely.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 7, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not run the live macOS app and manually confirm that the current-location button spinner stops after a fallback/immediate resolution or after a no-permission refresh path.

# Current Location Phase Visibility Follow-up

## Checklist
- [x] Inspect whether the app is hanging in Core Location or in the downstream weather fetch
- [x] Add explicit loading-phase reporting so the UI distinguishes current-location resolution from weather loading
- [x] Add a timeout for the active weather fetch path so it cannot spin indefinitely
- [x] Rebuild the macOS target and record verification results plus remaining risks

## Review
- `WeatherViewModel.swift` now tracks an explicit `ActiveLoadPhase`, so the app can distinguish between resolving the user’s current coordinates and fetching weather data for an already-resolved location.
- The active forecast load path now has its own 18-second timeout. If WeatherKit or the downstream air-quality fetch never returns, the active request is cancelled and the UI reports that the location was found but weather data took too long to load.
- `QuickStatusPopoverView.swift` now surfaces the current load phase directly in the summary and empty-state copy, and `MainWeatherWindowView.swift` mirrors that phase in both the current-location sidebar row and the empty overview state.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 7, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not run the macOS app interactively this turn, so the next runtime check is to trigger `Use Current Location` and confirm the UI first says `Finding your current location...`, then either resolves weather normally or changes to a weather-fetch timeout/error within about 18 seconds after location resolution.

# macOS Current Location Prompt Follow-up

## Checklist
- [x] Inspect the macOS-specific Core Location authorization flow for `LSUIElement` behavior
- [x] Replace the stuck `.notDetermined` path with the correct macOS service-start flow and bounded timeout messaging
- [x] Rebuild the macOS target and record verification results plus remaining risks

## Review
- On macOS, the user-initiated `.notDetermined` path in `WeatherViewModel.swift` now starts the location service directly instead of calling `requestWhenInUseAuthorization()`. That matches Apple’s documented macOS Core Location behavior and avoids leaving the app parked in a pending-authorization state forever.
- The current-location timeout now reports a permission-specific message when authorization is still `.notDetermined` after the timeout window, which gives the user a direct next step if the system prompt never surfaced.
- `locationManagerDidChangeAuthorization(_:)` now avoids re-arming a second active location request when the timer-backed request is already in flight.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not run the macOS app interactively this turn, so the next runtime check is to trigger `Use Current Location` and confirm the app either begins location resolution immediately or exits with the new permission-pending error within about 12 seconds instead of sitting on `Finding your current location...`.

# Location Permission Recovery UX

## Checklist
- [x] Inspect where the app can surface recovery actions after a pending or denied location permission state
- [x] Promote a real foreground window before first-time popover location requests and add a direct Location Settings shortcut
- [x] Rebuild the macOS target and record verification results plus remaining risks

## Review
- `QuickStatusPopoverView.swift` now promotes the full forecast window before a first-time location request when authorization is still `.notDetermined`, giving macOS a stronger foreground surface for the permission flow than the transient status-bar popover alone.
- `WeatherViewModel.swift` now exposes a dedicated location-settings recovery shortcut, and the popover, main overview empty state, and legacy content error state all surface an `Open Location Settings` action when permission is pending, denied, or restricted.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not run the macOS app interactively this turn, so the next runtime check is to trigger `Use Current Location`, confirm the full forecast window comes forward for first-time authorization, and use the new `Open Location Settings` action if macOS still leaves the permission in a pending state.

# macOS Location Privacy Key Fix

## Checklist
- [x] Confirm whether the app declares the correct macOS location privacy usage key
- [x] Replace the iOS-only plist key with the correct macOS location usage key
- [x] Rebuild the macOS target and record verification results plus remaining risks

## Review
- `Info.plist` previously declared `NSLocationWhenInUseUsageDescription`, which Apple documents for iOS. The app now declares `NSLocationUsageDescription`, which Apple documents for macOS location access.
- This is a stronger root-cause fix than the earlier prompt handling alone, because without the correct macOS privacy key the app may never present or register as a valid Location Services client the way we expect.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not launch the rebuilt app interactively this turn, so the next runtime check is to run this build, retry current location, and confirm the app now appears and authorizes correctly in macOS Location Services.

# Sidebar Transition Motion Tuning

## Checklist
- [x] Inspect the main-window sidebar visibility animation path and identify what is making collapse/expand feel slow or clunky
- [x] Simplify the shell motion so sidebar show/hide feels faster and smoother without fighting `NavigationSplitView`
- [x] Rebuild the macOS target and record verification results plus remaining risks

## Review
- `MainWeatherWindowView.swift` no longer uses the extra `sidebarRevealPhase` staging state for shell visibility changes. The sidebar panels now animate directly from `isSidebarVisible`, which removes a second layer of delayed child choreography fighting the split-view resize.
- Sidebar open/close timing in `WeatherDesignSystem.swift` is now shorter and asymmetric: reveal uses a quicker high-damping spring, collapse uses a brief ease-out, and the panel stagger delays are shorter and only applied on reveal.
- The detail surface response is lighter than before: the lift is smaller, the highlight/shadow are softer, and the expensive `compositingGroup()` wrapper around the full detail content has been removed during the shell transition.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not run the main window interactively this turn, so the next runtime check is to toggle the sidebar repeatedly in the full forecast window and confirm both collapse and re-expand feel quick, smooth, and free of the earlier draggy staging.

# PID 60682 CPU Investigation

## Checklist
- [x] Inspect the new `sample` output for `pid 60682` and confirm whether the latest hot path moved off the toolbar/sidebar fixes
- [x] Compare the sample to `QuickStatusPopoverView.swift` and `WeatherViewModel.swift` to identify any view-driven synchronous system queries
- [x] Refactor location authorization handling so SwiftUI bodies consume cached model state instead of calling Core Location synchronously during render
- [x] Remove any remaining popover timestamp formatter churn from the same hot render path
- [x] Rebuild the macOS target and record verification results plus any remaining runtime gaps
- [x] Add a review summary here and capture any new lessons in `tasks/lessons.md`

## Review
- Sampled root cause on March 8, 2026 for `pid 60682` showed the hot path had moved again: `QuickStatusPopoverView.body` was repeatedly evaluating `WeatherViewModel.shouldOfferLocationSettingsShortcut`, and that computed property was synchronously reading `CLLocationManager.authorizationStatus`, which in turn spent most of its time in Core Location XPC/TCC calls on the main thread.
- `WeatherViewModel.swift` now publishes a cached `locationAuthorizationStatus` value, syncs it once at startup, refreshes it when the app becomes active again, and updates it from `locationManagerDidChangeAuthorization(_:)`. The view-facing computed properties now read that cached model state instead of hitting Core Location from SwiftUI body evaluation.
- The user-initiated current-location flow still queries the live manager status when the action begins, but that sync now happens on the command path instead of the render path, which keeps the UI logic correct without reintroducing the body-driven XPC loop.
- `QuickStatusPopoverView.swift` now reuses shared per-time-zone date formatters for the popover’s local-time, updated-time, hourly, and daily labels instead of constructing fresh `DateFormatter` instances during repeated body passes.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- Runtime verification outside Xcode looks healthy: the freshly launched rebuilt app from `/tmp/WeatherKitTestDerivedData/Build/Products/Debug/WeatherKitTest.app` showed `0.0%` CPU in `ps`, while the still-running Xcode/debugger process `60682` remained hot at about `70.5%` CPU because it had not yet been stopped and relaunched with the new binary.
- Remaining verification gap: I cannot prove the fix inside the active Xcode session until that debug run is stopped and started again. The next direct check is to relaunch from Xcode, capture the new PID, and confirm the new debug-run process matches the standalone app's near-idle CPU when the UI is inactive or not visible.

# PID 65447 Follow-up

## Checklist
- [x] Sample the relaunched Xcode debug PID and confirm whether the new build moved off the Core Location render loop
- [x] Inspect the new hot stack and compare it to the current hidden-window suspension boundary
- [x] Extend offscreen suspension to remove the main window's SwiftUI/AppKit toolbar items when the window is not actually visible
- [x] Rebuild the macOS target and record verification results plus any remaining runtime gaps

## Review
- Sampled root cause on March 8, 2026 for `pid 65447` showed the relaunched Xcode debug process was no longer dominated by Core Location. Instead, the hot path was back in AppKit toolbar layout and menu-form updates: `NSToolbarItemViewer`, `ToolbarItemHostingView`, and `AppKitToolbarItem.updateMenuFormRepresentation(_:)`, all pointing to the `MainWeatherWindowView.swift` toolbar block around lines 47 through 81.
- The missing piece was that `MainWeatherWindowView.swift` had been suspending the main content tree when the window was hidden, but it was still attaching the SwiftUI toolbar unconditionally. That left AppKit free to keep churning on toolbar items even while the detail and sidebar content were already replaced with the cheap suspended surface.
- `MainWeatherWindowView.swift` now only renders `WindowToolbarBackdrop` and the `ToolbarItemGroup` when `allowsLiveWindowContent` is true, so a fully occluded or miniaturized main window drops its toolbar chrome along with the rest of the heavyweight UI.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded again on March 8, 2026.
- Standalone verification remains healthy after the rebuild: the existing `/tmp/WeatherKitTestDerivedData/Build/Products/Debug/WeatherKitTest.app` processes were still at `0.0%` CPU in `ps`, while the active Xcode/debugger process `65447` stayed hot at about `54.8%` because it was still the pre-patch run.
- Remaining verification gap: this latest toolbar-suspension fix will not affect `pid 65447` until Xcode stops and relaunches the app again. The next direct check is the next debug PID after relaunch.

# Main View Contrast Tuning

## Checklist
- [x] Inspect the main-window window chrome, backdrop, and shared surface styles to find why the detail content is visually washing out
- [x] Tighten the window/backdrop opacity model so the desktop no longer bleeds through bright daytime forecasts
- [x] Strengthen the shared shell and overview card surfaces so forecast content stays legible over animated backdrops
- [x] Rebuild the macOS target and record verification results plus remaining runtime gaps

## Review
- The washed-out look came from three layers stacking together: `MainWeatherWindowView.swift` configured the `NSWindow` as non-opaque with a clear background, `WeatherBackdrop.swift` used semi-transparent daytime/cloudy gradients, and the main forecast surfaces in `WeatherDesignSystem.swift` and `LiquidGlassDesign.swift` were still leaning on ultra-thin glass with only light overlays.
- The main window now keeps its transparent titlebar styling but no longer uses a literally clear window body. The AppKit window background is now an opaque dark blue, which prevents the desktop or editor behind the app from bleeding through the main forecast area.
- `WeatherBackdrop.swift` now lays down an opaque foundation gradient before the condition-specific animated layers and uses a slightly stronger daylight vignette, so bright/cloudy daytime forecasts stay atmospheric without becoming see-through.
- Shared shell panels and overview cards now sit on denser material with a darker substrate, and the small inset forecast tiles in `OverviewForecastDashboard.swift` now use their own darker inner surface style so their labels do not disappear into the background.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not run an interactive GUI pass against the rebuilt window in this turn, so the next direct check is to reopen the main forecast window and confirm the desktop no longer shows through the cloudy/daytime overview background or the 24-hour forecast cards.

# Main View Unit Refresh Fix

## Checklist
- [x] Inspect why the main window does not refresh unit-sensitive values when `useCelsius` changes
- [x] Fix the main-view observation path so the overview and map destinations recompute immediately on unit changes
- [x] Rebuild the macOS target and record verification results plus remaining runtime gaps

## Review
- The main-window unit bug had two causes. First, the overview destination in `OverviewForecastDashboard.swift` was formatting temperature and visibility from `UserDefaults.standard.bool(forKey: "useCelsius")` inside static helpers, which gave SwiftUI no observable state dependency for those labels. Second, `WeatherViewModel.refreshCurrentWeather()` was not publishing `objectWillChange`, so the settings toggle’s explicit refresh callback did not actually invalidate `ObservedObject` views in the main window.
- `OverviewForecastDashboard.swift` now observes `@AppStorage("useCelsius")` directly at the dashboard level and threads that unit preference into its formatting helpers for temperatures, visibility, and wind speed, so the overview content recomputes immediately when the setting changes.
- `MainWeatherWindowView.swift` now makes the map destination observe `@AppStorage("useCelsius")` as well, so its temperature and wind rows update in the same pass instead of staying on stale imperial values.
- `WeatherViewModel.swift` now emits `objectWillChange.send()` inside `refreshCurrentWeather()`, which keeps the existing settings-triggered refresh path meaningful for `ObservedObject` surfaces that depend on the view model.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not perform a live GUI toggle test in this turn, so the next direct runtime check is to switch between Fahrenheit and Celsius in Settings and confirm the overview hero, conditions, hourly, 10-day, AI summary, and map-condition rows all update immediately in the running main window.

# Popover Alert Deep-Link to Expanded Overview Alert

## Checklist
- [x] Add shared alert identity/navigation request types and route them through `AppShellState`
- [x] Convert the popover alert pill into a button that opens the main overview with the first alert targeted
- [x] Move overview alert expansion state to the parent flow and support scroll-to-expanded alert behavior
- [x] Reuse the shared alert identity in the dedicated Alerts destination so selection stays aligned
- [x] Build the macOS target and record verification results plus any remaining runtime gaps

## Review
- `AppShellState.swift` now carries a one-shot `pendingOverviewAlertRequest` with a stable alert key plus index fallback, and `showMainWindow(...)` can publish that request before bringing the main forecast window forward.
- `Models.swift` now centralizes alert identity extraction through `WeatherAlert.navigationTarget(at:)`, so the popover deep-link path, the overview cards, and the dedicated Alerts destination all resolve the same alert key and parsed alert ID.
- `QuickStatusPopoverView.swift` now renders the alert pill as a real `Button`. Tapping it opens the main window on Overview and targets the first active alert for expansion.
- `MainWeatherWindowView.swift` now owns overview alert expansion state in the parent destination, preserves multiple simultaneously expanded alerts, prunes stale keys when alerts change, and consumes the pending shell request after expanding and scrolling to the targeted alert card.
- `OverviewForecastDashboard.swift`, `WeatherAlertsViews.swift`, and `CurrentWeatherView.swift` now use the shared alert target identity with parent-driven expansion instead of duplicating local URL parsing inside each banner.
- `xcodebuild -project /Users/nikhilbolar/Documents/WeatherKitTest/WeatherKitTest.xcodeproj -scheme WeatherKitTest -configuration Debug -sdk macosx -derivedDataPath /tmp/WeatherKitTestDerivedData CODE_SIGNING_ALLOWED=NO build` succeeded on March 8, 2026.
- A lightweight runtime sanity check succeeded as well: `open -n /tmp/WeatherKitTestDerivedData/Build/Products/Debug/WeatherKitTest.app` launched the rebuilt app, and `pgrep -fl WeatherKitTest` showed running processes from the derived-data app bundle.
- Remaining build warnings are unchanged from baseline: App Intents metadata extraction is skipped because there is no `AppIntents.framework` dependency, and the target still copies `Info.plist` plus `tasks/*.md` into bundle resources.
- Remaining verification gap: I did not perform an interactive macOS click-through in this turn, so the next direct runtime check is to tap the popover alert pill with one and multiple active alerts and confirm the main window opens on Overview with the first alert already expanded.
