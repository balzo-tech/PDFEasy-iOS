#!/bin/bash
# Monta le catture nel layout ed esporta le slide in PNG 1290x2796, la misura
# che App Store Connect accetta per il display da 6,7" (e riusa per le altre).
#
#   ./export.sh                        # tutte le lingue
#   ./export.sh it                     # solo l'italiano
#   DEVICE=ipad ./export.sh de         # le slide dell'iPad, 2048x2732
#   SLIDES=5 ./export.sh de            # solo le prime cinque
#
# Legge shots/<lingua>/1.png … 6.png e scrive out/<lingua>/screenshot_1.png …
# Con DEVICE=ipad legge ipad-shots/<lingua>/ e scrive out/<lingua>/ipad/, che e'
# la cartella dove place-shots.sh cerca le slide dell'iPad.
#
# SLIDES serve alle lingue senza la sesta: la chat va scattata da un telefono
# con abbonamento (vedi chat-material/), e finche' non c'e' e' meglio caricare
# cinque slide vere che sei con un segnaposto a righe.
set -e
cd "$(dirname "$0")"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

if [ "$DEVICE" = "ipad" ]; then
  WIDTH=2048; HEIGHT=2732; SUB="/ipad"; QUERY="&device=ipad"
else
  WIDTH=1290; HEIGHT=2796; SUB=""; QUERY=""
fi

for lang in ${*:-en it es de fr}; do
  mkdir -p "out/$lang$SUB"
  for i in $(seq 1 "${SLIDES:-6}"); do
    # index.html?lang=xx&only=N mostra una sola slide a dimensione piena, nella
    # lingua chiesta. Il budget di tempo virtuale serve a dare a Chrome il modo
    # di caricare la cattura e di far girare il fit-to-width del titolo prima
    # dello scatto: senza, le parole lunghe escono ancora fuori dal margine.
    "$CHROME" --headless --disable-gpu --hide-scrollbars \
      --screenshot="out/$lang$SUB/screenshot_$i.png" \
      --window-size=$WIDTH,$HEIGHT \
      --virtual-time-budget=3000 \
      --default-background-color=00000000 \
      "file://$PWD/index.html?lang=$lang&only=$i$QUERY" 2>/dev/null
    echo "out/$lang$SUB/screenshot_$i.png"
  done
done
