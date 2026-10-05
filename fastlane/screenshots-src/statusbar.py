#!/usr/bin/env python3
"""Ridisegna in nero la barra di stato di una cattura su fondo chiaro.

Nell'editor il simulatore scrive ora, campo e Wi-Fi in bianco su bianco: in
vetrina il telefono sembra senza barra. I glifi si prendono da una cattura su
fondo scuro (lo scanner), dove sono bianchi e leggibili, e si stampano in nero.
La batteria resta quella della cattura: è verde, si vede già.

    ./statusbar.py <cattura> <uscita> [cattura-scura]
"""
import sys
from PIL import Image

src, out = sys.argv[1], sys.argv[2]
dark = sys.argv[3] if len(sys.argv) > 3 else "shots/en/1.png"

im = Image.open(src).convert("RGBA")
ref = Image.open(dark).convert("RGB")
assert im.size == ref.size, (im.size, ref.size)

H = 150            # altezza della barra di stato a 1320x2868
ISLAND = (460, 860)  # la Dynamic Island: niente da ridisegnare lì
BATTERY_X = 1090   # da qui in poi c'è la batteria

px, rp = im.load(), ref.load()
for y in range(H):
    for x in range(im.width):
        if ISLAND[0] <= x <= ISLAND[1] or x >= BATTERY_X:
            continue
        r, g, b = rp[x, y]
        lum = (r + g + b) / 3
        if lum > 60:
            a = min(1.0, (lum - 60) / 160)
            R, G, B, A = px[x, y]
            px[x, y] = (int(R * (1 - a)), int(G * (1 - a)), int(B * (1 - a)), A)
im.save(out)
