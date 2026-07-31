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
- [x] **Image to PDF** — più foto insieme → una pagina per foto: **passata** il
      2026-07-31 (`image_to_pdf.pdf`), tre foto → tre pagine, nessuna bianca, e
      l'ordine è quello dei tocchi (selezionate 3-2-1, uscite 3-2-1).
      **Non se ne poteva scegliere più di una**: il picker chiedeva un solo
      `PhotosPickerItem`. Ora ne prende fino a 50, e le pagine si costruiscono
      mentre le foto arrivano — cinquanta scatti a piena risoluzione insieme non
      ci stanno in memoria.
      La fotocamera resta una foto per volta: per fare più pagine con la
      fotocamera c'è lo scanner, che è la funzione fatta apposta.
      ⚠️ Le foto entrano in pagina a ~72 dpi (una da 1400 px esce 595 px di
      larghezza): misurato, e **lasciato così** — decisione del 2026-07-31
- [x] **Word to PDF** — `.doc` provato (`relazione-vecchio-formato.pdf`): titoli,
      grassetto, corsivo, elenco puntato e numerato, tabella con i bordi, tutto reso
      e selezionabile. L'interruzione di pagina non è stata rispettata, ma il salto
      l'ha perso `textutil` scrivendo il `.doc`, non l'app.
      Il **`.docx`** non si poteva nemmeno scegliere: il picker chiedeva
      `com.microsoft.word.doc`, che è **Word 97**, e `.docx` è un tipo a sé che non
      vi conforma. Corretto il 2026-07-31 con un test che tiene insieme le due
      liste, e riprovato dal picker: funziona
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
- [x] Una pagina **dietro cookie banner** — provata il 2026-07-31: esce la pagina,
      non il muro del consenso
- [x] **Markdown to PDF** — `guida.pdf`: intestazioni, elenchi puntati e numerati,
      grassetto, corsivo, codice inline e a blocco, citazione in corsivo — tutto
      corretto. La tabella esce scomposta, che è il comportamento previsto
- [x] **Create PDF** — documento vuoto: funziona (2026-07-31)
- [x] **Import PDF** — da File: funziona (2026-07-31)
- [x] **Da un'altra app, condividendo** — un `.docx` da File: «Copia su PDF Pro»
      compare, il file arriva, si converte e si apre. Prima non compariva per
      niente che non fosse un PDF (`relazione 2.pdf`)
- [x] **Da un'altra app, «Apri con»** — la voce del menu contestuale di File
      mancava (`LSSupportsOpeningDocumentsInPlace`): aggiunta e funzionante
- [x] **Nuovo ▸ Converti da qualsiasi file** — la guida in tre passi, rifatta il
      2026-07-31: in italiano e funzionante. In simulatore si riapre con
      `xcrun simctl spawn booted defaults write <bundle-id> debugImportTutorial -int 0..2`

### Organizzare

- [x] **Merge PDF** — tre documenti, 16 pagine, ordine rispettato.
      ⚠️ Ha reso due difetti, corretti il 2026-07-31: nell'editor **la pagina non
      era centrata** (un `GeometryReader` appoggia il figlio in alto a sinistra), e
      con essa era fuori bersaglio il **tocco per modificare una firma o un testo**,
      che invece calcola la posizione come se la pagina fosse centrata
