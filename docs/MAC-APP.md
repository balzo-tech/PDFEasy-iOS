# L'app per Mac — stato e giro di prova

Scritto la notte del 1 agosto 2026, branch `feature/mac-app`; **aggiornato il
pomeriggio del 1 agosto**, dopo il primo giro fatto davvero col mouse.
Da leggere prima di aprire Xcode: la prima sezione dice **come si avvia**, la
seconda **cosa è stato deciso e perché**, la terza è la **checklist** da spuntare,
la **sesta è cosa è stato corretto** e cosa resta rosso.

Segna così: `[x]` passata · `[!]` problema (scrivi cosa) · `[-]` non provabile ora.

✅ **La sezione 4 è stata percorsa tutta**, premendo, digitando e trascinando per
davvero. Restano scoperte solo le righe che vogliono hardware che non c'è
(Continuity Camera, widget e condivisione finché la 1.26 è installata) e le due
di forma segnate `[!]`.

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
  ⚠️ Il menu File **non arriva da SwiftUI**: si costruisce a mano nell'app
  delegate, per il motivo spiegato in 6.1. Da SwiftUI vengono solo il menu Vai e
  le Impostazioni.
  *Nessun comando per la sidebar*: duplicare una scorciatoia che il sistema già
  possiede fa fallire la costruzione della barra dei menu e l'app muore
  all'avvio (trovato e corretto stanotte, e di nuovo il pomeriggio con ⌘O).
  ⚠️ Quella di sistema su ⌃⌘S però **non esiste** — vedi 6.6.
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
- [x] **367 test unitari su Mac Catalyst: tutti verdi** (erano 366; il 367° copre
      la firma senza ritaglio, vedi 6.3). Tutto il core (PDFKit, compressione,
      OCR, utility, persistenza) funziona su Mac.
- [x] **367 test unitari su iPhone 17 Pro (simulatore): tutti verdi**, e il build
      iOS passa. Niente di quanto fatto per il Mac ha toccato iOS.
- [x] L'app si avvia, costruisce la barra dei menu e resta su senza crash.

**Gli UI test su Mac girano** (aggiornato il 1 agosto, mattina). La nota di
stanotte diceva il contrario: non è così, il runner parte da riga di comando,
preme i bottoni e registra un video. Quello che serve è:

```bash
xcodebuild -project pdfexpert.xcodeproj -scheme "PdfExpert Staging" \
  -configuration "Staging Debug" \
  -destination 'platform=macOS,variant=Mac Catalyst,arch=arm64' \
  -derivedDataPath DerivedData -only-testing:PdfExpertUITests \
  -allowProvisioningUpdates DEVELOPMENT_TEAM=G6RAKRKZPR test
```

**`DEVELOPMENT_TEAM` va passato a mano**: i due target di test non ce l'hanno
nelle loro impostazioni, e senza xcodebuild si ferma su *"Signing for
'PdfExpertTests' requires a development team"*. Vale la pena metterlo nel
progetto. La firma ad-hoc non è un'alternativa: gli entitlement iCloud la
rifiutano (*"has entitlements that require signing with a development
certificate"*).

**Usa Staging, non Production.** Su iOS il bundle di test reinstalla l'app a ogni
giro; su Mac l'app riusa il contenitore vero, quindi il seed dell'archivio — che
si posa solo su un archivio vuoto — viene saltato e i test falliscono dicendo
«the seeded archive never appeared», che suona come un archivio rotto e non lo è.
Staging ha un contenitore suo, vuoto, e non tocca i documenti veri.

E i **366 test unitari** girano allo stesso modo, con `-only-testing:PdfExpertTests`.

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

### 3.2 Il giro della mattina del 1 agosto

Fatto sull'app vera in esecuzione (`Production Debug-maccatalyst`, profilo di
sviluppo vero, quindi iCloud e StoreKit attivi), fotografando ogni finestra
dalla riga di comando. **Senza poter premere niente**: l'accesso assistivo al
terminale non era concesso, quindi tutto ciò che richiede un clic, un tasto o un
trascinamento resta non provato. Le righe qui sotto sono solo quelle
effettivamente viste.

**Chiuso il punto rimasto aperto in 3.1.** Su Mac **gli avvisi compaiono**: il
file danneggiato apre un alert in una finestra propria. Il difetto sospettato
(«gli `.alert` di `ToolsView` non si presentano su Catalyst») non esiste.

