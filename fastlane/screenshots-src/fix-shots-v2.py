#!/usr/bin/env python3
"""Pulisce le catture di shots-v2/<lingua>/ prima del montaggio.

- 2 (scanner, fondo nero): le catture di XCTest hanno «◀ Run With» sotto l'ora,
  dall'app omonima installata nel simulatore. La parte sinistra della barra di
  stato si prende dalla 2 inglese, che è pulita e ha la stessa ora (09:41).
- 1, 3, 5 (editor e archivio, fondo bianco): la barra esce bianca su bianco;
  statusbar.py la ridisegna in nero, coi glifi della 2 inglese.

Le catture grezze restano accanto come N-raw.png, così il passo si può rifare.

    ./fix-shots-v2.py it es de
"""
import os, shutil, subprocess, sys
from PIL import Image

here = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(here, "shots-v2/en/2.png")
H, LEFT = 150, 460   # altezza della barra e fine della sua parte sinistra

for lang in sys.argv[1:]:
    d = os.path.join(here, "shots-v2", lang)
    for n in ("1", "2", "3", "5"):
        shot, raw = os.path.join(d, n + ".png"), os.path.join(d, n + "-raw.png")
        if not os.path.exists(raw):
            continue
        if n == "2":
            im = Image.open(raw).convert("RGBA")
            im.paste(Image.open(REF).convert("RGBA").crop((0, 0, LEFT, H)), (0, 0))
            im.save(shot)
        else:
            subprocess.run([os.path.join(here, "statusbar.py"), raw, shot, REF], check=True)
        print(os.path.relpath(shot, here))
