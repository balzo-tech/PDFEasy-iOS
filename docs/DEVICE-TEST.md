# Giro di prova su device — 1.27

Da spuntare tutto prima di pubblicare. Ogni riga dice **cosa fare** e **cosa deve
succedere**: se la seconda parte non si verifica, la riga è rossa anche se l'app
non è crashata.

Segna così: `[x]` passata · `[!]` problema (scrivi cosa) · `[-]` non provabile ora.

---

## 0. Prima di cominciare

- [ ] Build **Staging** installata sull'iPhone (`Giuslape`, iPhone 16 Pro, iOS 26.5.2)
- [ ] **Debug token di App Check registrato** — l'app lo stampa in un riquadro a
      ogni avvio; va incollato nel progetto Firebase **staging** (App Check → app
      → ⋮ → Gestisci token di debug). Cambia a ogni reinstallazione.
      Senza, chat e strumenti online falliscono con «non riesco a verificare il
      dispositivo» e al Worker non arriva niente.
- [ ] Un **iPad** per la sezione 11 (oggi non ce n'è uno collegato)
- [ ] Materiale da tenere pronto:
      una **scansione vera di 20+ pagine**, due versioni dello stesso contratto,
      un `.docx`, un `.xlsx`, un `.pptx`, un PDF **protetto da password**, un PDF
      di **una sola pagina**, un PDF con **campi modulo**, un PDF già ricercabile,
      qualche foto storta di un foglio.

---

## 1. Primo avvio — ✅ passata il 2026-07-29

- [x] Onboarding: cinque schermate, avanti **e indietro**, i puntini seguono la pagina
- [x] «Skip» in cima esce subito
- [x] Alla fine del tour compare il **permesso di tracciamento** (una volta sola)
- [x] Subito dopo compare il **paywall**, non insieme all'alert
- [x] Chiudendo il paywall si entra nell'app
- [x] Riavviando l'app: niente onboarding, niente secondo prompt di tracciamento

## 2. Acquisti — ✅ passata il 2026-07-29

⚠️ **Prima di comprare, spegni la configurazione StoreKit locale**: Edit Scheme →
Run → Options → **StoreKit Configuration → None**. Lo scheme `PdfExpert Staging`
la referenzia nella `LaunchAction`, quindi un Run da Xcode compra *simulato*: la
transazione ha un `originalID` che conta da zero, Apple non ne sa niente e il
proxy la rifiuta con `402 no_subscription` prima ancora di chiamare Apple. Il
risultato è che chat e strumenti online sembrano rotti mentre il problema è qui.
Poi serve un **Account Apple sandbox** (Impostazioni → Sviluppatore → Account
sandbox). Per rifare una prova: Impostazioni → App Store → Account Sandbox →
Gestisci → annulla l'abbonamento.
Il paywall si raggiunge **provando a far uscire un documento** (condividi,
esporta, stampa), non da un badge PRO.

- [x] Acquisto **settimanale** con prova gratuita → l'app diventa premium
- [x] Acquisto **annuale** con prova gratuita
- [x] Il badge della prova dice il periodo giusto, in italiano
- [x] Chiudere e riaprire l'app: resta premium
- [x] **Ripristina acquisti** su installazione pulita
- [x] Termini e Privacy sotto il paywall aprono pagine **che esistono** (non 404)

## 3. Archivio, cartelle, tag, ricerca

Coperta in parte da `ArchiveFilingUITests` (6 test, simulatore, verdi il
2026-07-29): creare cartella, creare tag, eliminare una cartella tenendo i suoi
documenti, ricerca per nome, ricerca nel testo della pagina, ricerca a vuoto.
Restano da fare a mano le righe non spuntate.

- [x] Creare cartelle e tag — *automatizzato*
- [x] **Assegnarli a un documento** dal menu contestuale (tieni premuto): i due
      sottomenu su schermo piccolo, e il menu non deve uscire dallo schermo
- [x] **Ricerca per nome file** — *automatizzato*
- [x] **Ricerca dentro il testo** di un PDF — *automatizzato* (cerca «Lorem», che
      non compare in nessun nome file)
- [x] Una ricerca che non trova niente non elenca documenti — *automatizzato*
- [x] Un PDF vecchio, mai ri-salvato né OCR, si trova **solo per nome**
- [x] Eliminare una cartella: chiede conferma («The documents inside will be
      kept.») e i cinque documenti restano — *automatizzato*
- [x] Dopo OCR / redazione / annotazioni il documento **conserva cartella e tag**
- [ ] Sync iCloud: il documento appare sull'altro dispositivo
- [ ] Due cartelle con lo stesso nome create su due dispositivi **si fondono in
      una** (dedup attivo da `8055367`): sopravvive la più vecchia per data di
      creazione e si porta dietro i documenti di entrambe. Vale anche per «Lavoro»
      contro «lavoro » — maiuscole e spazi non fanno due cartelle. Idem per i tag,
      che però vengono *condivisi* invece che spostati.

> Le due righe qui sopra vogliono un **secondo dispositivo**. Senza iPad, va bene
> un simulatore con la build Staging e lo **stesso account iCloud**: il container
> è unico e in Development entrambi ci parlano.

## 4. Scanner — ✅ chiusa il 2026-07-29

**Otto difetti in tutto**, tutti corretti e riverificati sul device. È la sezione
che ne ha resi di più, il che era prevedibile: metà di questo schermo non era mai
girata su hardware.

Primo giro il 2026-07-29: **cinque difetti trovati, tutti corretti**. L'anteprima
ruotata di 90° (`0519295`, poi davvero `31fcc93`: il coordinatore di rotazione
va costruito **con** il preview layer), lo scatto fuori asse, la X e i filtri che
richiedevano più tocchi (`contentShape` mancante, corretto anche nelle altre 13
schermate che condividono quella X), i filtri che sembravano non applicarsi (la
cache di rendering non avvisava la vista). Rotazione **riverificata sul device e
funzionante**. Dettagli in `scanner-camera-traps`.
Secondo giro, stesso giorno: **altri tre**. Il ritaglio manuale scartato in
silenzio quando copriva meno di un sesto dell'inquadratura (il rendering
chiedeva la domanda del rilevatore automatico), «Salva» da premere due volte
perché la tastiera copriva i bottoni, e lo scatto automatico che partiva senza
farsi sentire. Tutti in `ab993b5`, con quattro test nuovi sulla geometria.