- [x] **Split PDF** — su `una-pagina.pdf` dice l'errore e non apre niente
- [x] **Extract pages** — idem sul PDF di una pagina
- [x] **Rotate PDF** — una pagina e tutte, su `ruotato.pdf`
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
- [x] Confronto fra **due scansioni** senza testo — provato il 2026-07-31 con
      `scansione-contratto-v1.pdf` (3 pagine) e `-v2.pdf` (4), i due contratti
      rasterizzati: nessun testo da estrarre, e infatti cade sull'allineamento
      posizionale («È cambiata solo l'impaginazione: vedi la scheda Visivo») invece
      di dire che i documenti sono vuoti, e riconosce la 4ª pagina come esistente
      solo nella versione modificata (`scansione_confronto.png`).
      Resta da provare «tieni premuto per vedere l'originale»
- [x] **Compress PDF** — funziona
- [x] I tre preset su una **scansione lunga** — provati tutti e tre il 2026-07-31 su
      `scansione-lunga.pdf` (12 pagine immagine a 300 dpi, 13,5 MB) e vanno bene.
      Misurato quello consegnato: **1,4 MB**, 12 pagine, JPEG a 94 dpi — un decimo
      del peso, testo ancora leggibile
- [x] Il documento **già compresso** deve dirlo e tenere Salva spento — verificato
      il 2026-07-31 in simulatore (`LocalisationUITests`, screenshot
      `compressione-es`): «151 KB → 151 KB, Este documento ya está comprimido todo
      lo posible», Guardar spento

### Modificare

- [x] **Sign PDF** — firma disegnata, inserita e salvata (`relazione 2_firmata.pdf`):
      resta un'annotazione, quindi si può riaprire e correggere
- [x] **Firma da immagine e da fotocamera** — provata sul device il 2026-07-31:
      entrambe arrivano nell'anteprima e Conferma le prende.
      Ci sono voluti due giri. Prima il ritaglio non si apriva affatto (`6a8f706`):
      è un `fullScreenCover` chiesto mentre il picker che ha prodotto l'immagine si
      sta ancora chiudendo, e SwiftUI scarta una presentazione chiesta lì —
      lasciando per giunta il flag a `true`, cioè il flusso morto per sempre.
      Poi il ritaglio si apriva ma il risultato non tornava: l'immagine croppata
      rientrava attraverso lo **stesso** `image` da cui era entrata e veniva
      consegnata dal suo `didSet`, mentre l'`onDisappear` del cover correva a
      buttare via la callback — chi dei due arrivasse prima lo decideva SwiftUI.
      Ora Mantis dice al flow cosa è successo (`onCropConfirmed` / `onCropCancelled`)
      e il flow chiude il cover: nessun binding in mezzo, nessun ordine da
      indovinare. Se una presentazione viene scartata lo stesso, il cover non
      compare mai e il flow la richiede (8 test)
- [x] La firma in **tema chiaro** — verificata in simulatore il 2026-07-31
      (`LocalisationUITests`, screenshot `firma-tema-chiaro`): con l'app in «Sempre
      chiaro», un tratto disegnato davvero sulla tela esce **nero su foglio
      bianco** e Conferma si accende. Il foglio dipinge il proprio sfondo, quindi
      l'inchiostro non può finire nero su nero
- [x] **Fill in a form** — `modulo.pdf`, quattro campi e una casella: i valori
      digitati sono nel PDF salvato e si vedono nel file esportato, casella
      compresa
- [x] **Add text** — rifatto il 2026-07-31 e approvato: sotto la pagina c'è la
      barra con **colori, carattere, A− / A+ e cestino** al posto del contatore
      (salito sulla pagina come pastiglia), e il riquadro segue lo stile dell'app.
      A− / A+ scalano il riquadro, perché il carattere viene ingrandito per
      riempirlo: il riquadro *è* la dimensione.
      Prima erano emersi: la barra sopra la tastiera vuota (conteneva solo le
      parole suggerite) e invisibile su PDF a fondo nero, e un riquadro in basso
      irraggiungibile sotto la tastiera — «Fatto» sulla barra la chiude e
      restituisce la pagina
- [x] **Make Searchable (OCR)** — funziona. ⚠️ Da provare su un documento fatto di
      **immagini**: un PDF creato al computer ha già il testo e l'app risponde
      giustamente che è già ricercabile. In cartella c'è `finta-scansione.pdf`,
      che di testo non ne ha
- [x] **Page numbers** — provati da soli: funzionano. In `contratto-v1-punto5.pdf`
      non ce n'era traccia, ma il tool non c'entrava: non erano stati applicati.
      Restano due test scritti per quel sospetto (`306f877`), che coprono i numeri
      prima e dopo l'inversione dei colori
- [x] **Watermark** — «Balzo» in diagonale su tutte le pagine di
      `contratto-v1-punto5.pdf`, e il testo del documento resta selezionabile.
      Dal 2026-07-31 la filigrana finisce su una **copia**
      (`nome-watermarked`) e il documento aperto resta pulito, con l'alert che lo
      dice. Prima sostituiva il documento, e non c'è modo di togliere una filigrana:
      è disegnata *dentro* la pagina, non appoggiata sopra come annotazione (è ciò
      che tiene il testo selezionabile). Da riprovare
- [x] **Invert colors** — su `contratto-v1-punto5.pdf`: sfondo nero e testo bianco
      su tutte le pagine. Applicato **dopo** la filigrana, che infatti risulta
      grigia su nero: l'ordine conta
- [x] **Flatten PDF** — `relazione 2_firmata.pdf` è passato da **1 annotazione a 0**
      con la firma ancora al suo posto e il testo ancora selezionabile

- [x] **Il pannello Strumenti dell'editor** — la barra in cima aveva una fascia
      verdognola dietro «Strumenti» e «Fatto»: lo sfondo della sheet si fermava alla
      lista, così la barra faceva da vetro sull'**editor sottostante**. Corretto e
      **verificato sul device**
- [x] **Il menu che si apre dal basso** (Strumenti ▸ Firma PDF, Aggiungi testo o
      Rendi ricercabile → «File / Scansiona»): lo sfondo è a posto
- [x] Lo stesso menu **nella lingua del telefono** — verificato in simulatore il
      2026-07-31 (screenshot `importa-da-it`): «Importa da», «File», «Scansiona un
      documento». Era in inglese ovunque, erano `String` semplici (`2bd614d`)

### Proteggere

- [x] **Protect PDF** — `una-pagina_protetto.pdf`: risulta cifrato e si apre solo
      con la password
- [x] Proteggere un PDF **già protetto** → errore corretto
- [x] **Unlock PDF** — `protetto-prova1234.pdf` (password `prova1234`) si sblocca
- [x] Su un PDF **senza** password → messaggio in italiano, «già sbloccato»
- [ ] **PDF permissions** — scrivi la password (senza, la conferma resta spenta),
      spegni «Consenti stampa» e «Consenti copia», conferma; poi apri il file in
      Anteprima sul Mac e verifica che stampa e selezione siano bloccate.
      Il pezzo sulla sicurezza: riapri il tool, **scrivi qualcosa nel campo
      password**, esci a metà, rientra — il campo dev'essere **vuoto**.
      ✅ Che i due interruttori tornino accesi riaprendo è corretto: il form riparte
      da «tutto permesso»
- [x] **Redact PDF** («Oscura PDF», in Proteggi) — provato su `ruotato.pdf`, una
      banda per pagina a 90°, 180°, 270° e 0°: **tutte e quattro cadono dove
      servono**, e i cinque dati finti non sono più estraibili dal file
      (`ruotato-redacted.pdf`). Le pagine oscurate diventano immagini e le
      rotazioni risultano azzerate: è la conseguenza normale del rendering, il
      contenuto si vede con lo stesso orientamento di prima.
      ⚠️ Ci è voluto un fix: la banda nera **non seguiva il dito**, perché la pagina
      era spinta contro il bordo inferiore da un doppio centraggio (un `.offset`
      non muove il layout, quindi il frame la ricentrava sopra all'offset che già
      centrava) e ogni box cadeva mezzo spazio vuoto più in là (`3a2c4b3`).
      ⚠️ Da sapere per l'uso: la garanzia sta nella **conversione in immagine**, non
      nel box. Un frammento di lettera lasciato scoperto al bordo della banda non
      è estraibile ma resta **visibile** — conviene trascinare più larghi del testo

### Esportare e leggere

- [x] **Export PDF as…** — testo (29.276 caratteri, contenuto giusto) e immagini
      (12 JPG + 12 PNG) da `solo-testo-12-pagine.pdf`
- [ ] Esportare le **foto incorporate**: quel documento non ne ha, per questo diceva
      che non ce n'erano. Usa `con-immagini.pdf`, che ne porta tre vere
- [x] **Read PDF** — `leggi_pdf.pdf`: due pagine e **7 annotazioni** salvate

### Solo con il servizio online acceso

Se il servizio è spento questi sei **non devono comparire** nel catalogo.

- [x] **Repair PDF** — su `danneggiato.pdf` (troncato, PDFKit non lo apriva):
      riparato. Prova anche che il giro completo del proxy funziona dal telefono
- [x] **Sanitize PDF** — passata il 2026-07-31 su `con-javascript.pdf`: nel file
      che torna, `JavaScript`, `EmbeddedFile` e `note.txt` sono a **zero**, il link
      e il testo sono ancora al loro posto. È quello che il tile promette.
      ⚠️ L'errore visto prima **non era un difetto**: era il debug token di App
      Check, che cambia a ogni reinstallazione. Se uno degli strumenti online
      risponde con un errore, quello è il primo posto da guardare
- [x] **PDF to Word** — passata il 2026-07-31 (`relazione 2.docx`): OOXML valido,
      testo completo. **Era rotto davvero**: senza il campo `outputFormat` Stirling
      risponde **400**. Misurato contro l'istanza locale
      (`docker run -p 8081:8080 stirlingtools/stirling-pdf`, nessuna chiave):
      senza il campo 400, con `outputFormat=docx` 200. Corretto in
      `StirlingOperation.formFields`
- [x] **PDF to PowerPoint** — passata (`piano-commerciale.pptx`): 3 pagine → 3
      slide, testo dentro. Stessa causa e stessa correzione di PDF to Word
- [x] **PDF to Excel** — funziona (2026-07-31): `tabella-materiali.csv`.
      Esce un **CSV**, non un `.xlsx` — è quello che l'endpoint di Stirling
      produce (`/api/v1/convert/pdf/csv`). **Deciso il 2026-07-31: va bene così**,
      il CSV si apre in Excel e in Numbers.
      Nel CSV di prova le colonne risultano attaccate, ma **è il file di partenza**:
      `tabella-materiali.pdf` disegna le celle come testo posizionato senza
      struttura di tabella. Con `fatture.pdf`, che nasce da un foglio vero, la
      stessa chiamata rende `"Numero","Cliente","Imponibile",…` — verificato in
      locale
- [ ] **PDF/A** — l'ultima dei cinque online. Senza `outputFormat` risponde
      comunque 200, ma il formato lo sceglierebbe il server: ora l'app chiede
      `pdfa`. Verifica: `strings out.pdf | grep -i pdfaid`
      ⚠️ La lista dei campi si legge da `curl https://api.stirling.com/v1/api-docs`;
      **quali siano davvero imposti** si scopre solo chiedendo all'istanza locale,
      perché la dichiarazione «required» dello schema e il comportamento a runtime
      non coincidono (cinque dichiarati, due imposti)
- [ ] Il prompt di passaggio al servizio online è **esplicito**, mai silenzioso

---

## 7. Chat sul documento

- [x] Il documento viene letto e riassunto — provato il 2026-07-31 con
      `chat-verbale.pdf` (`chat_verbale.png`): riassunto corretto in italiano
      (Elena Bianchi, utile 87.450, assemblea del 12 settembre 2026), tre domande
      suggerite in vista, contatore a «20 messaggi rimasti»
- [x] Le **domande suggerite** si premono e rispondono correttamente (2026-07-31)
- [x] Il **grassetto, il corsivo e gli elenchi** si vedono formattati, non con gli
      asterischi
- [x] Un messaggio di **soli spazi** non parte: l'invio resta inerte
- [x] Il **contatore mensile scende**. Resta da vedere una sola volta cosa dice a
      quota zero — non vale un giro di venti messaggi, si guarda quando capita
- [x] Un documento **più lungo di quanto la chat possa leggere** — provato con
      `chat-lungo.pdf` (17 pagine, ~70.000 caratteri contro i 60.000 che l'app
      manda): alla domanda sulla parola di controllo, che sta nell'ultima pagina,
      risponde che non la trova. È il comportamento giusto — non se l'è inventata.
      ⚠️ Riga riscritta: **non esiste più un limite che dia errore**. Da quando il
      testo si estrae sul telefono, oltre `K.ChatPdf.DocumentCharacterBudget` viene
      troncato e al modello si dice che ha solo l'inizio

## 8. Uscire dal documento (il paywall all'uscita)

- [x] Da **non premium**: condividere/esportare/stampare fa comparire il paywall
- [x] Dopo l'acquisto l'operazione **riprende da sola** — provato il 2026-07-31
- [x] Il file condiviso è **identico** a quello salvato (stessa dimensione), sia
      dall'editor sia dall'archivio
- [x] Un documento protetto esce protetto

## 9. Widget, Siri, Scorciatoie

Provata tutta il 2026-07-31, nessun difetto.

- [x] Entrambi i widget in tutte le taglie sulla schermata Home
- [x] Le frasi Siri — sono **sette**, non cinque: scansiona un documento, mostra le
      mie scansioni, crea un PDF scansionato, apri i miei documenti, unisci PDF,
      rimuovi le pagine vuote, apri uno strumento (`PdfExpertShortcuts`)
- [x] Azioni Scorciatoie su file veri, comprese quelle che girano **senza aprire
      l'app** (merge, rotate, remove blank pages)
- [x] L'azione premium (extract text) da non premium → errore, **non** un paywall:
      una scorciatoia può girare a telefono bloccato, dove un paywall non lo
      vedrebbe nessuno
- [x] Deeplink `pdfprostaging://`

## 10. Casi d'errore, in italiano e in spagnolo

> Le righe di questa sezione sono state **provate in simulatore** il 2026-07-31,
> non a mano: `PdfExpertUITests/LocalisationUITests` (6 test) le percorre in
> italiano e in spagnolo e allega gli screenshot al result bundle. Restano a mano
> le due che vogliono hardware o la libreria foto.

- [x] **Tema dell'app** (Impostazioni ▸ Aspetto): con «Sempre chiaro» l'editor è
      chiaro, e lo è ancora dopo che l'app è stata uccisa e riaperta — screenshot
      `editor-tema-chiaro`. Il tema sta in `@AppStorage`, applicato alla radice,
      quindi arriva anche a sheet e cover
- [x] Foglio firma: i tre tab dicono «Disegno / Da immagine / Da fotocamera»
      (screenshot `foglio-firma-it`), il titolo «Tocca dove vuoi firmare», e il
      bottone «Conferma»
- [ ] Negare l'accesso alla fotocamera in Impostazioni e riprovare
- [ ] Importare una foto illeggibile — usa **`foto-corrotta.jpg`**: header e
      dimensioni validi (1400×1050, quindi compare nel picker e ha la miniatura) e
      dati di scansione mescolati. `foto-illeggibile.jpg` non serve: non essendo
      un'immagine, la libreria Foto non la importa nemmeno e il picker non la
      mostra — quello è il filtro di sistema, non l'app. Prova da **entrambe** le
      porte, galleria e File
- [x] Etichette lunghe in spagnolo: **preset di compressione** («Ligera /
      Equilibrada / Máxima» con i sottotitoli) e **paywall** («Desbloquea todas las
      herramientas», «Pruébalo ahora gratis», «Ahorra 83 %») — screenshot
      `compressione-es` e `paywall-es`, niente tagliato
- [x] Numeri nelle frasi tradotte: «1 di 3» sul contatore pagine e «Benvenuto in
      PDF Pro» all'avvio — i due posti dove l'ordine degli argomenti si rompe
      ⚠️ **Quattro bottoni erano inglesi in ogni lingua** e nessuno se n'era
      accorto: «Finish» (firma, compila modulo, aggiungi testo, campi suggeriti),
      «Retry», «Confirm», «Send Feedback». La causa è la stessa di sempre —
      `PrimaryActionButton` riceve una `String` e `Text(String)` non localizza.
      Corretti passando da `String(localized:)`; «Finish» e «Send Feedback» non
      erano nemmeno nel catalogo, ora ci sono in tre lingue

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
