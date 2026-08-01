# L'app per Mac — stato e giro di prova

Scritto la notte del 1 agosto 2026, branch `feature/mac-app`.
Da leggere prima di aprire Xcode: la prima sezione dice **come si avvia**, la
seconda **cosa è stato deciso e perché**, la terza è la **checklist** da spuntare.

Segna così: `[x]` passata · `[!]` problema (scrivi cosa) · `[-]` non provabile ora.

---

## 0. Come si avvia (5 minuti)

L'app Mac **non è un secondo progetto**: è lo stesso target `PdfExpert`, con
Mac Catalyst acceso e l'idiom Mac (controlli nativi, non un iPad ingrandito).

1. Apri `pdfexpert.xcodeproj`.
2. Nel selettore delle destinazioni scegli **My Mac (Mac Catalyst)**.
3. Scheme **PdfExpert Staging**, poi Run.

Alla prima esecuzione Xcode deve **generare il profilo di provisioning Mac
Catalyst** — succede da solo perché la firma è automatica, ma ci vuole l'account
sviluppatore connesso in Xcode (Settings → Accounts). Da riga di comando non
funziona: `xcodebuild` non ha accesso all'account e risponde *"No profiles for
'eu.balzo.pdfexpert.staging' were found"*.

Se il portale dovesse lamentarsi, le capability da avere sull'App ID per macOS
sono le stesse di iOS: iCloud (container `iCloud.eu.balzo.pdfexpert`), App
Groups, Push. **Attenzione all'App Group**: su macOS si chiama
`G6RAKRKZPR.group.eu.balzo.pdfexpert` — con il Team ID davanti. Il codice lo sa
già (`AppGroupIdentifier`), ma se il gruppo col prefisso non esiste sul portale
il widget e l'estensione di condivisione non vedono niente.

### Avviarla senza profilo (quello che ho fatto stanotte)

Serve solo se vuoi rilanciarla da terminale senza Xcode:

```bash
xcodebuild -project pdfexpert.xcodeproj -scheme "PdfExpert Staging" \
  -configuration "Staging Debug" \
  -destination 'platform=macOS,variant=Mac Catalyst,arch=arm64' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
# poi firma ad-hoc app, framework e appex, e lancia con:
PDFPRO_DISABLE_CLOUDKIT=1 "…/PdfExpert.app/Contents/MacOS/PdfExpert"
```

`PDFPRO_DISABLE_CLOUDKIT=1` esiste **solo nei build Debug** e serve solo lì: un
binario firmato ad-hoc non ha l'entitlement iCloud, e CloudKit non risponde con
un errore ma con un'eccezione dentro una sua coda, che ammazza il processo prima
che compaia una finestra. Con il profilo vero non serve e non va usata.

---

## 1. Cosa è stato deciso, e perché

**Mac Catalyst, non un target macOS nativo.** Le ragioni, in ordine di peso:

- Esisteva già `MainSplitView`: sidebar + lista + dettaglio, cioè esattamente la
  forma dell'app desktop di Stirling. E `PdfProCommands` con le scorciatoie.
- Stesso bundle ID → **Universal Purchase**: chi è abbonato su iPhone lo è sul
  Mac, senza toccare App Store Connect e senza un secondo prodotto.
- Una sola base di codice. L'app è in evoluzione: un target nativo avrebbe
  raddoppiato ogni correzione da qui in avanti.
- Tutti i binari di terze parti hanno la slice `maccatalyst` (Firebase,
  GoogleAppMeasurement, gRPC, abseil, Lottie); Mantis e grogu dichiarano macOS.

Il costo di un target nativo sarebbe stato riscrivere la UI, i 42 file che usano
UIKit, la fotocamera e il ritaglio. Settimane, non una notte.

**Il codice Swift ha compilato per Catalyst senza un solo errore** al primo
tentativo. Tutto quello che segue è adattamento, non porting.

---

## 2. Cosa è stato cambiato

### Progetto
- Catalyst acceso su `PdfExpert`, `PdfProWidget`, `ShareFileExtension` e sui due
  target di test, con idiom Mac (`TARGETED_DEVICE_FAMILY = 1,2,6`), stesso bundle
  ID (`DERIVE_MACCATALYST_PRODUCT_BUNDLE_IDENTIFIER = NO`), deployment macOS 26.
- Tre file di entitlements per macOS (`*-Mac.entitlements`) con **App Sandbox**,
  accesso ai file scelti dall'utente, fotocamera, rete, stampa, iCloud e App
  Group col prefisso del team.
