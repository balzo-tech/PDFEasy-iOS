# Trappole: prezzi, App Store Connect, metadata, review

Leggilo prima di toccare prezzi, offerte/prove, testi dello store, app info, invio in review o prodotti IAP (script in `fastlane/scripts/`, lane `metadata*` in `fastlane/Fastfile`, `pdfexpert/Resources/IAP/`).

Credenziali: `fastlane/.env` (git-ignorato; vedi `fastlane/.env.example`) con `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_FILEPATH`. La chiave ha ruolo **App Manager**: legge e scrive i metadati, ma non basta per tutto (vedi trappola 7).

## Rete e API

1. **L'API di Apple cade a intermittenza.**
   - Sintomo: `SSL_connect ... unexpected eof while reading` verso `api.appstoreconnect.apple.com` o il transporter; da Python (`urllib`) le connessioni restano appese per minuti.
   - Causa: la rete di questa macchina (VPN con tunnel `utun`, MTU basso). Non è una credenziale né uno script.
   - Fai: riprova. `fastlane/scripts/asc.py` ritenta 4 volte il solo trasporto. Per il binario usa `bundle exec fastlane upload_ipa` (carica l'`PdfExpert.ipa` già costruito senza riarchiviare). In shell `curl -4 --connect-timeout 40` con tentativi ripetuti passa.
2. **`POST /v1/profiles` e altre scritture rispondono 500 `UNEXPECTED_ERROR` a caso.** Riprova dopo qualche secondo, anche cambiando nome. Le 500 di ASC arrivano a raffiche.

## Prezzi e offerte (API ASC)

3. **Per lo stesso territorio ci sono più righe di prezzo.**
   - Sintomo: leggi 399 MXN dove il listino dice 1.299.
   - Causa: `GET /v1/subscriptions/{id}/prices?include=subscriptionPricePoint,territory` restituisce anche i prezzi `preserved: true` (congelati per gli abbonati vecchi).
   - Fai: vale **l'ultima riga con `preserved: false`**, non la prima. Inoltre `customerPrice` arriva come `"699.0"`, non `"699.00"`: non confrontare stringhe.
4. **`startDate: null` su `POST /v1/subscriptionPrices` = «prezzo iniziale».**
   - Sintomo: 409 `STATE_ERROR` «Initial price cannot be created again after subscription is approved».
   - Fai: serve sempre una data; **domani va bene** per un prezzo (a differenza di `endDate` di un'offerta, trappola 5). Il prezzo di un abbonamento parte dal giorno dato; quello di un **consumabile** è immediato, quindi per qualche ora due prodotti correlati possono avere listini incoerenti.
5. **Le offerte introduttive (prova gratuita) hanno vincoli rigidi.**
   - La `duration` non si modifica: `PATCH` risponde 409 `ENTITY_ERROR.ATTRIBUTE.NOT_ALLOWED`. Si chiude la vecchia (PATCH `endDate`) e se ne crea una nuova.
   - `endDate` non può essere oggi («cannot be past»): il primo giorno ammesso è domani, la nuova può partire dopodomani. Un cambio durata non è mai immediato e per un giorno intero **nessun territorio ha la prova**.
   - Due offerte sullo stesso territorio non si sovrappongono: prima PATCH `endDate` sulla vecchia, poi POST della nuova (altrimenti 409 con le due `DateRange`).
   - 175 territori, due chiamate ciascuno; con due script in parallelo l'API rallenta molto. Gli script devono essere idempotenti.
6. **Cambiare prezzo e offerta dello stesso prodotto nello stesso giorno può far sparire la prova di un territorio in silenzio.**
   - Sintomo: in un paese il paywall chiede il prezzo pieno subito, nessuna prova parte; lo script stampa «174 territori» senza dire quale manca (caso reale: ZAF).
   - Causa: la ricreazione dell'offerta fallisce e uno script che itera sui territori *che hanno* un'offerta non lo ritocca più.
   - Fai: mai toccare prezzo e offerta dello stesso prodotto nella stessa giornata. Dopo ogni modifica al listino rileggi i due insiemi e confrontali (`territori_con_prezzo - territori_con_offerta` deve essere vuoto) invece di fidarti del conteggio. Le offerte si leggono da `GET /v1/subscriptions/{id}/introductoryOffers`.
7. **Togliere la disponibilità di un abbonamento già in vendita da un paese non si può con la chiave API.**
   - Sintomo: `POST /v1/subscriptionAvailabilities` senza il territorio -> 409 `INVALID_REQUEST_SUBSCRIPTION_AVAILABILITY_REMOVAL_NOT_ALLOWED` («Only account holder can remove availability»).
   - Causa: ruolo App Manager insufficiente. Aggiungere territori invece passa.
   - Fai: lo fa solo l'Account Holder. Alternativa tecnica: cancellare l'offerta introduttiva di quel territorio (toglie solo la prova lì).
8. **La base di un listino nuovo decide il prezzo in tutto il mondo.**
   - Sintomo: nel simulatore USA il pass a 24 ore costava come il settimanale ($1.99 e $1.99).
   - Causa: prezzato sul price point del mercato più economico (ZAF) con equalizzazione automatica sugli altri 174 territori.
   - Fai: la base va sul **listino principale (ITA)**; poi rileggi i prezzi nei territori in cui il prodotto si mostra davvero. Per un consumabile: `/v2/inAppPurchases/{id}/pricePoints?filter[territory]=ITA`, `POST inAppPurchasePriceSchedules` (`baseTerritory` + `manualPrices`; si può ripetere senza cancellare il precedente), `.../automaticPrices` per leggere cosa ha calcolato Apple.
9. **`preserveCurrentPrice` decide se il cambio tocca gli abbonati esistenti.** `True` li lascia al vecchio prezzo (obbligatorio per un rincaro: altrimenti Apple chiede consenso a ciascuno e chi non risponde scade); `False` solo per un ribasso o se non ci sono abbonati.
10. **I prodotti venduti sono pochi e con prezzi scollegati.** Il paywall vende `eu.balzo.pdfexpert.yearly.freetrial` (non `...yearly`, fermo a 19,99 €), `weekly`, e il consumabile `eu.balzo.pdfexpert.daypass`. Il mensile è `offered: false` dalla 1.35. Si tocca solo ciò che il paywall vende. Quali piani appaiono lo decide `pdfexpert/Resources/IAP/Products.plist` (`offered: true/false`), che sta nel bundle e richiede una build; prezzo e durata della prova no (li legge StoreKit in `pdfexpert/InternalUtils/SubscriptionViewUtility.swift`; le stringhe «7 days» in `SubscriptionPlanCardView.swift` sono solo preview).
11. **Il netto non è sempre l'85%.** In Sudafrica c'è il 15% di IVA prima della commissione: 89,99 ZAR danno 66,51 ZAR (~74%).

## StoreKit e prodotti in simulatore

12. **Il paywall legge i prodotti da App Store Connect, non dai `.storekit` del repo.**
   - Sintomo: modifichi un `.storekit` e il prezzo non cambia; un prodotto nuovo non compare.
   - Causa: i file in `pdfexpert/Resources/IAP/` non sono la sorgente a runtime. Un prodotto compare solo dopo averlo creato su ASC (con qualche minuto di propagazione), e può arrivare senza la sua introductory offer se l'offerta è stata configurata dopo.
   - Fai: per provare un prodotto nuovo deve esistere su ASC almeno in `READY_TO_SUBMIT`. Gli UI test vedono solo i prodotti ASC: le reference `.storekit` nello scheme (TestAction o LaunchAction) e `SKTestSession` dentro un UI test non funzionano (`SKTestSession` funziona in un unit test).
13. **Un IAP nuovo è `MISSING_METADATA` finché non ha la screenshot di revisione, e StoreKit non lo serve.** Esci dal cerchio caricando una screenshot provvisoria qualunque (il prodotto passa a `READY_TO_SUBMIT`, propagazione immediata), poi rifai la foto col prodotto dentro e sostituisci. Dopo una revisione la screenshot di un IAP è bloccata (`MEDIA_ASSET_DELETE_NOT_ALLOWED`, `INVALID.UNMODIFIABLE`): si cambia solo dal sito.
14. **Con Run da Xcode gli acquisti sono simulati anche se i prezzi vengono da ASC.** Lo scheme `PdfExpert Staging` referenzia `LocalStagingProducts.storekit` nel LaunchAction: una transazione così ha `originalID` da 0 e il proxy la rifiuta con `402 no_subscription`. Per provare il proxy: Edit Scheme > Run > Options > StoreKit Configuration > None e Account sandbox. In staging il product id ha `.staging.` in mezzo e serve un IAP separato sull'app `eu.balzo.pdfexpert.staging`.

## Metadata, deliver, app info

15. **`deliver` può rinominare la versione in 1.0.0 con una riga di successo.**
   - Causa: senza `app_version` deliver ricava il numero dall'.ipa in root o da `get_version_number`, che qui risponde `1.0.0` (la versione sta in `MARKETING_VERSION`, non c'è Info.plist su disco). Poi stampa «Successfully set the version to '1.0.0'».
   - Fai: il numero giusto viene da `xcodebuild -showBuildSettings ... | MARKETING_VERSION`; nel `Fastfile` c'è il metodo `marketing_version`, usato dalle lane che scrivono metadati. Se è già successo: `PATCH /v1/appStoreVersions/{id}` con `attributes.versionString`. Verifica sempre il nome della versione su ASC dopo un `metadata`.
16. **`fastlane metadata` fallisce se una versione qualsiasi è in review (app info congelata).**
   - Sintomo: dieci minuti di «Cannot find edit app info... Retrying» e poi errore, che si porta dietro anche descrizione, keyword e note (che non erano bloccate).
   - Causa: `deliver` chiede l'app info (nome e sottotitolo, condivisi tra piattaforme) prima di scrivere; è congelata finché una versione (anche Mac) è in review. Togliere `name.txt`/`subtitle.txt` non serve.
   - Fai: prima di una lane di metadati guarda se c'è una versione in review; se c'è usa `fastlane/scripts/` (`push_texts.py`, `push_screenshots.py`, `create_event.py`, `submit_review.py`; vedi `fastlane/scripts/README.md`). Es.: `PYTHONPATH=fastlane/scripts python3 fastlane/scripts/push_texts.py 1.36`.
17. **Configurazione del `Deliverfile` che non va toccata alla leggera.**
   - `run_precheck_before_submit(false)`: precheck non sa leggere gli IAP con chiave API; senza, la lane carica tutto e poi fallisce.
   - `overwrite_screenshots(false)`: gli screenshot si sommano (limite 10 per slot). Per sostituire un set già online va svuotato prima su ASC. Per i soli testi: `DELIVER_SKIP_SCREENSHOTS=true bundle exec fastlane metadata`.
   - `metadata_check` / `metadata_mac_check` leggono i file e riportano le dimensioni senza contattare Apple.
18. **Cartella locale sbagliata = deliver non scrive niente e non lo dice.** Lo spagnolo del Messico è `es-MX` (non `es-ES`). Una lingua senza file viene lasciata com'è, non svuotata. Testi in `fastlane/metadata/<locale>/{description,release_notes,promotional_text}.txt`, Mac in `fastlane/metadata-mac/`. Il testo promozionale è l'unico campo modificabile senza nuova versione.
19. **Pagina Mac (Universal Purchase): arriva vuota e ha regole sue.** Le note di rilascio non si scrivono sulla prima versione di una piattaforma (409 `STATE_ERROR`); `app_version` non crea una versione che non esiste (la pagina nasce 1.0: vai con `PATCH /v1/appStoreVersions/{id}`); `get_version_number` senza `configuration` si ferma a chiedere e in una lane non interattiva è un crash.
20. **`nome` e `sottotitolo` stanno nell'`appInfo`, e ce ne sono due.** Uno `READY_FOR_SALE` (live) e uno `PREPARE_FOR_SUBMISSION`: leggendo il primo sembra che il caricamento non sia riuscito. Il sottotitolo va scritto sull'app info modificabile; `push_texts.py` non lo tocca.
21. **Una lingua nuova della scheda si decide prima di sottomettere.** Con una versione in review: `POST /v1/appStoreVersions` -> 409 e `POST /v1/appStoreVersionLocalizations` -> 409 «Cannot create localization after the app version has been submitted». Le locale esistenti si modificano. Per creare una localizzazione serve `supportUrl` (`push_texts.py` lo copia da una locale sorella). Aggiungere una lingua all'app info la rende **obbligatoria sulla versione**: servono `privacyPolicyUrl` sull'app info e descrizione, keyword, novità e `supportUrl` sulla localizzazione (gli screenshot ereditano dalla lingua principale).
22. **Guideline 2.3.7: mai prezzo o «gratis»/«kostenlos»/«gratuit» in nome e sottotitolo** (rifiuto della 1.35). Semmai nella descrizione. Nome e sottotitolo non si cambiano senza richiesta esplicita dell'utente.
23. **Una lingua nuova o screenshot parziali.** Una cartella `fastlane/screenshots/<lang>/` con soli iPhone toglie l'ereditarietà da `en-US` e lascia la lingua senza iPad: una versione senza iPad non si sottomette. Crea la cartella solo con il set completo.

## Review, upload, invio

24. **`upload_ipa` carica ma non collega la build alla versione.** Serve `PATCH /v1/appStoreVersions/{id}/relationships/build` con l'id della build, altrimenti la versione sembra pronta e non è inviabile.
25. **Un IAP nuovo va in review insieme alla versione che lo introduce.** Se lo dimentichi resta `READY_TO_SUBMIT` per sempre e il paywall di quel mercato torna in silenzio ai piani precedenti. `fastlane/scripts/submit_review.py <versione>` (con `--dry-run`) allega ogni IAP `READY_TO_SUBMIT`.
26. **Dopo un rifiuto reinvia la submission rifiutata, non una nuova.** PATCH `submitted: true` sulla submission rifiutata (contiene già versione e acquisti). `submit_review.py` ne apre una nuova che resta vuota e non si può annullare. Dopo una modifica ai metadati Apple risponde «Version is not ready to be submitted yet» per un paio di minuti: riprova.
27. **Le firme degli SDK terzi le controlla Apple all'invio, non all'upload.**
   - Sintomo: `altool --validate-app`, upload e processing OK, ma la submission è respinta nello stesso minuto (`ITMS-91065`); su ASC si legge solo «Codice binario non valido». **Il motivo c'è solo nella mail di Apple: conservala.**
   - Causa: una dipendenza agganciata a un branch (Lottie `main` portava 4.2.0 senza firma dell'autore). Oggi Lottie è `exactVersion 4.6.1` e Firebase `10.29.0` (non salire a 11.x/12.x senza migrare: sparisce `FirebaseAnalyticsSwift`).
   - Fai: nessuna dipendenza su branch. Verifica: `codesign -dv --verbose=2 <path>/Lottie.xcframework` («Authority=...» o «not signed at all»); in `<archivio>.xcarchive/Signatures/` un file da ~2 KB col certificato è firmato, 452 byte no.
28. **Eventi in-app: li invia una persona, a versione pubblicata.** Evento e versione sono code di review separate; una card che promette uno strumento non ancora in vendita viene respinta. `fastlane/scripts/create_event.py` crea la bozza.
29. **Paywall: il numero più grande deve essere l'importo addebitato** (3.1.2(c)), non il prezzo a settimana; e un prodotto IAP deve essere trovabile dal revisore in ogni store (2.1(b)): il pass a 24 ore è in tutti i paesi.