- [x] Il **contorno sta sulla pagina**, non accanto
- [x] Lo **scatto automatico** parte quando il telefono si ferma, non prima —
      e ora si sente: colpetto aptico sul conteggio pagine (`ab993b5`)
- [x] Dopo uno scatto non rifà la stessa pagina
- [x] Flash sulla carta, pinch per lo zoom, tap per la messa a fuoco
- [x] Ritaglio: maniglie con la lente, il crop combacia con i pixel raddrizzati
      — un taglio stretto veniva scartato in silenzio fino a `ab993b5`
- [x] Filtro «Documento» leggibile
- [x] Filtro **«Bianco e nero» su pagina in penombra** (il caso critico: le matite
      chiare non devono sparire)
- [x] «Salva come PDF» → il documento compare nella **tab Scanner**
- [ ] «Salva come immagini» → chiede il permesso *solo aggiunta*, le pagine arrivano
      in Foto — **l'unica riga della sezione mai nominata**: da fare quando capita
- [-] iPad in orizzontale: la pagina esce dritta — nessun iPad disponibile

## 5. Editor su una scansione lunga — ✅ passata il 2026-07-29

Provata con una **scansione vera di 20 pagine**, fatte con lo scatto automatico:
«ci lavoravo tranquillamente». Nessun difetto trovato.

Questa era la prova che contava: è il difetto segnalato il 2026-07-27 («gli
strumenti non funzionano, nemmeno il tasto indietro»), chiuso due volte — per
tempo e per memoria — senza che nessuno potesse verificarlo su hardware. Ora sì.

- [x] Si apre **subito**, con «Preparazione delle pagine…» e le pagine che arrivano
- [x] Applicare uno strumento **non congela** l'editor
- [x] Riordinare e cancellare pagine; la barra sotto la pagina si **riaccende**
- [x] **Sfogliarla da capo a fondo**: la pagina resta nitida (al massimo un istante
      di miniatura sfocata)
- [ ] La memoria non sale sfogliando — **non misurata** con Instruments: l'app
      regge, ma il numero non l'ha visto nessuno
- [x] Trascinare una miniatura di **più posti in un colpo solo** nella striscia
- [x] **Ruotare mentre le pagine si stanno ancora disegnando**: si vede la pagina ruotata
- [x] Tasto **indietro** funziona in ogni momento

