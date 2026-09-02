#!/usr/bin/env bash
# Export the archive with automatic signing and upload it straight to App Store Connect
# (ExportUpload.plist: destination = upload). Uses the Xcode account session — no API key.
set -euo pipefail
cd "$(dirname "$0")/.."
ARCHIVE=${1:-build/Goldn.xcarchive}
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist scripts/ExportUpload.plist -allowProvisioningUpdates 2>&1 \
  | tee build/export.log | grep -E "error|Upload succeeded|EXPORT (SUCCEEDED|FAILED)|ITMS" || true
tail -1 build/export.log
