#!/bin/bash
# Distribuisce le slide sulle localizzazioni della scheda, in
# fastlane/screenshots/<locale>/.
#
#   ./place-shots.sh                 # da incoming/ (le immagini fatte a mano)
#   ./place-shots.sh out             # da out/ (quelle montate dal simulatore)
#
# Le immagini di iPhone e iPad finiscono nella stessa cartella: deliver le
# smista da solo in base alla misura, e dentro ogni misura le ordina per nome —
# per questo si chiamano iphone_1… e ipad_1….
#
# Su App Store Connect solo en-US ha screenshot propri: le altre tredici lingue
# ereditano da lui. Qui se ne caricano tre — le lingue in cui l'app e' davvero
# tradotta — e le altre undici continuano a ereditare l'inglese.
set -e
cd "$(dirname "$0")"

SOURCE="${1:-incoming}"
DEST="../screenshots"

# locale di App Store Connect : lingua della cattura
MAP="en-US:en it:it es-MX:es"

for pair in $MAP; do
  locale="${pair%%:*}"
  lang="${pair##*:}"

  mkdir -p "$DEST/$locale"
  rm -f "$DEST/$locale"/iphone_*.png "$DEST/$locale"/ipad_*.png \
        "$DEST/$locale"/screenshot_*.png

  n=0
  if [ -d "$SOURCE/$lang/iphone" ]; then
    for f in "$SOURCE/$lang/iphone"/*.png; do
      n=$((n+1)); cp "$f" "$DEST/$locale/iphone_$n.png"
    done
  elif [ -d "$SOURCE/$lang" ]; then
    # out/<lang>/ non ha sottocartelle: sono solo slide da iPhone.
    for f in "$SOURCE/$lang"/*.png; do
      n=$((n+1)); cp "$f" "$DEST/$locale/iphone_$n.png"
    done
  fi

  m=0
  if [ -d "$SOURCE/$lang/ipad" ]; then
    for f in "$SOURCE/$lang/ipad"/*.png; do
      m=$((m+1)); cp "$f" "$DEST/$locale/ipad_$m.png"
    done
  fi

  echo "$locale  ←  $lang   $n iPhone, $m iPad"
done

echo
echo "fatto: $(cd "$DEST" && pwd)"
