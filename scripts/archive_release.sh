#!/usr/bin/env bash
# Archive Release build with automatic signing via the Xcode account (client team 63A35ZDM9C).
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHIVE=${1:-build/Goldn.xcarchive}
mkdir -p build
xcodebuild archive \
  -project SOLA.xcodeproj -scheme SOLA -configuration Release \
  -destination generic/platform=iOS \
  -archivePath "$ARCHIVE" -derivedDataPath build/DD \
  -allowProvisioningUpdates 2>&1 | tee build/archive.log | grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" || true
tail -1 build/archive.log
