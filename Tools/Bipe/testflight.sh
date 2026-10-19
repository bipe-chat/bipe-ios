#!/usr/bin/env bash
# Archive a Release build and upload it to App Store Connect (TestFlight) with the Centaur Labs team.
# Needs: the "Bipe" app record for chat.bipe.app.dev, and an Apple account signed in to Xcode on this Mac.
# Usage (repo root): Tools/Bipe/testflight.sh [extra xcodebuild settings]
set -euo pipefail
cd "$(dirname "$0")/../.."

# Version and build number come from bipe-shared (ADR 0088): node tools/bump-build.mjs there, then commit
# and push bipe-shared and this repo before you upload. App Store Connect rejects a build number it has seen.
# shellcheck source=version.env
. Tools/Bipe/version.env
if [ -n "$(git status --porcelain -- Tools/Bipe/version.env)" ]; then
  echo "Tools/Bipe/version.env has uncommitted changes. Commit and push the bump first." >&2
  exit 1
fi
BUILD_NUMBER=$BIPE_BUILD
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

echo "Archiving $BIPE_VERSION ($BUILD_NUMBER)"
xcodebuild archive -project ElementX.xcodeproj -scheme ElementX -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" "${AUTH[@]}" \
  ${PACKAGES:+-clonedSourcePackagesDirPath "$PACKAGES"} \
  MARKETING_VERSION="$BIPE_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" "$@"

echo "Uploading to App Store Connect"
xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist Tools/Bipe/ExportAppStore.plist \
  -exportPath "build/appstore-$BUILD_NUMBER" "${AUTH[@]}"

echo "Uploaded $BIPE_VERSION ($BUILD_NUMBER). Giving it to the external testers."
ASC_KEY_ID=$ASC_KEY_ID ASC_ISSUER_ID=$ASC_ISSUER_ID ASC_KEY_PATH=$ASC_KEY_PATH node Tools/Bipe/testflight-distribute.mjs "$BUILD_NUMBER"
