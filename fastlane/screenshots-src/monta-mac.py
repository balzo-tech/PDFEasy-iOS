# -*- coding: utf-8 -*-
"""Monta una cattura della finestra Catalyst su fondo pieno, misura App Store.

La barra del titolo del Mac non c'e' nella cattura — DebugWindowCapture disegna
la UIWindow, e il titolo lo disegna il sistema fuori da quella. Qui viene
ricostruita: fascia chiara, tre semafori, angoli tondi e un'ombra sotto.
"""
import sys
from PIL import Image, ImageDraw, ImageFilter

TELA = (2880, 1800)
FONDO_ALTO = (11, 41, 110)     # blu profondo, come le slide iPhone
FONDO_BASSO = (23, 78, 186)
BARRA = (238, 238, 240)
BORDO = (206, 208, 212)
SEMAFORI = [(255, 95, 87), (255, 189, 46), (40, 201, 64)]
RAGGIO = 34
BARRA_H = 56

def fondo():
    tela = Image.new("RGB", TELA, FONDO_ALTO)
    d = ImageDraw.Draw(tela)
    for y in range(TELA[1]):
        t = y / TELA[1]
        d.line([(0, y), (TELA[0], y)],
               fill=tuple(int(a + (b - a) * t) for a, b in zip(FONDO_ALTO, FONDO_BASSO)))
    return tela

def cornice(shot):
    """La cattura piu' la barra del titolo, angoli arrotondati."""
    w, h = shot.size
    finestra = Image.new("RGB", (w, h + BARRA_H), BARRA)
    d = ImageDraw.Draw(finestra)
    d.line([(0, BARRA_H - 1), (w, BARRA_H - 1)], fill=BORDO)
    for i, colore in enumerate(SEMAFORI):
        cx = 34 + i * 40
        d.ellipse([cx - 11, BARRA_H // 2 - 11, cx + 11, BARRA_H // 2 + 11], fill=colore)
    finestra.paste(shot, (0, BARRA_H))
    maschera = Image.new("L", finestra.size, 0)
    ImageDraw.Draw(maschera).rounded_rectangle([0, 0, w - 1, h + BARRA_H - 1], RAGGIO, fill=255)
    fuori = Image.new("RGBA", finestra.size)
    fuori.paste(finestra, (0, 0))
    fuori.putalpha(maschera)
    return fuori

def monta(percorso_shot, percorso_out):
    shot = Image.open(percorso_shot).convert("RGB")
    finestra = cornice(shot)
    tela = fondo()
    x = (TELA[0] - finestra.width) // 2
    y = (TELA[1] - finestra.height) // 2

    ombra = Image.new("RGBA", TELA, (0, 0, 0, 0))
    ImageDraw.Draw(ombra).rounded_rectangle(
        [x + 10, y + 26, x + finestra.width - 10, y + finestra.height + 30], RAGGIO, fill=(0, 0, 0, 120))
    ombra = ombra.filter(ImageFilter.GaussianBlur(38))
    tela = Image.alpha_composite(tela.convert("RGBA"), ombra)
    tela.alpha_composite(finestra, (x, y))
    tela.convert("RGB").save(percorso_out, "PNG")
    print(percorso_out, tela.size)

if __name__ == "__main__":
    monta(sys.argv[1], sys.argv[2])