---

## 6. I 36 strumenti, uno per uno

Il materiale di prova sta in `~/Desktop/PdfExpert-Test` (generato il 2026-07-31):
i file di partenza e, accanto, i PDF che l'app ne ha prodotto.

### Creare

- [ ] **Scan** — vedi sezione 4
- [ ] **Image to PDF** — più foto insieme → una pagina per foto
- [x] **Word to PDF** — `.doc` provato (`relazione-vecchio-formato.pdf`): titoli,
      grassetto, corsivo, elenco puntato e numerato, tabella con i bordi, tutto reso
      e selezionabile. L'interruzione di pagina non è stata rispettata, ma il salto
      l'ha perso `textutil` scrivendo il `.doc`, non l'app.
      ⚠️ Il `.docx` non si poteva nemmeno scegliere: il picker chiedeva
      `com.microsoft.word.doc`, che è **Word 97**, e `.docx` è un tipo a sé che non
      vi conforma. Corretto il 2026-07-31, con un test che tiene insieme le due
      liste. Da riprovare
- [x] **Excel to PDF** — `fatture.pdf`: le righe e i due fogli ci sono e sono
      leggibili; **si perdono la formattazione** (intestazione colorata → grigia) e
      le larghezze di colonna. È la fedeltà dichiarata in `DocumentRenderUtility`:
      WebKit rende bene i testi e male i fogli di calcolo.
      Le colonne calcolate mostrano `0` perché il fixture non porta i valori
      cached (openpyxl scrive la formula e non il risultato): **non è un difetto
      dell'app**. Da rifare con un `.xlsx` salvato da Excel o Numbers per giudicare
- [x] **Powerpoint to PDF** — `piano-commerciale.pdf`: 3 slide → 3 pagine, tutto il
      testo presente. Il layout della slide (16:9, posizioni, sfondo) è appiattito
      su A4: stesso limite dichiarato
- [x] **Web page to PDF** — una pagina normale: 8 pagine, testo estraibile
- [ ] Una pagina **dietro cookie banner**
- [x] **Markdown to PDF** — `guida.pdf`: intestazioni, elenchi puntati e numerati,
      grassetto, corsivo, codice inline e a blocco, citazione in corsivo — tutto
      corretto. La tabella esce scomposta, che è il comportamento previsto
- [ ] **Create PDF** — documento vuoto
- [ ] **Import PDF** — da File
- [x] **Da un'altra app, condividendo** — un `.docx` da File: «Copia su PDF Pro»
      compare, il file arriva, si converte e si apre. Prima non compariva per
      niente che non fosse un PDF (`relazione 2.pdf`)
- [ ] **Da un'altra app, «Apri con»** — la voce del menu contestuale di File
      mancava: vuole `LSSupportsOpeningDocumentsInPlace`, aggiunta il 2026-07-31.
      Da riprovare con un `.docx` e con un PDF
- [ ] **Nuovo ▸ Converti da qualsiasi file** — la guida in tre passi, rifatta il
      2026-07-31: i testi devono essere **nella lingua del telefono** (erano in
      inglese in ogni lingua), lo swipe deve andare avanti e indietro, «Ho capito»
      chiude. In simulatore:
      `xcrun simctl spawn booted defaults write <bundle-id> debugImportTutorial -int 0..2`

### Organizzare

- [x] **Merge PDF** — tre documenti, 16 pagine, ordine rispettato.
      ⚠️ Ha reso due difetti, corretti il 2026-07-31: nell'editor **la pagina non
      era centrata** (un `GeometryReader` appoggia il figlio in alto a sinistra), e
      con essa era fuori bersaglio il **tocco per modificare una firma o un testo**,
      che invece calcola la posizione come se la pagina fosse centrata
- [x] **Split PDF** — su `una-pagina.pdf` dice l'errore e non apre niente
- [x] **Extract pages** — idem sul PDF di una pagina
- [ ] **Rotate PDF** — una pagina e **tutte**; anche dalla tab Strumenti su file vero
- [x] **Remove blank pages** — `con-pagine-bianche.pdf`: da 6 pagine a 3, tolta
      anche quella che conteneva **soli spazi**
