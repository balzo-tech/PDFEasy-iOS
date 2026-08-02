#!/bin/bash
# Rifà da zero gli screenshot dell'App Store: guida l'app nel simulatore,
# fotografa le schermate, le monta nel layout ed esporta i PNG in out/.
#
#   ./make-screenshots.sh
#
# Serve Xcode e il simulatore "iPhone 17 Pro Max" (1320x2868, il display da 6,9").
#
# La sesta schermata — ChatPDF con una risposta — non esce di qui: il proxy vuole
# l'originalTransactionId di StoreKit, che in simulatore non esiste. Va presa da
# un telefono con abbonamento attivo, sbloccato e con la modalità sviluppatore
# attiva:
#
#   xcodebuild test -project ../../pdfexpert.xcodeproj -scheme PdfExpert \
#     -configuration "Production Debug" \
#     -destination 'platform=iOS,name=<telefono>' \
#     -only-testing:PdfExpertUITests/StoreScreenshotsUITests/testTakesTheChatScreenshot \
#     -resultBundlePath build/chat.xcresult -allowProvisioningUpdates
#
# …e poi: ./pull-shots.sh build/chat.xcresult && ./export.sh
set -e
cd "$(dirname "$0")"

PROJECT="$(cd ../.. && pwd)/pdfexpert.xcodeproj"
DEVICE="iPhone 17 Pro Max"
BUNDLE="eu.balzo.pdfexpert"
RESULT="$PWD/build/shots.xcresult"

UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "simulatore '$DEVICE' non trovato"; exit 1; }

echo "→ preparo il simulatore"
mkdir -p build
xcrun simctl boot "$UDID" 2>/dev/null || true
# Senza questo la prima schermata esce con il dialog dei permessi sopra.
xcrun simctl privacy "$UDID" grant camera "$BUNDLE" 2>/dev/null || true
# La status bar di serie mostra l'ora vera e una batteria a metà: Apple vuole
# gli screenshot con una barra pulita.
xcrun simctl status_bar "$UDID" override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 \
  --dataNetwork wifi 2>/dev/null || true

echo "→ guido l'app e fotografo le schermate"
rm -rf "$RESULT"
xcodebuild test \
  -project "$PROJECT" \
  -scheme PdfExpert \
  -configuration "Production Debug" \
  -destination "platform=iOS Simulator,name=$DEVICE" \
  -only-testing:PdfExpertUITests/StoreScreenshotsUITests/testTakesTheStoreScreenshots \
  -resultBundlePath "$RESULT" >/dev/null

echo "→ estraggo le catture"
./pull-shots.sh "$RESULT"

echo "→ monto il layout ed esporto"
./export.sh

echo
echo "fatto: $PWD/out"
