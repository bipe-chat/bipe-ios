#!/usr/bin/env bash
# Archive a Release build and upload it to App Store Connect (TestFlight) with the Centaur Labs team.
# Needs: the "Proseio" app record for br.com.proseio.app.dev, and an Apple account signed in to Xcode on this Mac.
# Usage (repo root): Tools/Proseio/testflight.sh [extra xcodebuild settings]
set -euo pipefail
cd "$(dirname "$0")/../.."

# Unique, increasing build number per upload (App Store Connect rejects duplicates).
BUILD_NUMBER=$(date -u +%Y%m%d%H%M)
ARCHIVE=build/Proseio-$BUILD_NUMBER.xcarchive
PACKAGES=${CLONED_SOURCE_PACKAGES:-}

echo "Archiving build $BUILD_NUMBER"
xcodebuild archive -project ElementX.xcodeproj -scheme ElementX -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  ${PACKAGES:+-clonedSourcePackagesDirPath "$PACKAGES"} \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" "$@"

echo "Uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist Tools/Proseio/ExportAppStore.plist \
  -exportPath "build/appstore-$BUILD_NUMBER" -allowProvisioningUpdates

echo "Uploaded build $BUILD_NUMBER. Add it to the external TestFlight group in App Store Connect."
