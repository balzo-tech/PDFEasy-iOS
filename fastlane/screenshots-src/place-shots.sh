#!/bin/bash
# Distribuisce le slide esportate sulle localizzazioni della scheda, in
# fastlane/screenshots/<locale>/.
#
#   ./place-shots.sh
#
# La scheda è in quattordici lingue, l'app in tre: ogni localizzazione prende le
# slide della propria lingua quando ci sono, quelle inglesi quando non ci sono.
# «Niente» non è un'opzione — una localizzazione senza screenshot non si può
# mandare in review.
set -e
cd "$(dirname "$0")"

# locale di App Store Connect : lingua della cattura.
# Le prime cinque sono le lingue vere; le altre nove leggono l'inglese perché
# l'app non parla la loro.
MAP="en-US:en en-GB:en en-CA:en it:it es-MX:es \
     ar-SA:en fr-CA:en fr-FR:en ko:en pt-BR:en ru:en vi:en zh-Hans:en zh-Hant:en"

DEST="../screenshots"

for pair in $MAP; do
  locale="${pair%%:*}"
  lang="${pair##*:}"
  src="out/$lang"

  [ -d "$src" ] || { echo "manca $src — lancia prima ./make-screenshots.sh $lang"; exit 1; }

  mkdir -p "$DEST/$locale"
  rm -f "$DEST/$locale"/screenshot_*.png
  cp "$src"/screenshot_*.png "$DEST/$locale/"
  echo "$locale  ←  $lang"
done

echo
echo "fatto: $(cd "$DEST" && pwd)"
