#!/bin/bash
# Distribuisce le slide sulle localizzazioni della scheda, in
# fastlane/screenshots/<locale>/.
#
#   ./place-shots.sh                 # da incoming/ (le immagini fatte a mano)
#   ./place-shots.sh out             # da out/ (quelle montate dal simulatore)
#   ./place-shots.sh out de          # una lingua sola
#
# **La lingua sola non e' un vezzo.** Senza, lo script riscrive tutte e sei le
# localizzazioni dalla stessa sorgente: lanciato su out/ oggi, butterebbe via le
# slide iPad di en/it/es — che out/ non ha — e la firma della terza slide,
# l'unica fatta a mano che cade dove un contratto si firma davvero. Quando si
# aggiunge una lingua, si nomina quella lingua.
#
# Le immagini di iPhone e iPad finiscono nella stessa cartella: deliver le
# smista da solo in base alla misura, e dentro ogni misura le ordina per nome —
# per questo si chiamano iphone_1… e ipad_1….
#
# Su App Store Connect una lingua senza screenshot propri eredita quelli di
# en-US. Qui si riempiono le localizzazioni delle lingue in cui l'app e' davvero
# tradotta; le altre continuano a ereditare l'inglese.
#
# es-ES prende le stesse immagini di es-MX: e' la stessa lingua, e la Spagna e'
# il mercato che compriamo di piu' — leggeva la vetrina inglese su iPad.
set -e
cd "$(dirname "$0")"

SOURCE="${1:-incoming}"
ONLY="${2:-}"
DEST="../screenshots"

# `./place-shots.sh mac` prende le slide del Mac da out-mac/ e le mette in una
# cartella tutta loro: la scheda macOS e' una piattaforma diversa sullo stesso
# record, e deliver la carica con `platform: "osx"` e uno screenshots_path suo.
# Mescolarle con quelle iPhone significherebbe offrire un 2880x1800 a un
# telefono, che e' un rifiuto immediato.
if [ "$SOURCE" = "mac" ]; then
  SOURCE="out-mac"
  DEST="../screenshots-mac"
  PREFISSO="mac_"
fi

# locale di App Store Connect : lingua della cattura
MAP="en-US:en it:it es-MX:es es-ES:es de-DE:de fr-FR:fr"

for pair in $MAP; do
  locale="${pair%%:*}"
  lang="${pair##*:}"
  [ -n "$ONLY" ] && [ "$lang" != "$ONLY" ] && continue
  [ -d "$SOURCE/$lang" ] || { echo "$locale  —  niente in $SOURCE/$lang, lascio stare"; continue; }

  mkdir -p "$DEST/$locale"
  rm -f "$DEST/$locale"/iphone_*.png "$DEST/$locale"/ipad_*.png \
        "$DEST/$locale"/screenshot_*.png "$DEST/$locale"/mac_*.png

  if [ -n "$PREFISSO" ]; then
    n=0
    for f in "$SOURCE/$lang"/mac_*.png; do
      [ -e "$f" ] || continue
      n=$((n+1)); cp "$f" "$DEST/$locale/mac_$n.png"
    done
    echo "$locale  ←  $lang   $n Mac"
    continue
  fi

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