| Prova | Esito |
|---|---|
| `contratto-v1.pdf` da «Apri con» | ✅ editor a tutta finestra, 3 miniature, pagina leggibile, titolo `contratto-v1` |
| `protetto-prova1234.pdf` | ✅ chiede la password, **e la chiede col nome giusto** |
| `solo-testo-12-pagine.txt` | ✅ 15 pagine impaginate |
| `scansione-lunga.pdf` (13,5 MB, 12 pagine) | ✅ aperto in **meno di 3 s**, tutte le miniature disegnate — nessun blocco |
| `foto-foglio-1.jpg` | ✅ diventa un PDF di una pagina |
| `danneggiato.pdf` | ⚠️ l'avviso c'è, ma dice la cosa sbagliata (sotto) |
| `relazione.docx` | ❌ *«This document could not be converted on your device»* |
| 366 test unitari su Mac Catalyst | ✅ 0 fallimenti |

~~**Difetto — un file rotto dice «Internal Error. Please try again later».**~~
**Corretto il 2 agosto**: `urlToPdfConversionError` condivideva la stringa di
`unknownError`, così si chiedeva di riprovare una cosa che non riuscirà mai e si
dava la colpa all'app invece che al file. Ora dice «This file could not be
opened. It may be damaged, or not a PDF.», in tre lingue, con un test che impedisce
ai due casi di ritrovarsi con la stessa frase. **Valeva anche su iPhone.**

**Difetto — su Mac i formati Office non si convertono mai.** Non è il singolo
file: `.txt` passa dallo stesso motore e funziona, quindi WebKit e
`UIPrintPageRenderer` su Catalyst vanno. Quello che manca è la resa dei
documenti Office, che è una capacità del WebKit **di iOS** e su macOS non
esiste — esattamente quello che l'intestazione di `DocumentRenderUtility.swift`
dà per scontato («iOS renders Office, iWork, RTF and HTML natively»). Quindi
Word/Excel/PowerPoint → PDF è morto in partenza su Mac, e il ripiego online non
parte perché il proxy non è configurato. **I 366 test verdi non lo coprivano:
nessun test converte davvero un `.docx`** — ci sono solo HTML e la lista di
estensioni.

**Difetto — iCloud non sincronizza.** Il log ripete `CKErrorDomain Code=2`,
`CKInternalErrorDomain Code=1011` e *«Never successfully initialized»*. L'app
gira in Production, cioè sull'ambiente CloudKit di produzione: da verificare se
lo schema è stato deployato lì.

**Da sapere prima di provare condivisione, widget ed estensioni:** su questo Mac
è **installata anche la versione iOS-su-Mac 1.26** (`/Applications/PDF Pro.app`,
con dentro `Wrapper/PdfExpert.app`), **con lo stesso bundle ID** della Catalyst.
`pluginkit` risolve `eu.balzo.pdfexpert.ShareFileExtension` alla 1.26, non alla
build Catalyst. Finché quella resta installata, «Condividi» e il menu Condividi
di altre app parlano con l'app vecchia, e il giro di prova non dice niente sulla
nuova. Va tolta prima — o almeno saputo.

**Verificato senza toccare l'app:**
- L'App Group col prefisso del team funziona su Mac: in
  `~/Library/Group Containers/G6RAKRKZPR.group.eu.balzo.pdfexpert/` ci sono
  `widget-documents.json` e le miniature, scritti dall'app Catalyst. Esiste
  anche il contenitore senza prefisso, ma è vuoto.
- Entrambe le estensioni della build Catalyst sono registrate in LaunchServices.
- L'icona: `AppIcon.appiconset` ha **un solo `icon.png` del 2023**, nessuna
  variante macOS. Nel Dock è il quadrato pieno di iOS, come previsto.

**Correzione a questo documento:** la sezione 5 dice che la stringa del drag &
drop va aggiunta «alle 14 lingue di `Localizable.xcstrings`». Il file ha **3
lingue** (en, es, it) — 14 sono le lingue della scheda su App Store, non quelle
dell'interfaccia. Quindi mancano due traduzioni, non tredici.

### 3.3 Il giro con gli UI test

Fatto sulla classe `EditorNavigationUITests`, sei test, su Staging Mac Catalyst.

**Esito: 6 su 6 verdi su Mac, e 6 su 6 su iPhone.**

