#!/usr/bin/env bash
# Captures the raw App Store screenshots (bipe#454) from the UI test StoreScreenshotTests.
#
#   appstore/capture.sh <iphone69|ipad13> [light|dark] [--locale pt-BR|en-US]
#
# Writes appstore/raw/<device>/<appearance>/<locale>/<slug>.png (git-ignored). The bipe-web image builder (bipe#455)
# makes the store panels from them. The screens are mock screens with the sample cast (bipe-shared/product/cast.json)
# and the content of bipe-shared/product/store-fixtures.json in that locale, with the app in that language, so two
# runs give the same images. Default: light, pt-BR.
#
# Needs the simulator named in appstore/devices.mjs and the cast photos in ../bipe-web/src/cast/photos
# (BIPE_CAST_PHOTOS overrides the folder). DERIVED_DATA_PATH overrides the shared DerivedData
# (bipe/docs/agents/builds.md).
# It never downloads a simulator or a runtime: a missing one stops the script.
set -euo pipefail

usage="usage: appstore/capture.sh <iphone69|ipad13> [light|dark] [--locale pt-BR|en-US]"
DEVICE=""
APPEARANCE="light"
LOCALE="pt-BR"
while [ $# -gt 0 ]; do
  case "$1" in
    --locale) LOCALE="${2:?$usage}"; shift 2 ;;
    light|dark) APPEARANCE="$1"; shift ;;
    -*) echo "$usage" >&2; exit 1 ;;
    *) [ -z "$DEVICE" ] || { echo "$usage" >&2; exit 1; }; DEVICE="$1"; shift ;;
  esac
done
[ -n "$DEVICE" ] || { echo "$usage" >&2; exit 1; }
case "$LOCALE" in
  pt-BR|en-US) ;;
  *) echo "$usage" >&2; exit 1 ;;
esac
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData/Bipe-iOS}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

device_field() {
  node --input-type=module -e \
    'import { device } from "./appstore/devices.mjs"; console.log(device(process.argv[1])[process.argv[2]]);' \
    "$DEVICE" "$1"
}
SIM_NAME="$(device_field simulator)" || { echo "Unknown device: $DEVICE" >&2; exit 1; }
WIDTH="$(device_field width)"
HEIGHT="$(device_field height)"

PHOTOS="${BIPE_CAST_PHOTOS:-$ROOT/../bipe-web/src/cast/photos}"
[ -d "$PHOTOS" ] || { echo "No cast photos in $PHOTOS. Clone bipe-web next to bipe-ios or set BIPE_CAST_PHOTOS." >&2; exit 1; }
PHOTOS="$(cd "$PHOTOS" && pwd)"

# The newest available simulator with that name. Never create or download one.
SIM_ID="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
found = [(runtime, d["udid"]) for runtime, devices in json.load(sys.stdin)["devices"].items()
         for d in devices if d["name"] == name and d.get("isAvailable")]
print(sorted(found)[-1][1] if found else "")
' "$SIM_NAME")"
[ -n "$SIM_ID" ] || { echo "No '$SIM_NAME' simulator installed. Install it in Xcode; this script does not download one." >&2; exit 1; }

xcrun simctl boot "$SIM_ID" 2>/dev/null || true
xcrun simctl bootstatus "$SIM_ID" -b >/dev/null
xcrun simctl ui "$SIM_ID" appearance "$APPEARANCE"
xcrun simctl status_bar "$SIM_ID" override \
  --time "9:41" \
  --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --operatorName "" \
  --batteryState charged --batteryLevel 100

WORK="$(mktemp -d "${TMPDIR:-/tmp}/bipe-appstore.XXXXXX")"
RESULT="$WORK/capture.xcresult"
OUT="$ROOT/appstore/raw/$DEVICE/$APPEARANCE/$LOCALE"
rm -rf "$OUT"
mkdir -p "$OUT"

# Export the attachments also when a test fails: the captures it took show what broke.
set +e
TEST_RUNNER_BIPE_CAST_PHOTOS="$PHOTOS" TEST_RUNNER_BIPE_STORE_LOCALE="$LOCALE" xcodebuild test \
  -project ElementX.xcodeproj \
  -scheme UITests \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT" \
  -only-testing:UITests/StoreScreenshotTests \
  -quiet
TEST_STATUS=$?
set -e

EXPORT="$WORK/attachments"
mkdir -p "$EXPORT"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$EXPORT" >/dev/null

# Keep only the named captures (`<slug>`), renamed to <slug>.png, and check their pixel size.
python3 - "$EXPORT" "$OUT" "$WIDTH" "$HEIGHT" <<'PY'
import json, os, re, shutil, subprocess, sys

export, out, width, height = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
with open(os.path.join(export, "manifest.json"), encoding="utf-8") as handle:
    manifest = json.load(handle)

wrong = []
for test in manifest:
    for attachment in test["attachments"]:
        slug = attachment["suggestedHumanReadableName"].split("_0_")[0].removesuffix(".png")
        if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", slug):
            continue
        target = os.path.join(out, f"{slug}.png")
        shutil.copyfile(os.path.join(export, attachment["exportedFileName"]), target)
        info = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", target],
                              capture_output=True, text=True, check=True).stdout
        size = tuple(int(v) for v in re.findall(r"pixel(?:Width|Height): (\d+)", info))
        if size != (width, height):
            wrong.append(f"{slug}.png is {size[0]}x{size[1]}, expected {width}x{height}")

names = sorted(os.listdir(out))
print("captured:", ", ".join(names) if names else "nothing")
if wrong:
    print("\n".join(wrong), file=sys.stderr)
    sys.exit(1)
PY

if [ "$TEST_STATUS" -ne 0 ]; then
  echo "StoreScreenshotTests failed on $DEVICE. appstore/raw/$DEVICE/$APPEARANCE/$LOCALE holds what it captured. Do not ship these." >&2
  echo "Result bundle with the failure: $RESULT" >&2
  exit "$TEST_STATUS"
fi

rm -rf "$WORK"

echo "raw screenshots: appstore/raw/$DEVICE/$APPEARANCE/$LOCALE"
