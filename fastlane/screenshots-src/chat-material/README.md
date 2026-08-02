# La sesta slide: la chat

Le altre cinque escono dal simulatore con `../make-screenshots.sh`. Questa no:
il proxy vuole l'`originalTransactionId` di StoreKit prima di rispondere, e in
simulatore quella transazione non esiste. Va scattata a mano da un telefono con
abbonamento attivo, una volta per lingua.

## Il documento

Un contratto di locazione, uno per lingua. È il documento giusto per la vetrina
perché è lungo, noioso e pieno di numeri che si cercano davvero: mostra il
motivo per cui uno chiederebbe a un PDF invece di leggerlo.

| Lingua | File | Come si legge nella chat |
|---|---|---|
| en | `Rental agreement.pdf` | Boston, dollari |
| it | `Contratto di locazione.pdf` | Milano, euro |
| es | `Contrato de arrendamiento.pdf` | Città del Messico, pesos — la scheda spagnola è `es-MX` |

I dati sono gli stessi in tutti e tre — due mensilità di cauzione, tre mesi di
preavviso — così le tre risposte si somigliano e le tre slide sembrano la stessa
schermata in tre lingue, che è quello che sono.

Si rigenerano da `en.html` / `it.html` / `es.html` con Chrome:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless \
  --no-pdf-header-footer --print-to-pdf="Rental agreement.pdf" "file://$PWD/en.html"
```

## La domanda

Una sola per lingua, corta, con **due** dati chiesti insieme: una domanda da un
dato solo fa una risposta da una riga, che sembra poco, e una domanda aperta fa
un muro di testo che nella miniatura non si legge.

| Lingua | Domanda da digitare |
|---|---|
| en | `What's the deposit and the notice period?` |
| it | `Quanto è la cauzione e il preavviso?` |
| es | `¿Cuánto es el depósito y el preaviso?` |

La risposta attesa cita due cifre — due mensilità e tre mesi — e sta in tre o
quattro righe. Se esce più lunga di mezzo schermo, rifai la domanda: la bolla
deve entrare tutta nella foto insieme alla domanda.

## Come scattare

1. Telefono in **tema chiaro**, Non disturbare acceso, batteria sopra l'80%.
2. Apri il PDF della lingua nell'app, lingua dell'app impostata su quella.
3. Vai su ChatPDF, scegli il documento, digita la domanda, aspetta la risposta.
4. Screenshot con la domanda **e** la risposta entrambe visibili, senza tastiera
   aperta se possibile.

Poi il file va in `../shots/<lingua>/6.png` e si rilancia `../export.sh`.

## L'ora nella status bar

Le cinque slide del simulatore hanno la barra fissata a 09:41 con batteria piena.
Su un telefono vero quella barra non è governabile, quindi la sesta arriva con
l'ora del momento. È l'unico punto in cui le sei slide di una lingua non
combaciano: se dà fastidio, si rifà il giro del simulatore passando a
`simctl status_bar override --time` l'ora dello scatto.
