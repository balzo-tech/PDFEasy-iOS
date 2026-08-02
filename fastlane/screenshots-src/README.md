# Gli screenshot dell'App Store

Sei immagini 1290×2796, rifatte con un comando:

```sh
./make-screenshots.sh          # → out/screenshot_1.png … screenshot_6.png
```

Sotto il cofano: `StoreScreenshotsUITests` guida l'app nel simulatore e fotografa
le schermate, `pull-shots.sh` le tira fuori dal result bundle, `index.html` le
monta con titolo e sfondo, `export.sh` esporta i PNG con Chrome headless.

Per cambiare i testi si edita `index.html` e si rilancia `./export.sh` — non
serve rifotografare.

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

## La sesta va presa a mano

ChatPDF passa dal proxy, e il proxy vuole l'`originalTransactionId` di StoreKit
prima di rispondere. In simulatore quella transazione non esiste — `-debugPremium`
apre i gate dell'app ma non ne inventa una — quindi la conversazione si ferma su
«This feature is part of the subscription». Va catturata da un telefono con
abbonamento attivo, sbloccato e con la modalità sviluppatore accesa:

```sh
xcodebuild test -project ../../pdfexpert.xcodeproj -scheme PdfExpert \
  -configuration "Production Debug" \
  -destination 'platform=iOS,name=<telefono>' \
  -only-testing:PdfExpertUITests/StoreScreenshotsUITests/testTakesTheChatScreenshot \
  -resultBundlePath build/chat.xcresult -allowProvisioningUpdates
./pull-shots.sh build/chat.xcresult && ./export.sh
```

In alternativa si mette a mano uno screenshot in `shots/6.png` e si lancia
`./export.sh`.

## Le trappole già pagate

- **`debugInitialTab` non tiene**: imposta il tab nell'`init` del coordinator, ma
  qualcosa a valle rimette Files prima che la schermata si fermi. I tab si
  raggiungono toccando la barra.
- **La firma non è nel pannello**: sta nella barra sotto la pagina, insieme ad
  Aggiungi pagina, Aggiungi testo e Compila modulo. Si tocca per etichetta.
- **La camera non esiste in simulatore**: la schermata «scan» è la review che la
  segue, aperta con `-debugStartScan` e `-debugScanPages`.
- **Le pagine finte dello scanner** disegnavano righe grigie: ora renderizzano il
  PDF di test del bundle, perché un placeholder in vetrina si vede che è un
  placeholder.
- **I documenti scansionati non si possono chattare**: sono immagini senza testo
  estraibile, e la chat li rifiuta. Per questo `debugChatWithArchive` parte dal
  PDF di test e non dal primo documento dell'archivio.
