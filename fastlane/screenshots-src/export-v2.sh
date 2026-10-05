#!/bin/bash
# Monta le slide del set di ottobre (index-v2.html) ed esporta i PNG 1290x2796
# in out-v2/<lingua>/screenshot_N.png. Salta la 4 (condivisione): non c'è una
# cattura buona, vedi make-v2.sh.
#
#   ./export-v2.sh                 # en it es de fr nl pt-BR
#   ./export-v2.sh it pt-BR
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
for lang in ${*:-en it es de fr nl pt-BR}; do
  mkdir -p "out-v2/$lang"
  for i in 1 2 3 5 6; do
    "$CHROME" --headless --disable-gpu --hide-scrollbars \
      --screenshot="out-v2/$lang/screenshot_$i.png" \
      --window-size=1290,2796 --virtual-time-budget=3000 \
      "file://$PWD/index-v2.html?lang=$lang&only=$i" 2>/dev/null
    echo "out-v2/$lang/screenshot_$i.png"
  done
done