**Passa la riga più importante del documento.**
`testSharingShowsThePaywallCarryingTheRenewalNotice` è verde: Condividi apre il
paywall con l'avviso di rinnovo, il paywall si chiude e il documento resta lì.
Verde anche `testThePaywallOffersTheYearlyPlanPreselectedAndNoMonthlyOne`:
annuale preselezionato, mensile ritirato. Il dubbio della riga 4.3 — «su Mac la
sheet a volte esce vuota o non si chiude» — **non si verifica**.

**Alla fine sono verdi tutti e sei**, e restano verdi tutti e sei anche su
iPhone 17 Pro. Cioè su Mac: i nove strumenti in push aprono la loro schermata e
il tasto indietro riporta al documento; i due strumenti immediati rispondono e il
loro avviso si chiude; uno strumento aperto e abbandonato due volte non lascia
niente dietro.

Ma **nessuno dei sei passava al primo colpo**, e non per colpa dell'app: i test
davano per scontata la forma del telefono. Le cinque differenze, tutte ora
gestite nel file — chi scriverà altri UI test le incontrerà di nuovo:

1. **Su Mac il contenitore non è mai pulito** (vedi sopra): usa Staging.
2. **Un clic sulla card non apre l'editor.** Riempie la colonna di destra con
   l'anteprima; l'editor è un passo più in là, il tasto **Edit** (⌘E).
3. **L'editor non ha una barra di navigazione.** Titolo e tasti stanno nella
   **barra della finestra**: `app.navigationBars[…]` non trova niente, si passa
   da `app.toolbars`.
4. **Il titolo di una schermata è il titolo della *finestra*.** Non un
   `navigationBar`: `app.windows["Reorder pages"]`.
5. **Un `.alert` di SwiftUI arriva come `Sheet`, non come `Alert`.**
   `app.alerts` resta vuoto mentre l'avviso è in mezzo allo schermo — si chiede
   il bottone, `app.buttons["Ok"]`.

E due trappole di metodo, che fanno perdere un'ora a testa:

- **Gli UI test su Mac pilotano lo schermo vero.** Se qualcuno usa la macchina
  mentre girano, i clic finiscono altrove e si prendono rossi che non c'entrano
  niente («"Edit" Button never appeared»). Rifare il giro a macchina ferma prima
  di credere a un rosso.
- **Il video allegato riprende solo lo schermo principale.** Se la finestra
  dell'app è sul secondo monitor, i filmati mostrano il desktop e sembra che
  l'app sia sparita o crashata. Non fidarsi del video: l'albero
  dell'interfaccia, allegato allo stesso fallimento, dice dov'è la finestra e
  cosa c'è dentro. È da lì che è saltato fuori che «Invert colors» su Mac
  funziona benissimo — avviso, testo e «Ok» tutti al loro posto.

Il **trascinamento sintetico non scorre il pannello** su Mac (le coordinate sono
normalizzate sulla *finestra* e partono fuori dal pannello): le piastrelle sotto
la piega si raggiungono dalla ricerca del pannello, che è anche come le
raggiunge una persona.

### 3.4 Tutto il bundle UI su Mac: 24 test, 10 verdi

Le altre cinque classi non sono state adattate — hanno copie loro degli stessi
aiutanti. I 14 rossi però si leggono, e quasi tutti sono le **stesse** differenze
di forma già elencate qui sopra:

| Quanti | Messaggio | Cos'è |
|---|---|---|
| 7 | «il documento non si è aperto» | Il clic sulla card riempie la colonna di destra: manca il passo sul tasto **Edit**. Differenza 2. |
| 3 | «the tab bar never appeared» | **Per progetto**: su Mac la shell non collassa mai in tab bar. Un test che aspetta una tab bar lì non passerà mai — va guardata la sidebar. |
| 1 | «"Strumenti" Button non è mai comparso» | La barra dell'editor è la toolbar della finestra. Differenza 3. |
| 1 | «le impostazioni non si sono aperte» | Su Mac le Impostazioni sono nel menu dell'app (⌘,), non dove le cerca il test. |
| 1 | «"Delete" Button never appeared» | Cancellare una cartella su Mac non si fa con lo scorrimento del dito. Da adattare. |
| **1** | **«the save sheet stayed up»** (`ScannerSaveUITests`) | **L'unico che merita gli occhi.** |