- [x] **Compare PDFs** — `contratto-v1` (3 pagine) contro `contratto-v2` (4): «2
      pagine modificate», la pagina inserita riconosciuta come «esiste solo nella
      versione modificata», e il diff a parole giusto (12.000,00 → 15.000,00,
      quattro → sei, trimestrali → bimestrali). Modalità Visivo allineata.
      Due osservazioni, nessuna bloccante: nel Visivo di quella pagina è evidenziata
      **una sola** delle tre zone cambiate (la data in testa e la riga del
      corrispettivo non lo sono), e nel Testo le parole isolate («1 → 2») si leggono
      senza contesto. Da guardare nel codice, non sul device
- [ ] Confronto fra **due scansioni** senza testo (deve cadere sull'allineamento
      posizionale) e «tieni premuto per vedere l'originale»
- [x] **Compress PDF** — funziona
- [ ] I tre preset su una **scansione lunga** (tempo, memoria, resa) e il documento
      di solo testo che deve dire «già compresso» e tenere Salva spento

### Modificare

- [ ] **Sign PDF** — firma disegnata, da immagine, da fotocamera; **in tema chiaro**
      la firma resta nera su foglio bianco
- [x] **Fill in a form** — `modulo.pdf`, quattro campi e una casella: i valori
      digitati sono nel PDF salvato e si vedono nel file esportato, casella
      compresa
- [ ] **Add text** — posizionamento e salvataggio
- [ ] **Make Searchable (OCR)** — su una scansione vera; barra di avanzamento; il
      testo diventa selezionabile; su un PDF **già ricercabile** deve dirlo e non toccarlo
- [ ] **Page numbers**
- [ ] **Watermark**
- [ ] **Invert colors**
- [ ] **Flatten PDF** — annotazioni e campi diventano parte della pagina

### Proteggere

- [ ] **Protect PDF** — password; riaprendolo la chiede
- [ ] Proteggere un PDF **già protetto** → messaggio in italiano, non in inglese
- [x] **Unlock PDF** — `protetto-prova1234.pdf` (password `prova1234`) si sblocca
- [ ] Su un PDF **senza** password → «già sbloccato»
- [ ] **PDF permissions** — limita stampa e copia; uscendo a metà e rientrando il
      campo password dev'essere **vuoto**
