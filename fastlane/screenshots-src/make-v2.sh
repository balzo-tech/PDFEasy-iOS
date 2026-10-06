#!/bin/bash
# Le catture del set di ottobre (index-v2.html), lingua per lingua: guida l'app
# nel simulatore, prende le cinque schermate e le mette in shots-v2/<lingua>/.
#
#   ./make-v2.sh                       # it es de fr nl pt-BR (l'inglese è fatto: va chiesto)
#   ./make-v2.sh it pt-BR              # solo alcune
#   ONLY=store ./make-v2.sh it         # solo scanner e firma (non servono i props)
#   ONLY=october ./make-v2.sh it       # solo foto→PDF, ricerca e pagine
#   SKIP_BUILD=1 ./make-v2.sh it       # riusa la build della volta prima
#
# Da dove viene ogni slide:
#   1  v2-01-photos  (testTakesTheOctoberScreenshots, photo-docs/<lingua>)
#   2  01-scan       (testTakesTheStoreScreenshots)
#   3  v2-03-search  (testTakesTheOctoberScreenshots, seed-docs/<lingua>)
#   5  03-sign       (testTakesTheStoreScreenshots)
#   6  v2-06-pages   (testTakesTheOctoberScreenshots)
# La 4 (condivisione) non esce in simulatore: il foglio non ha Mail né Messaggi.
#
# Le catture escono pulite: la barra di stato segue la schermata (nera sul
# bianco, nascosta nello scanner), non serve più ritoccarle.
# Poi ./export-v2.sh <lingua> monta le slide.
set -e
cd "$(dirname "$0")"
SRC="$PWD"
PROJECT="$(cd ../.. && pwd)/pdfexpert.xcodeproj"
DEVICE="iPhone 17 Pro Max"
BUNDLE="eu.balzo.pdfexpert"
LANGS="${*:-it es de fr nl pt-BR}"
DERIVED="$PWD/build/v2-derived"

UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "simulatore '$DEVICE' non trovato"; exit 1; }
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
xcrun simctl status_bar "$UDID" override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 \
  --dataNetwork wifi 2>/dev/null || true

DEST="platform=iOS Simulator,id=$UDID"
if [ -z "$SKIP_BUILD" ]; then
  echo "→ build"
  xcodebuild build-for-testing -project "$PROJECT" -scheme PdfExpert \
    -configuration "Production Debug" -destination "$DEST" \
    -derivedDataPath "$DERIVED" >"$PWD/build/v2-build.log" 2>&1 \
    || { tail -30 "$PWD/build/v2-build.log"; exit 1; }
fi

run() { # lingua test
  local lang=$1 test=$2 result="$PWD/build/v2-$1-$2.xcresult"
  rm -rf "$result"
  xcrun simctl privacy "$UDID" grant camera "$BUNDLE" 2>/dev/null || true
  echo "→ $lang: $test"
  TEST_RUNNER_SHOT_LANG="$lang" TEST_RUNNER_SHOTS_SRC="$SRC" \
  xcodebuild test-without-building -project "$PROJECT" -scheme PdfExpert \
    -configuration "Production Debug" -destination "$DEST" \
    -derivedDataPath "$DERIVED" \
    -only-testing:"PdfExpertUITests/StoreScreenshotsUITests/$test" \
    -resultBundlePath "$result" >"$PWD/build/v2-$lang-$test.log" 2>&1 \
    || { echo "   ✘ fallito, vedi build/v2-$lang-$test.log"; grep -m3 "error:" "$PWD/build/v2-$lang-$test.log" || true; }
  local raw="$PWD/build/v2-raw-$lang-$test"
  rm -rf "$raw"; mkdir -p "$raw"
  xcrun xcresulttool export attachments --path "$result" --output-path "$raw" >/dev/null 2>&1 || true
  python3 - "$raw" "$PWD/shots-v2/$lang" <<'PY'
import json, os, shutil, sys
raw, out = sys.argv[1], sys.argv[2]
order = {"v2-01-photos": "1-raw", "01-scan": "2-raw", "v2-03-search": "3-raw",
         "03-sign": "5-raw", "v2-06-pages": "6"}
os.makedirs(out, exist_ok=True)
try:
    data = json.load(open(os.path.join(raw, "manifest.json")))
except FileNotFoundError:
    sys.exit("   nessuna cattura")
for test in data:
    for att in test.get("attachments", []):
        label = (att.get("suggestedHumanReadableName") or "").split("_0_")[0]
        if label in order:
            shutil.copyfile(os.path.join(raw, att["exportedFileName"]),
                            os.path.join(out, order[label] + ".png"))
            print("   shots-v2/%s/%s.png  <-  %s" % (os.path.basename(out), order[label], label))
PY
}

for lang in $LANGS; do
  [ "$ONLY" = "october" ] || run "$lang" testTakesTheStoreScreenshots
  [ "$ONLY" = "store" ] || run "$lang" testTakesTheOctoberScreenshots
  for n in 1 2 3 5; do
    [ -f "shots-v2/$lang/$n-raw.png" ] && cp "shots-v2/$lang/$n-raw.png" "shots-v2/$lang/$n.png"
  done
done
echo "fatto. Poi: ./export-v2.sh $LANGS"