**Il rosso da guardare: salvare una scansione.** Il test apre la sheet di fine
scansione, legge il nome proposto, preme «Save as PDF» — e la sheet non se ne
va. E soprattutto: nel negozio CoreData di Staging **non c'è nessuna scansione
salvata**, solo i cinque documenti seminati. Quindi o il tocco su «Save as PDF»
non arriva, o il salvataggio non avviene: sono due cose molto diverse e per
distinguerle serve premerlo con un dito vero. È l'unica riga di questo giro in
cui l'app potrebbe avere torto.

**Difetto — il pannello degli strumenti su Mac è grande quanto su un telefono.**
`PdfEditView.swift:103` lo presenta con una `.sheet` senza dimensione dichiarata,
e su Catalyst il sistema le dà la misura da form-sheet: una scatoletta di circa
390×330 al centro di una finestra da 1024, che mostra **5 piastrelle su 16** con
la terza fila tagliata a metà. Gli strumenti restano raggiungibili — dentro c'è
una `ScrollView` e la rotella funziona — ma la forma è sbagliata per il Mac.

**Osservazione di forma, Mac.** Nella scheda Scanner il pulsante tondo flottante
in basso duplica «Start scanning» e resta sospeso a metà della colonna centrale:
è un modo iPhone. Su Mac starebbe nella barra degli strumenti.

---

## 4. Da provare domattina

### 4.1 Prima occhiata
*(le prime due le ho già viste in fotografia — restano qui perché vanno
confermate ridimensionando davvero la finestra)*
- [x] La finestra si apre di una dimensione sensata (1512×950). **Il
      ridimensionamento e il limite minimo restano da provare**: serve il mouse.
- [x] Tre colonne: sezioni e cartelle a sinistra, lista al centro, documento a
      destra. **Mai** una tab bar. *(Visto su Files, Tools, Scanner, ChatPDF e
      Search. Stringendo la finestra non è stato provato.)*
- [x] In cima alla sidebar compaiono il nome dell'app e il pulsante Impostazioni.
- [!] **L'icona nel Dock.** `AppIcon.appiconset` contiene un solo `icon.png` del
      2023, senza varianti macOS: nel Dock è il quadrato pieno di iOS. Va
      disegnata un'icona macOS vera (Icon Composer su macOS 26).
- [x] I testi non sono tagliati e le spaziature non sembrano da telefono
      *(su cinque schermate; il resto non è stato raggiunto)*.

### 4.2 Menu e tastiera
- [x] **⌘O** apre il pannello file e importa un PDF — **dopo la correzione**: era
      inerte, come tutto il menu File. Vedi 6.1.
- [x] ⌘N, ⌘⇧S (scansiona), ⌘⇧P (immagine → PDF) — stessa storia, stessa correzione.
- [x] ⌘1/2/3/4 cambiano sezione, ⌘F va in Cerca.
- [x] **⌘,** apre le Impostazioni **dal menu PDF Pro**, non da «Vai».
- [!] Vista ▸ Nascondi barra laterale (⌃⌘S) **non esiste**: il menu Vista contiene
      solo «Enter Full Screen». Catalyst non la fornisce, contro quanto dava per
      scontato il commento in `PdfProCommands.swift`. Resta il pulsante nella
      barra della finestra, e stringendola la sidebar si chiude da sé.
- [x] Con l'editor aperto le scorciatoie non cambiano la scheda sotto — provato
      aprendo l'editor, premendo ⌘2 e richiudendolo: sotto c'era ancora Files.

### 4.3 File dentro e fuori — **la parte più a rischio**
- [x] **Trascina un PDF sulla finestra**: il file si apre. Provato **a mano** il
      1 agosto con `relazione 2.pdf`: entra e l'editor si apre su di lui.
      ⚠️ Con un trascinamento **sintetico** (`cliclick`) non succede niente, e per
      mezz'ora è sembrato un difetto: vedi 6.2. Chi proverà a automatizzare questa
      riga si fermerà allo stesso muro.
- [-] Doppio clic su un PDF nel Finder con PDF Pro come app predefinita.
      ⚠️ **Non provabile finché `/Applications/PDF Pro.app` 1.26 è installata**:
      stesso bundle ID, quindi non si sa quale delle due risponde.
- [x] «Apri con» dal Finder: apre l'editor a tutta finestra, col nome giusto.
      Il `.docx` entra ma **non si converte** (vedi 3.2).
