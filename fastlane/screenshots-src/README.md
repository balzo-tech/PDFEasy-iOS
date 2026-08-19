# Gli screenshot dell'App Store

Diciotto immagini 1290×2796 — sei slide per ognuna delle tre lingue in cui
l'app è tradotta — rifatte con un comando:

```sh
./make-screenshots.sh          # en it es → out/<lingua>/screenshot_1.png …
./make-screenshots.sh it       # una lingua sola
./place-shots.sh               # le distribuisce sulle 14 localizzazioni della scheda
```

Sotto il cofano: `StoreScreenshotsUITests` guida l'app sul telefono e fotografa
le schermate, `pull-shots.sh` le tira fuori dal result bundle, `index.html` le
monta con titolo e sfondo, `export.sh` esporta i PNG con Chrome headless.

Per cambiare i testi si edita l'oggetto `TEXT` in `index.html` e si rilancia
`./export.sh` — non serve rifotografare.

## Perché sono fatti così

I primi quattro risultati per «pdf scanner» negli Stati Uniti usano tutti lo
stesso schema: **una parola sola in maiuscolo** in cima, un sottotitolo corto, e
**un solo telefono dritto e intero** su fondo pieno ad alto contrasto. Non è
pigrizia: nei risultati di ricerca la miniatura è larga un centinaio di pixel, e
a quella dimensione sopravvive solo una parola grossa. Il fondo blu profondo
serve a staccare dal rosso di due concorrenti e dal bianco degli altri due.

L'ordine segue le intenzioni di ricerca, non l'organigramma dell'app: SCAN e
CONVERT per prime perché sono ciò che la gente cerca — l'89% dei download arriva
dalla ricerca — poi SIGN (il motivo per cui si paga), EDIT, PROTECT e ASK.

## Le tre lingue, e le altre undici

L'app è tradotta in **inglese, italiano e spagnolo**; la scheda esiste in
quattordici lingue. `place-shots.sh` dà a ogni localizzazione le slide della
propria lingua quando ci sono e quelle inglesi quando non ci sono: una
localizzazione senza screenshot non si può mandare in review, quindi lasciarne
qualcuna vuota non è un'opzione.

La parola grossa cambia lunghezza da una lingua all'altra — SCAN sono quattro
lettere, SCANSIONA nove — e a 168px la seconda esce dal margine. Il layout non
ha un corpo per lingua scritto a mano, che si sfalserebbe alla prima traduzione
ritoccata: cerca il corpo più grande in cui entra **la più lunga delle sei
parole** e lo dà a tutte, così i sei titoli di una lingua restano della stessa
misura.

## Perché tutte e sei si prendono dal telefono

ChatPDF passa dal proxy, e il proxy vuole l'`originalTransactionId` di StoreKit
prima di rispondere. In simulatore quella transazione non esiste —
`-debugPremium` apre i gate dell'app ma non ne inventa una — quindi la
conversazione si ferma su «This feature is part of the subscription».

Quella schermata va presa da un telefono con abbonamento attivo, e da lì viene
il resto: mischiare cinque catture da simulatore e una da device dentro la
stessa lingua dà sei slide con l'ora e la batteria che non combaciano.

Il prezzo è che la status bar non è più governabile: non c'è un
`simctl status_bar override` per un telefono vero. Prima di lanciare, batteria
sopra l'80%, Non disturbare acceso, telefono sbloccato e collegato.

## Le trappole già pagate

- **`debugInitialTab` non tiene**: imposta il tab nell'`init` del coordinator, ma
  qualcosa a valle rimette Files prima che la schermata si fermi. I tab si
  raggiungono toccando la barra.
- **La firma non è nel pannello**: sta nella barra sotto la pagina, insieme ad
  Aggiungi pagina, Aggiungi testo e Compila modulo. Si tocca per etichetta.
- **Le etichette sono tradotte**: il test naviga per testo, quindi in italiano e
  spagnolo cerca le stringhe di quelle lingue. La tabella sta in cima a
  `StoreScreenshotsUITests`, copiata da `Localizable.xcstrings`; se una
  traduzione cambia nel catalogo va cambiata anche lì, o il test fallisce.
- **Le pagine finte dello scanner** disegnavano righe grigie: ora renderizzano il
  PDF di test del bundle, perché un placeholder in vetrina si vede che è un
  placeholder.
- **I documenti scansionati non si possono chattare**: sono immagini senza testo
  estraibile, e la chat li rifiuta. Per questo `debugChatWithArchive` parte dal
  PDF di test e non dal primo documento dell'archivio.

## L'iPad non si automatizza (provato il 19 agosto 2026)

`make-screenshots.sh` guida solo l'iPhone. La tentazione è puntare lo stesso
test su un simulatore iPad, e in effetti **il test passa**: la nota in
`ipad-ready.sh` che dice che su iPad non arriva è vecchia, `show()` cerca già le
voci come `staticTexts` e la sidebar la trova. Quello che non funziona è la
fotografia:

- **la cattura esce ruotata di 90°.** Impostare `XCUIDevice.shared.orientation`
  gira l'app ma non il buffer del display, che resta verticale: si ottiene una
  schermata orizzontale dentro un PNG verticale;
- **l'app non riempie lo schermo.** Su iPadOS 26 parte in una finestra
  flottante, con lo sfondo di sistema tutto intorno.

Nessuno dei due si corregge nel layout, quindi le sei slide iPad restano da
fare a mano con `./ipad-ready.sh <lingua>` e Cmd+S nel Simulator. Al 19 agosto
mancano per il tedesco e per il francese: le due lingue hanno gli iPhone e non
gli iPad, mentre `es-ES` è a posto perché ha ricevuto le immagini spagnole già
esistenti.
