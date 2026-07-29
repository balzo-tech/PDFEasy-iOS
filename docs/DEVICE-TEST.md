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

- [ ] Creare cartelle e tag; assegnarli a un documento
- [ ] Menu contestuale del documento: i due sottomenu su schermo piccolo
- [ ] **Ricerca per nome file** e **ricerca dentro il testo** di un PDF
- [ ] Un PDF vecchio, mai ri-salvato né OCR, si trova **solo per nome**
- [ ] Eliminare una cartella: i documenti restano e tornano fra i non archiviati
- [ ] Dopo OCR / redazione / annotazioni il documento **conserva cartella e tag**
- [ ] Sync iCloud: il documento appare sull'altro dispositivo
- [ ] Due cartelle con lo stesso nome create su due dispositivi **si fondono in
      una** (dedup attivo da `8055367`): sopravvive la più vecchia per data di
      creazione e si porta dietro i documenti di entrambe. Vale anche per «Lavoro»
      contro «lavoro » — maiuscole e spazi non fanno due cartelle. Idem per i tag,
      che però vengono *condivisi* invece che spostati.

> Le due righe qui sopra vogliono un **secondo dispositivo**. Senza iPad, va bene
> un simulatore con la build Staging e lo **stesso account iCloud**: il container
> è unico e in Development entrambi ci parlano.

## 4. Scanner — la parte più scoperta

- [ ] Il **contorno sta sulla pagina**, non accanto
- [ ] Lo **scatto automatico** parte quando il telefono si ferma, non prima
- [ ] Dopo uno scatto non rifà la stessa pagina
- [ ] Flash sulla carta, pinch per lo zoom, tap per la messa a fuoco
- [ ] Ritaglio: maniglie con la lente, il crop combacia con i pixel raddrizzati
- [ ] Filtro «Documento» leggibile
- [ ] Filtro **«Bianco e nero» su pagina in penombra** (il caso critico: le matite
      chiare non devono sparire)
- [ ] «Salva come PDF» → il documento compare nella **tab Scanner**
- [ ] «Salva come immagini» → chiede il permesso *solo aggiunta*, le pagine arrivano in Foto
- [ ] iPad in orizzontale: la pagina esce dritta

## 5. Editor su una scansione lunga — la prova che conta

Con la scansione di 20+ pagine:

- [ ] Si apre **subito**, con «Preparazione delle pagine…» e le pagine che arrivano
- [ ] Applicare uno strumento **non congela** l'editor
- [ ] Riordinare e cancellare pagine; la barra sotto la pagina si **riaccende**
- [ ] **Sfogliarla da capo a fondo**: la pagina resta nitida (al massimo un istante
      di miniatura sfocata)
- [ ] La memoria non sale sfogliando (Instruments, se puoi)
- [ ] Trascinare una miniatura di **più posti in un colpo solo** nella striscia
- [ ] **Ruotare mentre le pagine si stanno ancora disegnando**: si vede la pagina ruotata
- [ ] Tasto **indietro** funziona in ogni momento

---

## 6. I 36 strumenti, uno per uno

### Creare

- [ ] **Scan** — vedi sezione 4
- [ ] **Image to PDF** — più foto insieme → una pagina per foto
- [ ] **Word to PDF** — `.doc/.docx`, guarda il risultato
- [ ] **Excel to PDF** — `.xls/.xlsx`
- [ ] **Powerpoint to PDF** — `.ppt/.pptx`
- [ ] **Web page to PDF** — una pagina normale e **una dietro cookie banner**
- [ ] **Markdown to PDF** — formattazione rispettata
- [ ] **Create PDF** — documento vuoto
- [ ] **Import PDF** — da File

### Organizzare

- [ ] **Merge PDF** — ordine dei file rispettato
- [ ] **Split PDF** — e su un PDF di **una sola pagina** deve dire l'errore, non aprire nulla
- [ ] **Extract pages** — idem sul PDF di una pagina
- [ ] **Rotate PDF** — una pagina e **tutte**; anche dalla tab Strumenti su file vero
- [ ] **Remove blank pages**
- [ ] **Compare PDFs** — due versioni dello stesso contratto: allineamento con una
      pagina inserita o rimossa; **due scansioni** senza testo; modalità Visivo e
      «tieni premuto per vedere l'originale»
- [ ] **Compress PDF** — i tre preset su una scansione lunga (tempo, memoria, resa);
      un documento di solo testo deve dire «già compresso» e tenere Salva spento

### Modificare

- [ ] **Sign PDF** — firma disegnata, da immagine, da fotocamera; **in tema chiaro**
      la firma resta nera su foglio bianco
- [ ] **Fill in a form** — su un PDF con campi veri
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
- [ ] **Unlock PDF** — con password nota; e su un PDF **senza** password → «già sbloccato»
- [ ] **PDF permissions** — limita stampa e copia; uscendo a metà e rientrando il
      campo password dev'essere **vuoto**
- [ ] **Redact PDF** — i box nella posizione giusta su pagine **ruotate** e a vari zoom;
      il contenuto sotto non è più recuperabile

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