- [x] **Condivisione**: il gate del paywall funziona su Mac — verde
      `testSharingShowsThePaywallCarryingTheRenewalNotice`. Il timore che la
      sheet uscisse vuota o non si chiudesse **non si verifica**: il paywall si
      apre, porta l'avviso di rinnovo, si chiude e lascia il documento al suo
      posto. *Resta da vedere il pannello di sistema vero e proprio, che si
      raggiunge da abbonato — il test si ferma al paywall.*
- [ ] «Salva su File» dal pannello di condivisione scrive davvero su disco.
- [x] **Apri `danneggiato.pdf`**: l'avviso compare, e dal 2 agosto **dice la cosa
      giusta** — «This file could not be opened. It may be damaged, or not a
      PDF.» invece di «Internal Error. Please try again later». Vedi 3.2.
- [!] **Apri `fatture.xlsx` e aspetta**: ora dice perché non ce l'ha fatta
      («could not be converted on your device»), ma su Mac **non ce la farà
      mai** — vedi 3.2. Il ripiego online non parte: proxy non configurato.
- [x] Il documento importato **si chiama come il file**, non `incoming-…`:
      confermato dal titolo della finestra e dall'alert della password.
      ⚠️ **In archivio non è ancora verificato**: aprire un file dal Finder lo
      mostra soltanto, si salva premendo il ✓ — che richiede un clic.

### 4.4 Scanner e fotocamera
- [ ] Con un iPhone vicino: lo scanner usa **la fotocamera dell'iPhone**
      (Continuity Camera) e non la webcam. *(Non provato: nessun iPhone vicino
      durante il giro.)*
- [x] Senza iPhone: usa la webcam e non crasha; si capisce cosa sta inquadrando —
      anteprima a tutta finestra, Flash / Filtri / Otturatore e pulsante di scatto.
- [x] macOS chiede il permesso fotocamera una volta sola: alla prima apertura
      compare il pannello di sistema con Consenti / Non consentire.
      ⚠️ Se il permesso è già stato **negato** l'app non chiede più niente e
      mostra «Camera access is off» con «Apri Impostazioni», che è corretto. Per
      rifare la prova da capo: `tccutil reset Camera eu.balzo.pdfexpert.staging`.
- [x] **Salvare la scansione**: scatto → «✓ 1 pagina» → sheet «Scan complete» →
      **Save as PDF salva davvero** e la scansione compare nella scheda Scanner.
      🎉 È la riga che il rosso di `ScannerSaveUITests` faceva temere: **l'app non
      ha torto**, è il tocco sintetico del test che non arriva sul bottone della
      sheet. Il test resta da adattare, come le altre cinque classi (vedi 3.4).

### 4.5 Editor e strumenti
- [x] L'editor si apre a tutta finestra: miniature a sinistra, pagina al centro,
      barra pagine in fondo. *(La chiusura richiede un clic sul ✓.)*
- [x] Almeno cinque strumenti diversi. **Gli UI test ne aprono undici** e tornano
      indietro da ognuno: riordina, dividi, estrai, numeri di pagina, filigrana,
      comprimi, esporta, permessi, info documento, inverti colori, togli pagine
      bianche.
- [x] **L'esito della filigrana**, guardato con gli occhi: «PROVA MAC» applicata,
      e l'avviso dice la cosa giusta — «A watermarked copy has been saved to your
      archive. This document is unchanged.» La copia c'è, l'originale è intatto.
- [x] **L'esito dell'OCR**: su un documento con due pagine di testo e una foto
      diceva soltanto «No text was recognized in your PDF», nascondendo la parte
      già ricercabile. Corretto (vedi 6.5) — **valeva anche su iPhone**.
- [!] **Il pannello degli strumenti è più piccolo della finestra**: con la
      finestra a 1024 mostra otto piastrelle e taglia a metà la terza fila. Meno
      grave di quanto scritto in 3.3 (che ne contava 5 su 16), ma la forma resta
      da telefono. La **ricerca dentro il pannello funziona** ed è il modo di
      arrivare a quelle sotto la piega.
- [x] **La firma**: PencilKit **si disegna col trackpad**. Il tratto compare, il
      pulsante Conferma si accende, la firma si appoggia sulla pagina, **si
      trascina e si ridimensiona col mouse**, e Finish la lascia nel documento.
- [x] Il ritaglio immagine (Mantis) risponde al mouse — **no**: si apriva nero e
      vuoto, senza immagine, senza maniglie e senza uscita, e la foto era persa.
      Su Mac il ritaglio è stato tolto di mezzo (vedi 6.3).