- `UIRequiresFullScreen` spento **solo su macOS** — su iPad resta com'era.
- Lo script che copia `GoogleService-Info.plist` scriveva nella radice del
  bundle: su Mac le risorse stanno in `Contents/Resources`, e Crashlytics non
  trovando il file **fermava il build**. Ora usa
  `UNLOCALIZED_RESOURCES_FOLDER_PATH`, che è giusto su entrambe le piattaforme.
- Aggiunti gli rpath macOS ai target di test (i framework stanno in
  `Contents/Frameworks`, non accanto all'eseguibile).

### Comportamento
- **`UIDevice.hasDesktopClassLayout`** (nuovo): sei punti del codice chiedevano
  «è un iPad?» per decidere la *forma* di una presentazione — e il Mac risponde
  `.mac`, quindi si sarebbe preso la forma dell'iPhone: file picker a tutto
  schermo, sheet con la maniglia di trascinamento, dialoghi che salgono dal
  bordo inferiore di una finestra. Ora passano tutti di qui.
- **La shell non collassa mai in tab bar sul Mac.** Una finestra stretta riporta
  una size class compact esattamente come un iPad in Slide Over, e la tab bar
  avrebbe sepolto le cartelle dietro una barra di chip.
- **Drag & drop**: trascinare un file sulla finestra lo importa, con un
  riquadro tratteggiato mentre il file è sopra. Passa dalla stessa strada di
  «Copia su PDF Pro». Un file per volta (la pipeline ne porta uno).
- **Menu**: aggiunto **File ▸ Apri… (⌘O)**, più Unisci/Dividi/Comprimi;
  **Impostazioni (⌘,)** spostate nel menu dell'app, dove le tiene ogni app Mac;
  il menu Vai ora include lo Scanner (⌘3) e ChatPDF passa a ⌘4.
  *Nessun comando per la sidebar*: Catalyst ne fornisce già uno su ⌃⌘S, e
  duplicare la scorciatoia fa fallire la costruzione della barra dei menu —
  l'app moriva all'avvio. (Trovato e corretto stanotte.)
- **Finestra**: dimensione minima 960×660. La barra del titolo è lasciata com'è:
  provare a nasconderne il titolo o a svuotarne la toolbar porta via anche
  l'intestazione della sidebar, dove stanno il nome dell'app e le Impostazioni.
- **Azioni rapide** (Strumenti): erano una riga che scorre di lato. Nella colonna
  centrale di uno split ci stanno tre icone e mezza su cinque, e l'ultima resta
  tagliata a metà senza un pollice per trascinarla. Ora, dove c'è un puntatore,
  vanno a capo in una griglia e si vedono tutte.
- **Benvenuto e tour**: stavano larghi quanto la finestra, con un pulsante
  «Inizia» lungo un metro. Ora si tengono in una colonna leggibile e la riga
  sotto il titolo, che diceva *«The PDF editor for iPhone and iPad»*, sul Mac
  dice il Mac.
- **Colonna di destra della chat**: il segnaposto «No conversation yet» dipingeva
  il proprio sfondo solo dietro al testo, e nella colonna restava un rettangolo
  nero sospeso. Ora il colore copre tutta la colonna.
- **Fotocamera in continuità**: sul Mac la webcam guarda la persona, non il
  foglio. Dove c'è, lo scanner sceglie **l'iPhone offerto via Continuity
  Camera**, che qui appare come un normale dispositivo di acquisizione; la
  webcam è il ripiego.
- **CloudKit non è più fatale**: se il negozio con mirroring non si carica,
  l'app riprova in locale invece di chiamare `fatalError`. I documenti stanno
  comunque nel negozio locale; smette solo di sincronizzare.
- **Popup delle recensioni**: si dimensionava su `UIScreen.main`, cioè sul
  *display*. Su Mac (e su un iPad in Stage Manager) la finestra è più piccola e
  il popup finiva centrato su un rettangolo che nessuno vede. Ora riempie la
  finestra.

---

## 3. Cosa è già verificato

- [x] Compila per Mac Catalyst — zero errori.
- [x] **366 test unitari su Mac Catalyst: tutti verdi.** Tutto il core (PDFKit,
      compressione, OCR, utility, persistenza) funziona su Mac.
- [x] **366 test unitari su iPhone 17 Pro (simulatore): tutti verdi**, e il build
      iOS passa. Niente di quanto fatto per il Mac ha toccato iOS.
- [x] L'app si avvia, costruisce la barra dei menu e resta su senza crash.

Gli **UI test su Mac non sono eseguibili da riga di comando** senza qualcuno alla
tastiera: il runner chiede l'autorizzazione all'automazione di sistema
(*"Authentication canceled. System authentication is running"*). Concessa una
volta, dovrebbero girare — ma useranno le coordinate pensate per il telefono,
quindi aspettati rossi di layout, non di sostanza.

**L'ho anche vista.** Cattura schermo e accesso assistivo erano negati (Mac
bloccato), quindi le ho fatto fotografare la propria finestra dall'interno, con
uno strumento di debug temporaneo poi rimosso. Le quattro correzioni di layout
qui sopra — azioni rapide, benvenuto, tour, colonna della chat — vengono da lì:
erano visibili, e sono state corrette e riguardate una per una.

