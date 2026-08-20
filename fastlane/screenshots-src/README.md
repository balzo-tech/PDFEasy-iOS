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

## L'iPad

Lo stesso test, puntato su un simulatore iPad, fa le sue cinque catture:

```sh
TEST_RUNNER_SHOT_LANG=de xcodebuild test \
  -project ../../pdfexpert.xcodeproj -scheme PdfExpert \
  -configuration "Production Debug" \
  -destination "platform=iOS Simulator,name=iPad Pro 13-inch (M5)" \
  -only-testing:PdfExpertUITests/StoreScreenshotsUITests/testTakesTheStoreScreenshots \
  -resultBundlePath build/shots-de-ipad.xcresult
```

Le catture si tirano fuori come per l'iPhone e vanno in `ipad-shots/<lingua>/`,
poi si montano nello stesso layout:

```sh
DEVICE=ipad SLIDES=5 ./export.sh de      # → out/de/ipad/screenshot_1.png …
```

`?device=ipad` cambia la slide a 2048x2732 e va a prendere le catture in
`ipad-shots/` invece che in `shots/`; fondali, titoli e ordine restano quelli
dell'iPhone, perché sulla scheda le due misure si vedono una accanto all'altra.

**Si fotografa in verticale.** La nota che c'era qui il 19 agosto — cattura
ruotata di 90°, app in una finestra flottante — veniva dall'aver forzato
l'orientamento orizzontale: `XCUIDevice.shared.orientation` gira l'app ma non il
buffer del display. Lasciato in verticale non succede niente di tutto questo: la
cattura esce 2064x2752, l'app riempie lo schermo, e 2048x2732 è una delle misure
che lo slot iPad accetta. Le slide inglesi, italiane e spagnole caricate sono
orizzontali perché fatte a mano prima di scoprirlo: dentro una localizzazione
l'orientamento è coerente, ed è l'unica cosa che conta.

**Il simulatore deve stare in piedi.** Un simulatore conserva l'orientamento in
cui lo si è lasciato, e un iPad coricato riporta una finestra 1376x1032 mentre
la cattura esce lo stesso 1032x1376: da quel momento ogni coordinata normalizzata
del test punta altrove rispetto a quello che si vede nella foto, e il giro
fallisce sul primo tocco che deve essere preciso. Non si corregge da dentro il
test — `XCUIDevice.shared.orientation` gira l'app e non il buffer, e la cattura
esce con lo schermo disegnato di traverso. Si spegne e si riaccende:

```sh
xcrun simctl shutdown "iPad Pro 13-inch (M5)" && xcrun simctl boot "iPad Pro 13-inch (M5)"
```

## La firma

Non si disegna: un drag sintetizzato traccia un segmento dritto, e otto in fila
sono uno scarabocchio in mezzo al contratto, dovunque cadano. L'app viene
lanciata con una firma già in archivio — `-debugSeedSignature "Daniel Markwart"`,
il conduttore del contratto di quella lingua — così toccando la pagina propone
il suo elenco invece di una tela vuota, che poi è quello che promette la slide:
disegnala una volta, riusala.

L'inchiostro è Snell Roundhand, un font di sistema, disegnato piccolo dentro
un'immagine larga e trasparente: l'app stende ogni firma nuova sul 70% della
larghezza della pagina, e un nome che riempie la propria immagine ne esce grande
come un timbro.

Dove finisce **non** lo decide il tocco: l'app la posa al centro della vista, e
il tocco sceglie solo la pagina. Il test la trascina da lì sulla riga del
conduttore, con due paia di coordinate misurate su una cattura — una per
l'iPhone, una per l'iPad, che disegna la pagina di fianco alle miniature. È per
questo che il contratto sta in **una pagina sola**: se il piede non entra nella
schermata, non c'è nessun posto giusto dove metterla.

Due trappole pagate qui:

- **`cells.firstMatch` non è la firma.** Su iPad la sidebar dell'archivio resta
  nell'albero dietro al foglio e la sua prima riga viene prima: il tocco non
  sceglieva niente, l'elenco restava aperto e Finish chiudeva una schermata
  senza firma sopra. Le righe del foglio sono quelle sotto il suo titolo.
- **Il gesto va lasciato assestare.** Toccare Finish dentro l'animazione di
  rilascio del trascinamento chiude la schermata buttando via la firma.