- [x] I dialoghi escono come **avvisi**, non come fogli dal bordo inferiore.

### 4.6 Conti, acquisti, sincronizzazione
- [!] iCloud: **non sincronizza**, anche col profilo vero. `CKErrorDomain Code=2`
      e `CKInternalErrorDomain Code=1011`, «Never successfully initialized».
      Vedi 3.2.
- [ ] **Universal Purchase**: con lo stesso ID Apple l'abbonamento è già attivo,
      il paywall non si presenta all'esportazione.
- [ ] Il paywall, se si apre, sta in una finestra decente.
- [ ] ChatPDF e gli strumenti online rispondono (serve il token App Check
      registrato su Firebase staging — l'app lo stampa a ogni avvio).

### 4.7 Estensioni
- [ ] Il **widget** appare nel Centro Notifiche del Mac e mostra i documenti
      recenti. *Il presupposto è verificato*: l'App Group col prefisso del team
      contiene `widget-documents.json` e le miniature, scritti dall'app Catalyst.
      Resta da guardarlo nel Centro Notifiche.
- [ ] L'**estensione di condivisione** compare nel menu Condividi di altre app.
      ⚠️ Oggi `pluginkit` risolve quel bundle ID alla **1.26 iOS-su-Mac**: la
      prova non dice niente sulla Catalyst finché l'altra è installata.

---

## 5. Rimasto fuori, da decidere insieme

- **Stampa (⌘P).** Un'app PDF su Mac senza stampa è monca, ma oggi l'app non
  stampa su nessuna piattaforma: è una funzione nuova, non un adattamento, e non
  l'ho aggiunta di mia iniziativa. Costo stimato: poche ore, vale anche su iOS.
- **Icona macOS** (vedi 4.1).
- ~~**Traduzioni**~~ — **fatte il 1 agosto**: «Drop the file to open it», «Apri…»,
  «Impostazioni…» e «The PDF editor for your Mac» erano solo in inglese, e con
  loro le tre stringhe nuove del pomeriggio. Ora il lint di localizzazione è
  `clean`. `Localizable.xcstrings` ha **3 lingue** (en, es, it), non 14 — 14 sono
  le lingue della scheda su App Store.
- **Più finestre**: oggi l'app è a finestra singola
  (`UIApplicationSupportsMultipleScenes = false`). Su Mac aprire due documenti
  affiancati sarebbe naturale, ma tocca il coordinatore, che è pensato per una
  scena sola. Da valutare a parte.
  ⚠️ Da sapere: quel `false` è anche il motivo per cui il menu File va costruito
  a mano (6.1). Accendendo le scene multiple, il gruppo SwiftUI tornerebbe a
  funzionare — ma è una decisione molto più grande di un menu.
- **App Store Connect**: quando si vorrà pubblicare, va spuntata la disponibilità
  su macOS per l'app esistente (Universal Purchase) e servono le schermate Mac.

---

## 6. Corretto il 1 agosto, pomeriggio

Il giro col mouse ha reso sette difetti veri, **tutti corretti e riverificati
sullo schermo**, più un falso allarme (6.2). **367 test iOS + 367 su Mac
Catalyst** (uno nuovo), lint di localizzazione `clean`.

### 6.1 Il menu File era vuoto, e le sue scorciatoie non esistevano
⌘N, ⌘O, ⌘⇧S e ⌘⇧P non facevano **niente**, e nel menu File si vedevano solo le
voci di sistema, grigie perché l'app non è document-based. Causa:
`CommandGroup(replacing: .newItem)` ha bisogno del gruppo «New» che UIKit
costruisce **solo per le app multi-scena**, e questa è a finestra singola — così
ogni bottone messo lì spariva, scorciatoia compresa.
Ora il menu si costruisce a mano in `AppDelegate.buildMenu(with:)`, con le stesse
azioni di prima (`PdfProMenuActions`, condiviso con SwiftUI).
⚠️ **Due scorciatoie di sistema vanno liberate prima**, o la barra dei menu non si
costruisce e **l'app parte senza finestra** — stessa morte del ⌃⌘S di stanotte:
Open… su ⌘O vive in `.open` (non in `.openRecent`) e Duplicate su ⇧⌘S in
`.document`. Rimossi entrambi: erano inerti.
✅ Riprovato sullo schermo: le sette voci ci sono, e **⌘N crea davvero un
documento nuovo**. Con l'editor aperto restano inerti, come devono.

### 6.2 Il drag & drop non era rotto: è il mouse finto a non contare
**Non c'era niente da correggere.** Trascinato **a mano**, un PDF dal Finder entra
e si apre: `dropDestination(for: URL.self)` fa il suo lavoro.
Trascinato con `cliclick` invece non succede **niente** — né riquadro né
importazione — e lo stesso identico trascinamento sintetico da una finestra
Finder all'altra copia il file. Quindi il ponte AppKit→Catalyst scarta gli eventi
di drag sintetici, mentre AppKit li accetta.
⚠️ **La lezione, per chi verrà dopo**: questa riga **non è automatizzabile** con un
mouse finto, e un test che ci provasse sarebbe rosso per sempre senza un difetto
dietro. Vale la pena ricordarlo accanto alle altre trappole degli UI test su Mac
(3.3).
Nel dubbio erano state provate due riscritture — `onDrop(of: [.fileURL])` e un
`UIDropInteraction` sulla finestra — e nessuna cambiava nulla, il che con il senno
di poi era prevedibile: il drop non arrivava affatto al processo. Il codice è
stato **riportato all'originale**, che è la cosa giusta anche col senno di poi:
funzionava già.

### 6.3 Il ritaglio dell'immagine si apriva nero
Dopo lo scatto in «Firma ▸ Da fotocamera», Mantis mostrava il proprio sfondo nero
e nient'altro: niente immagine, niente maniglie, niente barra. Si usciva solo con
Esc, e la foto era persa — quindi **firmare da immagine o da fotocamera era
impossibile sul Mac**, e restava solo la firma disegnata.
Su Mac il ritaglio è saltato: la foto arriva intera all'anteprima della firma.
Peggio del ritaglio, meglio di una schermata senza uscita; torna quando Mantis
imparerà a disegnarsi sotto Catalyst. La scelta è **iniettabile**
(`ImageCropFlow(presentsCropper:)`), così i test continuano a esercitare la
presentazione anche girando su Mac — un test nuovo copre il caso senza cropper.
✅ Riprovato sullo schermo: si scatta, la foto compare nell'anteprima e Conferma
si accende.

### 6.4 Il foglio della firma non si poteva chiudere
Su Mac una form sheet non si trascina via, non si chiude con Esc e non si chiude
cliccando fuori: «Aggiungi firma» era senza uscita (la X che si vede nel tab
Disegno cancella il tratto, non chiude il foglio). Aggiunto un pulsante di
chiusura in alto a sinistra, come quello che il selettore delle firme aveva già.

### 6.5 Quattro cose che l'utente leggeva sbagliate
- **Il menu dell'app diceva «PdfExpert»**, non «PDF Pro» — la prima cosa che si
  legge sul Mac. Il nome viene da `CFBundleName`, e con
  `GENERATE_INFOPLIST_FILE = YES` Xcode ci scrive dentro `PRODUCT_NAME`
  qualunque cosa dicano l'Info.plist **e** `INFOPLIST_KEY_CFBundleName`: provati
  entrambi, perdono. Corregge il plist costruito una build phase in coda al
  target, attiva solo quando `IS_MACCATALYST`. ✅ Ora il menu dice «PDF Pro».
- **«1 pages»**, sul badge dello scanner e nella sheet di salvataggio. Vale anche
  su iPhone.
- **L'OCR nascondeva le pagine già ricercabili**: con due pagine di testo e una
  foto diceva soltanto «No text was recognized in your PDF», che suona come un
  fallimento. Ora quel caso ha una frase sua. Vale anche su iPhone.
- Nelle Impostazioni il tema diceva «System follows your **phone**» anche sul Mac.

### 6.6 Rimasto rosso
- **Vista ▸ Nascondi barra laterale (⌃⌘S)** non esiste: Catalyst non la fornisce.
  Aggiungerla è possibile ma va fatto con la stessa cura di 6.1 — una scorciatoia
  duplicata uccide l'app all'avvio.
- Il **pannello degli strumenti** e il **foglio della firma** restano di misura
  fissa, più stretti della finestra.
- **`Passport scan`** dei test seminati ora porta una firma e una filigrana di
  prova: sono dati del contenitore Staging, si rigenerano cancellandolo.
