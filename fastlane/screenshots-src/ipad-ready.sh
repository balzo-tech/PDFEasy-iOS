#!/bin/bash
# Apre il simulatore iPad con l'app pronta da fotografare a mano.
#
#   ./ipad-ready.sh          # italiano
#   ./ipad-ready.sh es       # spagnolo
#
# Le catture si fanno da dentro il Simulator con Cmd+S: finiscono sulla
# Scrivania, alla misura giusta per lo slot iPad (2732x2048 in orizzontale).
#
# Il test automatico qui non arriva: su iPad la navigazione non passa dal tab
# bar ma dalla sidebar, e l'editor e' affiancato invece che a schermo pieno.
# Le sei dell'iPhone si fanno con ./make-screenshots.sh; queste, per ora, a mano.
#
# Le sei schermate, nell'ordine in cui vanno sulla scheda:
#   1 SCANSIONA  la fotocamera dello scanner (o la revisione che la segue)
#   2 CONVERTI   il pannello Strumenti, la griglia dei formati
#   3 FIRMA      la firma appoggiata sul contratto
#   4 MODIFICA   il pannello degli strumenti dell'editor aperto
#   5 PROTEGGI   la scheda della password sul documento
#   6 CHIEDI     la chat con una risposta sul contratto
set -e
LANG_CODE="${1:-it}"
DEVICE="${IPAD:-iPad Pro 13-inch (M5)}"
BUNDLE="eu.balzo.pdfexpert"

UDID=$(xcrun simctl list devices available | grep "$DEVICE (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
[ -n "$UDID" ] || { echo "simulatore '$DEVICE' non trovato"; exit 1; }

xcrun simctl boot "$UDID" 2>/dev/null || true
open -a Simulator
xcrun simctl privacy "$UDID" grant camera "$BUNDLE" 2>/dev/null || true
xcrun simctl status_bar "$UDID" override \
  --time "09:41" --batteryState charged --batteryLevel 100 \
  --wifiMode active --wifiBars 3 --cellularMode notSupported 2>/dev/null || true

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE" \
  -AppleLanguages "($LANG_CODE)" -AppleLocale "$LANG_CODE" \
  -onboardingShown YES -debugSeedArchive YES -debugResetArchive YES \
  -debugPremium YES -debugChatWithArchive YES >/dev/null

echo "pronto in $LANG_CODE — Cmd+S nel Simulator salva la cattura sulla Scrivania"
echo "poi: mettile in incoming/$LANG_CODE/ipad/ e lancia"
echo "  TARGET_W=2732 TARGET_H=2048 ./fit-sizes.sh incoming/$LANG_CODE/ipad"
echo "  ./place-shots.sh"
