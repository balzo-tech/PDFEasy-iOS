#!/bin/bash
# Esporta le 6 slide in PNG 1290x2796, la misura che App Store Connect accetta
# per il display da 6,7" (e riusa per tutte le altre).
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p out

for i in 1 2 3 4 5 6; do
  # index.html?only=N mostra una sola slide a dimensione piena, senza zoom.
  "$CHROME" --headless --disable-gpu --hide-scrollbars \
    --screenshot="out/screenshot_$i.png" \
    --window-size=1290,2796 \
    --default-background-color=00000000 \
    "file://$PWD/index.html?only=$i" 2>/dev/null
  echo "out/screenshot_$i.png"
done