Restano da guardare con gli occhi le cose che richiedono di **premere** qualcosa:
non ho potuto usare un bottone né trascinare un file. È tutto nella sezione 4.

### 3.1 Il giro con i file di prova

I file di `~/Desktop/PdfExpert-Test/` sono stati fatti passare dalla stessa porta
da cui entra un file aperto dal Finder. Tre difetti trovati, due corretti.

| File | Esito |
|---|---|
| `contratto-v1.pdf` | ✅ si apre nell'editor: miniature, pagina leggibile, barra pagine |
| `protetto-prova1234.pdf` | ✅ chiede la password — **dopo la correzione qui sotto** |
| `foto-foglio-1.jpg` | ✅ diventa un PDF di una pagina con la foto dentro |
| `danneggiato.pdf` | ⚠️ non crasha più, ma **non dice niente** |
| `fatture.xlsx` | ⚠️ nessun segno in 16 s: né conversione, né errore, né attesa |
| `piano-commerciale.pptx` | ⚠️ come sopra |

**Corretto — il nome del file spariva.** La copia di lavoro veniva rinominata
`incoming-<UUID>.pdf`, e quel nome non restava privato: era quello che l'alert
della password chiedeva («Enter the password of
incoming-301ACA79-2AF1-4763-B0B4-5D9467590767»), quello mandato al servizio di
conversione e quello con cui il documento veniva salvato. Ora l'UUID sta sulla
cartella e il file tiene il suo nome. **Valeva anche su iPhone.**

**Corretto — un PDF danneggiato ammazzava l'app.** `importPdf` aveva un
`assertionFailure` sul file illeggibile: in debug abbatteva il processo, in
release non faceva nulla e l'apertura sembrava semplicemente non funzionare. Un
file corrotto non è un errore di programmazione: ora imposta un errore vero.
**Anche questo valeva su iPhone.**

**Aperto — su Mac gli errori non arrivano a schermo.** L'errore adesso *viene
impostato*, ma l'avviso non compare; e Excel e PowerPoint non mostrano né
conversione né fallimento. Il sospetto è che gli `.alert` appesi a `ToolsView`
non si presentino in questo percorso su Catalyst (ho fotografato tutte le
finestre dell'app, alert di sistema compresi: non c'è). Serve l'app in mano per
chiuderla — vedi 4.3.

---

## 4. Da provare domattina

### 4.1 Prima occhiata
*(le prime due le ho già viste in fotografia — restano qui perché vanno
confermate ridimensionando davvero la finestra)*
- [ ] La finestra si apre di una dimensione sensata e si ridimensiona; sotto una
      certa misura non si stringe più.
- [ ] Tre colonne: sezioni e cartelle a sinistra, lista al centro, documento a
      destra. **Mai** una tab bar in fondo, nemmeno stringendo la finestra.
- [ ] In cima alla sidebar compaiono il nome dell'app e il pulsante Impostazioni
      (nella barra del titolo, disegnata dal sistema).
- [ ] **L'icona nel Dock.** È quella di iOS scalata: probabilmente un quadrato
      pieno, senza il margine che hanno le icone Mac. Se stona → va disegnata una
      icona macOS vera (con Icon Composer su macOS 26). *Atteso: da fare.*
- [ ] I testi non sono tagliati e le spaziature non sembrano da telefono.

### 4.2 Menu e tastiera
- [ ] **⌘O** apre il pannello file e importa un PDF.
- [ ] ⌘N, ⌘⇧S (scansiona), ⌘⇧P (immagine → PDF).
- [ ] ⌘1/2/3/4 cambiano sezione, ⌘F va in Cerca.
- [ ] **⌘,** apre le Impostazioni **dal menu PDF Pro**, non da «Vai».
- [ ] Vista ▸ Nascondi barra laterale (⌃⌘S) funziona — è quella di sistema.
- [ ] Con l'editor aperto le scorciatoie non cambiano la scheda sotto.

