#!/bin/bash
# Le slide dell'App Store per l'app Mac, rifatte con un comando.
#
#   ./mac-shots.sh            # it en es -> out-mac/<lingua>/mac_1.png …
#   ./mac-shots.sh it         # una lingua sola
#   SKIP_BUILD=1 ./mac-shots.sh   # riusa il bundle gia' compilato
#
# Quattro scene, tutte fotografate dalla finestra vera dell'app:
#   1 archivio    la forma desktop — sidebar, cartelle, tag, documento aperto
#   2 strumenti   il catalogo, che e' cio' che l'app sa fare
#   3 cerca       azioni rapide e documenti recenti
#   4 editor      il contratto aperto, con le miniature e la barra strumenti
#
# ## Perche' non si usa screencapture
#
# Perche' su questa macchina lo schermo puo' essere spento, e allora il window
# server non ha niente da consegnare: `screencapture` risponde "could not create
# image from rect" e l'accessibilita' non vede nemmeno la finestra. L'app si
# fotografa da sola (`DebugWindowCapture`, PDFPRO_CAPTURE_DIR) disegnando la
# propria UIWindow, che funziona a schermo spento perche' non passa dallo
# schermo. Il prezzo e' che manca cio' che il sistema disegna *fuori* dalla
# finestra — la barra del titolo — e infatti `monta-mac.py` la ridisegna.
#
# ## Le trappole
#
# - **La firma ad-hoc va rifatta a ogni build**: xcodebuild con
#   CODE_SIGNING_ALLOWED=NO lascia i framework non firmati, e macOS non carica
#   una libreria non firmata. Lo script rifirma prima di lanciare.
# - **PDFPRO_DISABLE_CLOUDKIT=1 non e' facoltativo**: senza entitlement iCloud,
#   CloudKit non torna un errore, fa trap dentro una sua coda e ammazza il
#   processo prima che compaia una finestra.
# - **La lingua si passa due volte**, -AppleLanguages e -AppleLocale: la prima
#   sceglie le stringhe, la seconda le date sotto i documenti.
# - **-debugResetArchive solo sulla prima scena** di ogni lingua: svuota
#   l'archivio, e rifarlo a ogni scena raddoppia l'attesa senza cambiare niente.
set -e
cd "$(dirname "$0")"
REPO="$(cd ../.. && pwd)"
APP="$REPO/DerivedData/Build/Products/Staging Debug-maccatalyst/PdfExpert.app"
DEST="out-mac"
LINGUE="${1:-it en es}"
ATTESA="${ATTESA:-15}"

if [ -z "$SKIP_BUILD" ]; then
  echo "== compilo l'app Mac"
  xcodebuild -project "$REPO/pdfexpert.xcodeproj" -scheme "PdfExpert Staging" \
    -configuration "Staging Debug" \
    -destination 'platform=macOS,variant=Mac Catalyst,arch=arm64' \
    -derivedDataPath "$REPO/DerivedData" CODE_SIGNING_ALLOWED=NO build \
    > /tmp/mac-shots-build.log 2>&1 || { tail -30 /tmp/mac-shots-build.log; exit 1; }
fi

echo "== firma ad-hoc"
for f in "$APP"/Contents/Frameworks/*.framework "$APP"/Contents/PlugIns/*.appex; do
  [ -e "$f" ] && codesign --force --sign - --timestamp=none "$f" > /dev/null 2>&1
done
codesign --force --sign - --timestamp=none "$APP" > /dev/null 2>&1

scatta() { # $1 lingua  $2 numero scena  $3 etichetta  $4… argomenti extra
  local lang="$1" n="$2" nome="$3"; shift 3
  local grezze="$DEST/$lang/grezze"
  mkdir -p "$grezze"
  pkill -f "PdfExpert.app/Contents/MacOS/PdfExpert" 2> /dev/null || true
  sleep 1
  PDFPRO_DISABLE_CLOUDKIT=1 \
  PDFPRO_CAPTURE_DIR="$PWD/$grezze" \
  PDFPRO_CAPTURE_LABEL="$nome" \
  "$@" > /dev/null 2>&1 &
  sleep "$ATTESA"
  pkill -f "PdfExpert.app/Contents/MacOS/PdfExpert" 2> /dev/null || true
  sleep 1
  # La terza cattura e' la buona: la prima arriva a 4 secondi, quando le
  # animazioni di apertura non sono finite.
  cp "$grezze/$nome-2.png" "$grezze/scena_$n.png"
  echo "   $lang/$n $nome"
}

for lang in $LINGUE; do
  echo "== $lang"
  COMUNE=(-AppleLanguages "($lang)" -AppleLocale "$lang" -appTheme light
          -onboardingShown YES -debugSeedArchive YES -debugPremium YES
          -debugSelectDocument YES)
  CONTRATTO="$REPO/pdfexpert/Resources/Test/contract-$lang.pdf"
  [ -f "$CONTRATTO" ] || CONTRATTO="$REPO/pdfexpert/Resources/Test/contract-en.pdf"

  PDFPRO_CAPTURE_GOTO=0 scatta "$lang" 1 archivio \
    "$APP/Contents/MacOS/PdfExpert" "${COMUNE[@]}" -debugResetArchive YES
  PDFPRO_CAPTURE_GOTO=1 scatta "$lang" 2 strumenti \
    "$APP/Contents/MacOS/PdfExpert" "${COMUNE[@]}"
  PDFPRO_CAPTURE_GOTO=3 scatta "$lang" 3 cerca \
    "$APP/Contents/MacOS/PdfExpert" "${COMUNE[@]}"
  PDFPRO_CAPTURE_OPEN="$CONTRATTO" scatta "$lang" 4 editor \
    "$APP/Contents/MacOS/PdfExpert" "${COMUNE[@]}"

  echo "   monto"
  for n in 1 2 3 4; do
    python3 monta-mac.py "$DEST/$lang/grezze/scena_$n.png" "$DEST/$lang/mac_$n.png"
  done
done

echo
echo "fatto: $(pwd)/$DEST — distribuiscile con ./place-shots.sh mac"
