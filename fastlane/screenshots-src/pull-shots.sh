#!/bin/bash
# Estrae le catture dell'app dal result bundle del UI test e le mette dove
# index.html le cerca (shots/<lingua>/1.png … 6.png).
#
#   ./pull-shots.sh build/shots-it.xcresult it
set -e
cd "$(dirname "$0")"
BUNDLE="${1:-build/shots.xcresult}"
SHOT_LANG="${2:-en}"
mkdir -p raw "shots/$SHOT_LANG"

rm -rf raw/*
xcrun xcresulttool export attachments \
  --path "$BUNDLE" \
  --output-path raw >/dev/null

# I file escono con il nome dell'attachment (01-scan, 02-convert, …); il
# manifest dice quale file corrisponde a quale nome.
python3 - "$PWD/raw" "$SHOT_LANG" <<'PY'
import json, os, shutil, sys

raw, lang = sys.argv[1], sys.argv[2]
manifest = os.path.join(raw, "manifest.json")
order = {"01-scan": 1, "02-convert": 2, "03-sign": 3,
         "04-edit": 4, "05-protect": 5, "06-ask": 6}

with open(manifest) as f:
    data = json.load(f)

found = 0
for test in data:
    for att in test.get("attachments", []):
        # XCTest appende "_0_<uuid>.png" al nome dato all'attachment.
        label = att.get("suggestedHumanReadableName") or ""
        n = next((v for k, v in order.items() if label.startswith(k)), None)
        if not n:
            continue
        name = label.split("_0_")[0]
        src = os.path.join(raw, att["exportedFileName"])
        dst = os.path.join(os.path.dirname(raw), "shots", lang, "%d.png" % n)
        shutil.copyfile(src, dst)
        print("shots/%s/%d.png  <-  %s" % (lang, n, name))
        found += 1

if not found:
    sys.exit("nessuna cattura trovata nel bundle")
PY
