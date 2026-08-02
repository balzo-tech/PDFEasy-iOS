#!/bin/bash
# Monta le catture nel layout ed esporta le slide in PNG 1290x2796, la misura
# che App Store Connect accetta per il display da 6,7" (e riusa per le altre).
#
#   ./export.sh              # tutte e tre le lingue
#   ./export.sh it           # solo l'italiano
#
# Legge shots/<lingua>/1.png … 6.png e scrive out/<lingua>/screenshot_1.png …
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

for lang in ${*:-en it es}; do
  mkdir -p "out/$lang"
  for i in 1 2 3 4 5 6; do
    # index.html?lang=xx&only=N mostra una sola slide a dimensione piena, nella
    # lingua chiesta. Il budget di tempo virtuale serve a dare a Chrome il modo
    # di caricare la cattura e di far girare il fit-to-width del titolo prima
    # dello scatto: senza, le parole lunghe escono ancora fuori dal margine.
    "$CHROME" --headless --disable-gpu --hide-scrollbars \
      --screenshot="out/$lang/screenshot_$i.png" \
      --window-size=1290,2796 \
      --virtual-time-budget=3000 \
      --default-background-color=00000000 \
      "file://$PWD/index.html?lang=$lang&only=$i" 2>/dev/null
    echo "out/$lang/screenshot_$i.png"
  done
done
