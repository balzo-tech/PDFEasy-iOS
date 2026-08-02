#!/bin/bash
# Rifà cinque delle sei slide dell'App Store, in tutte le lingue in cui l'app è
# tradotta: guida l'app nel simulatore, fotografa le schermate, le monta nel
# layout ed esporta i PNG in out/<lingua>/.
#
#   ./make-screenshots.sh            # en it es
#   ./make-screenshots.sh it         # una lingua sola
#
# Serve Xcode e il simulatore "iPhone 17 Pro Max" (1320x2868, il display da 6,9").
#
# **La sesta non esce di qui.** ChatPDF passa dal proxy, e il proxy vuole
# l'originalTransactionId di StoreKit prima di rispondere: in simulatore quella
# transazione non esiste, e `-debugPremium` apre i gate dell'app ma non ne
# inventa una. Quella schermata si cattura a mano da un telefono con
# abbonamento attivo e si lascia cadere in shots/<lingua>/6.png, poi ./export.sh.
# I documenti e le domande da usare stanno in chat-material/.
set -e
cd "$(dirname "$0")"

PROJECT="$(cd ../.. && pwd)/pdfexpert.xcodeproj"
DEVICE="iPhone 17 Pro Max"
BUNDLE="eu.balzo.pdfexpert"
LANGS="${*:-en it es}"

UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "simulatore '$DEVICE' non trovato"; exit 1; }

echo "→ preparo il simulatore"
mkdir -p build
xcrun simctl boot "$UDID" 2>/dev/null || true
# Senza questo la prima schermata esce con il dialog dei permessi sopra.
xcrun simctl privacy "$UDID" grant camera "$BUNDLE" 2>/dev/null || true
# La status bar di serie mostra l'ora vera e una batteria a metà: Apple vuole
# gli screenshot con una barra pulita. La sesta slide arriva da un telefono
# vero, dove questa barra non è governabile — quindi va scattata con la
# batteria alta e Non disturbare acceso, o si vede che viene da un'altra parte.
xcrun simctl status_bar "$UDID" override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3 \
  --dataNetwork wifi 2>/dev/null || true

for lang in $LANGS; do
  echo "→ $lang: guido l'app e fotografo le schermate"
  RESULT="$PWD/build/shots-$lang.xcresult"
  rm -rf "$RESULT"

  # TEST_RUNNER_ è il modo in cui xcodebuild passa una variabile d'ambiente al
  # processo del test: di là arriva come SHOT_LANG, e il test ci sceglie sia la
  # lingua di lancio dell'app sia le etichette con cui naviga.
  TEST_RUNNER_SHOT_LANG="$lang" xcodebuild test \
    -project "$PROJECT" \
    -scheme PdfExpert \
    -configuration "Production Debug" \
    -destination "platform=iOS Simulator,name=$DEVICE" \
    -only-testing:PdfExpertUITests/StoreScreenshotsUITests/testTakesTheStoreScreenshots \
    -resultBundlePath "$RESULT" >/dev/null

  echo "→ $lang: estraggo le catture"
  ./pull-shots.sh "$RESULT" "$lang"
done

echo "→ monto il layout ed esporto"
./export.sh $LANGS

echo
echo "fatto: $PWD/out  —  manca la sesta di ogni lingua (vedi chat-material/)"
