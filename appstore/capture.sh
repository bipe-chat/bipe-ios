#!/usr/bin/env bash
# Captures the raw App Store screenshots (bipe#454) from the UI test StoreScreenshotTests.
#
#   appstore/capture.sh <iphone69|ipad13> [light|dark]
#
# Writes appstore/raw/<device>/<appearance>/<slug>.png and <slug>.elements.json. Commit them under <locale>/: the bipe-web build (bipe#455, #466)
# makes the store panels on bipe.chat/sobre/marca/ from them. The screens are mock screens with the sample cast (bipe-shared/product/cast.json)
# and pt-BR text, so two runs give the same images.
#
# Needs the simulator named in appstore/devices.mjs and the cast photos in ../bipe-web/src/cast/photos
# (BIPE_CAST_PHOTOS overrides the folder). DERIVED_DATA_PATH sets xcodebuild's -derivedDataPath.
# It never downloads a simulator or a runtime: a missing one stops the script.
set -euo pipefail

usage="usage: appstore/capture.sh <iphone69|ipad13> [light|dark]"
DEVICE="${1:?$usage}"
APPEARANCE="${2:-light}"
case "$APPEARANCE" in
  light|dark) ;;
  *) echo "$usage" >&2; exit 1 ;;
esac

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
OUT="$ROOT/appstore/raw/$DEVICE/$APPEARANCE"
rm -rf "$OUT"
mkdir -p "$OUT"

# Export the attachments also when a test fails: the captures it took show what broke.
set +e
TEST_RUNNER_BIPE_CAST_PHOTOS="$PHOTOS" xcodebuild test \
  -project ElementX.xcodeproj \
  -scheme UITests \
  -destination "platform=iOS Simulator,id=$SIM_ID" \
  ${DERIVED_DATA_PATH:+-derivedDataPath "$DERIVED_DATA_PATH"} \
  -resultBundlePath "$RESULT" \
  -only-testing:UITests/StoreScreenshotTests \
  -quiet
TEST_STATUS=$?
set -e

EXPORT="$WORK/attachments"
mkdir -p "$EXPORT"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$EXPORT" >/dev/null

# Keep only the named captures (`<slug>`), renamed to <slug>.png, and check their pixel size. The element
# lists (`<slug>.elements`) become <slug>.elements.json: bipe-web places the panel callouts with them.
python3 - "$EXPORT" "$OUT" "$WIDTH" "$HEIGHT" <<'PY'
import json, os, re, shutil, subprocess, sys

export, out, width, height = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
with open(os.path.join(export, "manifest.json"), encoding="utf-8") as handle:
    manifest = json.load(handle)

wrong = []
for test in manifest:
    for attachment in test["attachments"]:
        name = attachment["suggestedHumanReadableName"]
        source = os.path.join(export, attachment["exportedFileName"])
        # Names come back as "<slug>_0_<uuid>.png" or "<slug>.png"; the element lists as "<slug>.elements...".
        match = re.match(r"([a-z0-9]+(?:-[a-z0-9]+)*)(\.elements)?(?:_\d+_|\.|$)", name)
        if not match:
            continue
        slug, is_elements = match.group(1), bool(match.group(2))
        with open(source, "rb") as handle:
            head = handle.read(8)
        kind = "png" if head.startswith(b"\x89PNG") else repr(head[:1])
        print(f"attachment {name} -> {attachment['exportedFileName']} ({kind})")
        if is_elements:
            if not head.lstrip().startswith(b"{"):
                wrong.append(f"{slug}.elements is not JSON")
                continue
            shutil.copyfile(source, os.path.join(out, f"{slug}.elements.json"))
            continue
        if not head.startswith(b"\x89PNG"):
            continue
        target = os.path.join(out, f"{slug}.png")
        shutil.copyfile(source, target)
        info = subprocess.run(["sips", "-g", "pixelWidth", "-g", "pixelHeight", target],
                              capture_output=True, text=True, check=True).stdout
        size = tuple(int(v) for v in re.findall(r"pixel(?:Width|Height): (\d+)", info))
        if size != (width, height):
            wrong.append(f"{slug}.png is {'x'.join(map(str, size)) or 'unreadable'}, expected {width}x{height}")

names = sorted(os.listdir(out))
print("captured:", ", ".join(names) if names else "nothing")
if wrong:
    print("\n".join(wrong), file=sys.stderr)
    sys.exit(1)
PY

if [ "$TEST_STATUS" -ne 0 ]; then
  echo "StoreScreenshotTests failed on $DEVICE. appstore/raw/$DEVICE/$APPEARANCE holds what it captured. Do not ship these." >&2
  echo "Result bundle with the failure: $RESULT" >&2
  exit "$TEST_STATUS"
fi

rm -rf "$WORK"

echo "raw screenshots: appstore/raw/$DEVICE/$APPEARANCE"
