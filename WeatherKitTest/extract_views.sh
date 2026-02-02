#!/bin/bash
set -euo pipefail

# Script to extract full view implementations from the original monolithic file
# and overwrite placeholder files. Then, restore the minimal app entry if needed.

# Detect the original monolith source file
CANDIDATES=(
  "WeatherKitTestApp-BACKUP.swift"
  "WeatherKitTestApp-ORIG.swift"
  "WeatherKitTestApp.swift"
)

ORIGINAL_FILE=""
for f in "${CANDIDATES[@]}"; do
  if [[ -f "$f" ]]; then
    LINES=$(wc -l < "$f" | tr -d ' ')
    if [[ "$LINES" -ge 2000 ]]; then
      ORIGINAL_FILE="$f"
      break
    fi
  fi
done

if [[ -z "$ORIGINAL_FILE" ]]; then
  echo "ERROR: Could not find the original monolithic WeatherKitTestApp.swift."
  echo "Please restore it as WeatherKitTestApp-BACKUP.swift or WeatherKitTestApp-ORIG.swift,"
  echo "or ensure WeatherKitTestApp.swift contains the monolith (>= 2000 lines)."
  exit 1
fi

echo "Using original source: $ORIGINAL_FILE"

# Helper to extract a range with a header into a file
extract_with_header() {
  local target_file="$1"; shift
  local header="$1"; shift
  local start_line="$1"; shift
  local end_line="$1"; shift

  echo "Writing $target_file (lines $start_line-$end_line from $ORIGINAL_FILE)..."
  printf "%s\n" "$header" > "$target_file"
  sed -n "${start_line},${end_line}p" "$ORIGINAL_FILE" >> "$target_file"
  echo "✅ Created $target_file"
}

# 1) WeatherEffects.swift (lines 1051-2442)
extract_with_header \
  "WeatherEffects.swift" \
  "import SwiftUI\n\n// MARK: - Weather Effects\n" \
  1051 2442

# 2) CurrentWeatherView.swift (lines 2444-2912)
extract_with_header \
  "CurrentWeatherView.swift" \
  "import SwiftUI\nimport WeatherKit\n\n// MARK: - Current Weather View\n" \
  2444 2912

# 3) ForecastViews.swift (lines 2913-3120)
extract_with_header \
  "ForecastViews.swift" \
  "import SwiftUI\nimport WeatherKit\n\n// MARK: - Forecast Views\n" \
  2913 3120

# 4) WeatherAlertsViews.swift (lines 3121-4257)
extract_with_header \
  "WeatherAlertsViews.swift" \
  "import SwiftUI\nimport WeatherKit\nimport WebKit\nimport AppKit\n\n// MARK: - Weather Alerts Views\n" \
  3121 4257

# 5) WeatherChartsViews.swift (lines 4258-4943)
extract_with_header \
  "WeatherChartsViews.swift" \
  "import SwiftUI\nimport WeatherKit\nimport Charts\n\n// MARK: - Weather Charts Views\n" \
  4258 4943

# 6) WeatherMapView.swift (lines 4944-5395)
extract_with_header \
  "WeatherMapView.swift" \
  "import SwiftUI\nimport MapKit\nimport CoreLocation\nimport WeatherKit\nimport AppKit\n\n// MARK: - Weather Map View\n" \
  4944 5395

# Attempt to restore minimal app entry if monolith is currently active
APP_FILE="WeatherKitTestApp.swift"
if [[ -f "$APP_FILE" ]]; then
  APP_LINES=$(wc -l < "$APP_FILE" | tr -d ' ' || echo 0)
  if [[ "$APP_LINES" -ge 2000 ]]; then
    # Monolith is active as WeatherKitTestApp.swift; try to swap in the minimal version
    if [[ -f "WeatherKitTestApp-NEW.swift" ]]; then
      echo "Restoring minimal app entry (WeatherKitTestApp-NEW.swift -> WeatherKitTestApp.swift)..."
      # Backup the monolith if no ORIG backup exists
      if [[ ! -f "WeatherKitTestApp-ORIG.swift" ]]; then
        mv "$APP_FILE" "WeatherKitTestApp-ORIG.swift"
      else
        mv "$APP_FILE" "${APP_FILE}.bak.$(date +%s)"
      fi
      mv "WeatherKitTestApp-NEW.swift" "$APP_FILE"
      echo "✅ Minimal app entry restored."
    else
      echo "NOTE: WeatherKitTestApp-NEW.swift not found; skipping app entry restore."
    fi
  else
    echo "Minimal app entry already present (WeatherKitTestApp.swift < 2000 lines)."
  fi
fi

echo ""
echo "🎉 Extraction complete. Next steps:"
echo "1) Ensure these files are added to your Xcode target (if needed):"
echo "   - WeatherEffects.swift\n   - CurrentWeatherView.swift\n   - ForecastViews.swift\n   - WeatherAlertsViews.swift\n   - WeatherChartsViews.swift\n   - WeatherMapView.swift"
echo "2) Product > Clean Build Folder (Cmd+Shift+K)"
echo "3) Build (Cmd+B) and run (Cmd+R)"
