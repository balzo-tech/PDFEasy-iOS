#!/bin/bash
# Porta le immagini alla misura che App Store Connect accetta per iPhone, e dice
# quanto le sta deformando per arrivarci.
#
#   ./fit-sizes.sh out/it            # controlla e corregge una cartella
#   ./fit-sizes.sh --check out/it    # controlla soltanto, non tocca niente
#
# 1284x2778 e' il display da 6,5", una delle quattro misure che lo slot iPhone
# accetta: 1242x2688, 2688x1242, 1284x2778, 2778x1284. Il layout e' disegnato a
# 1290x2796 — quasi lo stesso rapporto — quindi ci arriva senza deformarsi.
# Si cambia bersaglio con TARGET_W / TARGET_H.
#
# Il rapporto e' 1:2,167 — molto piu' stretto di qualunque immagine generata da
# un modello, che esce quadrata o al massimo 2:3. Portarci una figura quadrata
# significa stirarla di oltre il doppio in altezza: le facce diventano lunghe, i
# cerchi ovali, il testo si allunga. Lo script lo fa lo stesso se glielo chiedi,
# ma prima ti dice di quanto.
set -e
cd "$(dirname "$0")"

W="${TARGET_W:-1284}"
H="${TARGET_H:-2778}"
CHECK=0
[ "$1" = "--check" ] && { CHECK=1; shift; }
DIR="${1:?uso: ./fit-sizes.sh [--check] <cartella>}"

shopt -s nullglob
found=0
for f in "$DIR"/*.png "$DIR"/*.PNG "$DIR"/*.jpg "$DIR"/*.jpeg; do
  found=1
  cw=$(sips -g pixelWidth  "$f" | tail -1 | awk '{print $2}')
  ch=$(sips -g pixelHeight "$f" | tail -1 | awk '{print $2}')

  if [ "$cw" = "$W" ] && [ "$ch" = "$H" ]; then
    printf '%-28s %sx%s  gia giusta\n' "$(basename "$f")" "$cw" "$ch"
    continue
  fi

  # Di quanto va stirata ciascuna dimensione per arrivare al bersaglio: se i due
  # numeri sono diversi, la differenza fra loro e' la deformazione.
  read -r warp note <<EOF
$(python3 -c "
cw, ch = $cw, $ch
sx, sy = $W/cw, $H/ch
warp = max(sx/sy, sy/sx)
note = 'ok' if warp < 1.02 else ('accettabile' if warp < 1.15 else 'DEFORMA')
print(f'{warp:.2f} {note}')
")
EOF

  printf '%-28s %sx%s → %sx%s  stira %sx  %s\n' \
         "$(basename "$f")" "$cw" "$ch" "$W" "$H" "$warp" "$note"

  [ "$CHECK" = "1" ] && continue
  sips -z "$H" "$W" "$f" >/dev/null   # -z impone la misura, senza rispettare il rapporto
done

[ "$found" = "0" ] && { echo "nessuna immagine in $DIR"; exit 1; }
echo
[ "$CHECK" = "1" ] && echo "(solo controllo: non ho toccato niente)" || echo "fatto: $DIR"