### 4.3 File dentro e fuori — **la parte più a rischio**
- [ ] **Trascina un PDF sulla finestra**: appare il riquadro tratteggiato e il
      file si apre.
- [ ] Doppio clic su un PDF nel Finder con PDF Pro come app predefinita.
- [ ] «Apri con» dal Finder, e un `.docx` trascinato dentro.
- [ ] **Condivisione**: apri un documento e premi Condividi.
      ⚠️ Punto da guardare per primo: il pannello di condivisione è un
      `UIActivityViewController` presentato *dentro* una sheet, e su Mac questa
      forma a volte esce vuota o non si chiude. Se succede, si presenta il
      controller direttamente con la sorgente del popover — mezz'ora di lavoro.
      **È il gate del paywall, quindi è la riga più importante del documento.**
- [ ] «Salva su File» dal pannello di condivisione scrive davvero su disco.
- [ ] **Apri `danneggiato.pdf`**: deve comparire un avviso di errore. Se non
      compare, il difetto è quello aperto in 3.1 — l'errore c'è, l'avviso no.
- [ ] **Apri `fatture.xlsx` e aspetta**: la conversione deve mostrare l'attesa e
      poi il documento, o dire perché non ce l'ha fatta. Oggi non fa nessuna
      delle tre cose. Con il proxy configurato, prova anche il ripiego online.
- [ ] Il documento importato **si chiama come il file**, non `incoming-…`
      (corretto stanotte, ricontrollalo sul serio in archivio).

### 4.4 Scanner e fotocamera
- [ ] Con un iPhone vicino: lo scanner usa **la fotocamera dell'iPhone**
      (Continuity Camera) e non la webcam.
- [ ] Senza iPhone: usa la webcam e non crasha; si capisce cosa sta inquadrando.
- [ ] macOS chiede il permesso fotocamera una volta sola.

### 4.5 Editor e strumenti
- [ ] L'editor si apre a tutta finestra e si chiude.
- [ ] Almeno cinque strumenti diversi, uno per categoria (unisci, comprimi,
      firma, filigrana, OCR).
- [ ] **La firma**: PencilKit su Mac si disegna col trackpad? Se il canvas non
      accetta il puntatore, sul Mac la firma va presa da immagine o da testo —
      le due strade esistono già nel selettore.
- [ ] Il ritaglio immagine (Mantis) risponde al mouse.
- [ ] I dialoghi escono come **avvisi**, non come fogli dal bordo inferiore.

### 4.6 Conti, acquisti, sincronizzazione
- [ ] iCloud: un documento creato sull'iPhone compare sul Mac (serve il profilo
      vero — con la firma ad-hoc CloudKit è spento).
- [ ] **Universal Purchase**: con lo stesso ID Apple l'abbonamento è già attivo,
      il paywall non si presenta all'esportazione.
- [ ] Il paywall, se si apre, sta in una finestra decente.
- [ ] ChatPDF e gli strumenti online rispondono (serve il token App Check
      registrato su Firebase staging — l'app lo stampa a ogni avvio).

### 4.7 Estensioni
- [ ] Il **widget** appare nel Centro Notifiche del Mac e mostra i documenti
      recenti (dipende dall'App Group col prefisso del team).
- [ ] L'**estensione di condivisione** compare nel menu Condividi di altre app.

---

## 5. Rimasto fuori, da decidere insieme

- **Stampa (⌘P).** Un'app PDF su Mac senza stampa è monca, ma oggi l'app non
  stampa su nessuna piattaforma: è una funzione nuova, non un adattamento, e non
  l'ho aggiunta di mia iniziativa. Costo stimato: poche ore, vale anche su iOS.
- **Icona macOS** (vedi 4.1).
- **Traduzioni**: la stringa nuova del drag & drop («Drop the file to open it»)
  è solo in inglese. Va aggiunta alle 14 lingue di `Localizable.xcstrings`.
- **Più finestre**: oggi l'app è a finestra singola
  (`UIApplicationSupportsMultipleScenes = false`). Su Mac aprire due documenti
  affiancati sarebbe naturale, ma tocca il coordinatore, che è pensato per una
  scena sola. Da valutare a parte.
- **App Store Connect**: quando si vorrà pubblicare, va spuntata la disponibilità
  su macOS per l'app esistente (Universal Purchase) e servono le schermate Mac.