- [ ] **Redact PDF** («Oscura PDF», in Proteggi) — i box nella posizione giusta su
      pagine **ruotate** e a vari zoom; il contenuto sotto non è più recuperabile.
      ⚠️ Il 2026-07-31 la banda nera **non seguiva il dito**: la pagina era spinta
      contro il bordo inferiore da un doppio centraggio (un `.offset` non muove il
      layout, quindi il frame la ricentrava sopra all'offset che già centrava) e
      ogni box cadeva mezzo spazio vuoto più in là. Corretto, da riprovare.
      Verifica finale: dopo «Applica», il dato oscurato **non deve più essere
      estraibile** dal file — a occhio un rettangolo disegnato sopra è identico

### Esportare e leggere

- [ ] **Export PDF as…** — immagini, testo, foto incorporate
- [ ] **Read PDF** — lettore a schermo intero, annotazioni, salva/scarta

### Solo con il servizio online acceso

Se il servizio è spento questi sei **non devono comparire** nel catalogo.

- [ ] **Repair PDF** — su un file danneggiato
- [ ] **Sanitize PDF**
- [ ] **PDF to Word**
- [ ] **PDF to PowerPoint**
- [ ] **PDF to Excel**
- [ ] **PDF/A**
- [ ] Il prompt di passaggio al servizio online è **esplicito**, mai silenzioso

---

## 7. Chat sul documento

- [ ] Domanda su un PDF corto → risposta sensata
- [ ] Le **domande suggerite** sono bottoni e si premono
- [ ] Il **grassetto e gli elenchi** si vedono formattati, non con gli asterischi
- [ ] Un messaggio di soli spazi non parte (e non consuma uno dei venti)
- [ ] Il contatore mensile scende; a quota zero il messaggio è chiaro
- [ ] PDF enorme o con troppe pagine → messaggio in italiano

## 8. Uscire dal documento (il paywall all'uscita)

- [ ] Da **non premium**: condividere/esportare/stampare fa comparire il paywall
- [ ] Dopo l'acquisto l'operazione **riprende da sola**
- [ ] Il file condiviso è **identico** a quello salvato (stessa dimensione), sia
      dall'editor sia dall'archivio
- [ ] Un documento protetto esce protetto

## 9. Widget, Siri, Scorciatoie

- [ ] Entrambi i widget in tutte le taglie sulla schermata Home
- [ ] Le cinque frasi Siri
- [ ] Azioni Scorciatoie su file veri, comprese quelle che girano **senza aprire l'app**
      (merge, rotate, remove blank pages)
- [ ] L'azione premium (extract text) da non premium → errore, **non** un paywall
- [ ] Deeplink `pdfprostaging://`

## 10. Casi d'errore, in italiano e in spagnolo

- [ ] Foglio firma: i tre tab dicono «Disegno / Da immagine / Da fotocamera»
- [ ] Negare l'accesso alla fotocamera in Impostazioni e riprovare
- [ ] Importare una foto illeggibile
- [ ] Etichette lunghe in spagnolo: menu ⋯ dell'editor, preset di compressione, paywall
- [ ] Numeri nelle frasi tradotte: «Pagina 3», «2 di 10», «Benvenuto in PDF Pro»

## 11. iPad — serve un iPad

- [ ] Orizzontale e **Stage Manager / Slide Over**: passare da split a tab bar ad app
      aperta senza perdere scroll, filtri o un flusso a metà
- [ ] Sidebar: righe **tag** e riga «Cartelle e Tag»
- [ ] **Drag & drop** in entrambe le direzioni: PDF e immagini da File/Safari/Mail
      sulla griglia e sul riquadro chat; una card trascinata fuori verso Mail
- [ ] Scorciatoie da tastiera: ⌘N, ⇧⌘S, ⇧⌘P, ⇧⌘I, ⌘1-3, ⌘F, ⌘, — **inerti** durante
      l'onboarding e a editor aperto; ⌘S in editor, ⌘E nel dettaglio, ⌘↑/⌘↓, ⌘↩
- [ ] **Apple Pencil**: firma, palm rejection, il colore predefinito resta **nero**
- [ ] Editor: rail verticale delle miniature, riordino in drag & drop
- [ ] Hover con trackpad su card, tile, quick action, celle del rail

---

## Al termine

- [ ] Tutte le righe sopra spuntate o motivate
- [ ] `bundle exec fastlane test` verde
- [ ] Archivio 1.27 caricato su App Store Connect
- [ ] Screenshot aggiornati (quelli attuali sono dell'interfaccia vecchia)
- [ ] Invio in revisione

---

## Appendice — modificare una firma o un testo già inseriti

Segnalato il 2026-07-29 e concordato: si deve poter correggere un elemento subito
dopo averlo messo, perché è lì che ci si accorge di averlo posizionato male.

**Fatto**

- Il tocco su un'annotazione esistente la riapre in modifica: c'era già in
  `tapOnPdfView`, ma il filtro non trovava mai nulla perché `removeAnnotation`
  azzera `annotation.page` (`5509055`). Con `page` nulla non veniva disegnato
  nemmeno l'overlay: `getView(forAnnotation:)` esce subito.
- Un **bordo tratteggiato** attorno agli elementi già presenti nei due tool, per
  dire che si possono toccare. Prima erano indistinguibili dalla pagina.

**Da fare — modifica dal documento**

Toccare una firma o un testo nell'editor e trovarsi nel tool, già in modifica su
quell'elemento. Serve, in ordine:

1. Un tocco sulla pagina nell'editor. Oggi il pager mostra un'**immagine**, non un
   `PDFView`: le coordinate vanno convertite a mano (l'immagine è in aspect fit,
   vedi `ScanPreviewGeometry.fittedRect` per la stessa matematica già risolta
   altrove).
2. Interrogare il documento: `page.annotations` filtrate con `isSignatureAnnotation`
   / `isTextAnnotation`, e il punto convertito in spazio pagina.
3. Distinguere il tocco dallo scorrimento fra pagine — il pager è un `TabView`.
4. Aprire il tool giusto passandogli **quale** annotazione modificare: oggi
   `PdfSignatureViewModel` e `PdfFillFormViewModel` prendono il documento e
   scoprono da sé cosa c'è; serve un parametro in più.

⚠️ Nota per chi lo farà: `verticalCenteredTextBounds` restringe i bounds di 10
punti per lato (`CGRect.decode`), e su un testo corto l'area sensibile diventa
molto piccola. Vale la pena verificarla prima di dare la colpa alle coordinate.
