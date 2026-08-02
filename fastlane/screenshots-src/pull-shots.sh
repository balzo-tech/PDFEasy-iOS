#!/bin/bash
# Estrae le catture dell'app dal result bundle del UI test e le mette dove
# index.html le cerca (shots/1.png … shots/6.png).
set -e
cd "$(dirname "$0")"
BUNDLE="${1:-build/shots.xcresult}"
mkdir -p raw shots

rm -rf raw/*
xcrun xcresulttool export attachments \
  --path "$BUNDLE" \
  --output-path raw >/dev/null

# I file escono con il nome dell'attachment (01-scan, 02-convert, …); il
# manifest dice quale file corrisponde a quale nome.
python3 - "$PWD/raw" <<'PY'
import json, os, shutil, sys

raw = sys.argv[1]
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
        dst = os.path.join(os.path.dirname(raw), "shots", "%d.png" % n)
        shutil.copyfile(src, dst)
        print("shots/%d.png  <-  %s" % (n, name))
        found += 1

if not found:
    sys.exit("nessuna cattura trovata nel bundle")
PY
