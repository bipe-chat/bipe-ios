#!/usr/bin/env bash
# Archive a Release build and upload it to App Store Connect (TestFlight) with the Centaur Labs team.
# Needs: the "Bipe" app record for chat.bipe.app.dev, and an Apple account signed in to Xcode on this Mac.
# Usage (repo root): Tools/Bipe/testflight.sh [extra xcodebuild settings]
set -euo pipefail
cd "$(dirname "$0")/../.."

# Unique, increasing build number per upload (App Store Connect rejects duplicates).
BUILD_NUMBER=$(date -u +%Y%m%d%H%M)
ARCHIVE=build/Bipe-$BUILD_NUMBER.xcarchive
PACKAGES=${CLONED_SOURCE_PACKAGES:-}

# App Store Connect API key, so xcodebuild can refresh profiles and upload without the Xcode GUI account.
# Key "Bipe CI" (App Manager): ~/.config/bipe/AuthKey_<id>.p8, backup in Keychain item bipe-asc-api-key.
ASC_KEY_ID=${ASC_KEY_ID:-M2VUX56QAJ}
ASC_ISSUER_ID=${ASC_ISSUER_ID:-3cfd203a-f83c-4f1b-8895-2f31c9c02a26}
ASC_KEY_PATH=${ASC_KEY_PATH:-$HOME/.config/bipe/AuthKey_$ASC_KEY_ID.p8}
AUTH=(-allowProvisioningUpdates)
if [ -f "$ASC_KEY_PATH" ]; then
  AUTH+=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")
fi

echo "Archiving build $BUILD_NUMBER"
xcodebuild archive -project ElementX.xcodeproj -scheme ElementX -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" "${AUTH[@]}" \
  ${PACKAGES:+-clonedSourcePackagesDirPath "$PACKAGES"} \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" "$@"

echo "Uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist Tools/Bipe/ExportAppStore.plist \
  -exportPath "build/appstore-$BUILD_NUMBER" "${AUTH[@]}"

echo "Uploaded build $BUILD_NUMBER. Add it to the external TestFlight group in App Store Connect."
