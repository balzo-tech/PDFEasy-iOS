# Trappole: SwiftUI, PDFKit, annotazioni, scanner, editor

Leggilo prima di toccare presentazioni (sheet/cover/alert), layout con `GeometryReader`, toolbar iOS 26, PDFKit (`PDFPage`, annotazioni), scanner/fotocamera, editor pagine.

## Presentazioni e vetro (iOS 26)

1. **Una presentazione chiesta mentre un'altra si chiude viene scartata, e il flag resta acceso.**
   - Sintomo: il flusso è bloccato per sempre (es. ritaglio firma da immagine, `ImageCropFlow`).
   - Fai: chiedi la presentazione quando lo schermo è libero (~0,45 s) **e** accorgiti se è stata scartata: il contenuto segnala con `onAppear`; il suo silenzio è l'unico segno onesto; a quel punto flag `false` e riprova. Un ritardo da solo è una gara persa ogni tanto. Vale anche per uno StoreKit sheet aperto dentro il callback di un alert che si smonta: avvia l'acquisto fuori dal callback.
2. **Il risultato non deve tornare dal canale da cui è entrato.** Un `@Binding` usato per andata e ritorno + chiusura nella stessa riga: l'ordine tra `didSet` e `onDisappear` lo decide SwiftUI e sul device decide male (ritaglio che torna vuoto). Rimedio: niente binding in mezzo; il rappresentabile dice cosa è successo (`onCrop`/`onCancel`), il flow consegna e chiude lui. Se un ordine non è garantito, toglilo di mezzo invece di renderlo probabile. Test: `PdfExpertTests/ImageCropFlowTests.swift`.
3. **Su iOS 26 una barra o sheet senza sfondo diventa vetro e prende il colore di ciò che ha dietro.**
   - Casi: barra del pannello Strumenti (`.toolbarBackground(ColorPalette.background, for: .navigationBar)` + `.visible`); barra sopra la tastiera di Aggiungi testo che spariva su PDF nero (sfondo esplicito `ColorPalette.surfaceElevated`); form sheet dal basso (`.presentationBackground(...)` sulla **sheet**, non sul contenuto: vedi `pdfexpert/Utils/UI/FormSheet.swift`).
4. **In una toolbar il colore si chiede allo stile, mai a uno sfondo proprio.** Un `.background(accent, in: .capsule)` sotto un bottone `.plain` finisce sotto il materiale (blob bianco). Usa `.buttonStyle(.glassProminent)` + `.tint(...)`.
5. **Bottoni sotto la tastiera in una sheet.** Il primo tocco chiude la tastiera e non arriva al bottone («premi due volte»). Metti i bottoni in `.safeAreaInset(edge: .bottom)`.
6. **Un bottone-icona senza `contentShape` è grande quanto il glifo.** `Button { Image(...).frame(44) }` con `.buttonStyle(.plain)` è un bersaglio di ~16 pt. Sintomi: «la X non chiude». `getSystemClose` (in `View+Extensions`, usata da `addSystemCloseButton`) ora è corretta; per nuovi bottoni aggiungi `contentShape`. Pattern da cercare: `.buttonStyle(.plain)` + `Image(systemName:` + `.frame(` senza `contentShape`.

## Layout e misure

7. **`GeometryReader` non centra: il figlio sta in alto a sinistra.** Se un calcolo di coordinate (es. `pointInPage` con `fittedRect`) presume il contenuto centrato, ogni tocco cade mezzo spazio libero più in su. Chiudi il `GeometryReader` con `.frame(width:height:)` + `contentShape(.rect)`.
8. **`.offset` non muove il layout.** Se il figlio è già posizionato con `.offset`, quel `.frame` non deve centrare (`alignment: .topLeading`), o il centraggio si applica due volte (nel tool di redazione la banda nera cadeva lontano dal dito). Senza device: uno screenshot; se i margini sopra e sotto la pagina non sono uguali, il disaccordo è lì (`-debugRunTool redact` + `-debugPremium`).
9. **Misure che si decidono dal verso sbagliato.** (a) `AsyncImage` + `scaledToFill` + `frame` che fissa solo l'altezza: è l'immagine a dettare la larghezza e `maxWidth: .infinity` dopo allarga ma non stringe. (b) `Color.clear.aspectRatio(1, contentMode: .fit)` in una griglia lazy: nessuna altezza proposta, `.fit` si risolve diversamente riga per riga. Regola: **la vista non deve avere opinioni sulla propria misura**; un `Color` puro accetta qualunque proposta e la misura la detta chi la usa, in un posto solo. (c) Testo centrato che esce dalla cornice: bloccare il centro non basta; impagina il blocco, misura l'altezza, blocca il **rettangolo**, con la stessa funzione per anteprima ed export (`ImageCanvasUtility.captionFrame`).

## PDFKit e annotazioni

10. **`PDFPage.copy()` restituisce una pagina che disegna BIANCO.**
   - Sintomo: «esce bianco», «pesa poco» (841 byte per una pagina da 1,6 MB), riquadro dell'annotazione presente ma contenuto no.
   - Causa: copia struttura (e `document` non nil) ma non le risorse del content stream (immagini). Il thread non conta.
   - Fai: `PDFUtility.detachedPage(from:)` (`pdfexpert/InternalUtils/PdfUtility.swift`), che passa da `dataRepresentation`. Usato in `PdfEditViewModel` (disegno pagina, duplica pagina) e `PdfCompressUtility.byteCount(of:)`. I test tengono `page.copy()` come misura. **Quando verifichi «non è bianco» controlla almeno due canali** (il bianco ha rosso pieno); nei test di compressione usa rumore, non riempimento pieno.
11. **`page.removeAnnotation(_:)` azzera `annotation.page`.** I tool firma/compila staccano le annotazioni e poi le ritrovano con `filter { $0.page == page }`: dopo lo stacco reimposta `annotation.page` a mano, altrimenti tocco, overlay e conferma non trovano nulla. Le annotazioni nuove funzionano perché il codice imposta `page`.
12. **Tocco sull'annotazione dall'editor.** Il pager mostra un'immagine, non un `PDFView`: `PdfEditViewModel.pointInPage` fa l'aritmetica a mano (toglie la banda aspect-fit, ribalta la y). L'annotazione non si passa per identità (ogni tool copia il documento): viaggia come (indice pagina, rettangolo) e si riconosce con `CGRect.isNearlyEqual` (1 pt). `verticalCenteredTextBounds` toglie 10 pt per lato (`CGRect.decode`): prima riga da guardare se i testi corti sono difficili da centrare.
13. **Drag del riquadro di testo.** `DragGesture` riporta la posizione nello spazio della vista a cui è attaccato (quella che sta spostando): usa uno spazio nominato sul contenitore. I riconoscitori del `TextField` battono un `.gesture` normale: serve `highPriorityGesture` con soglia 8 pt (tap resta al campo, movimento = drag).
14. **`PdfEditViewModel.onAppear` riparte a ogni pop di un tool spinto.** Tutto ciò che ci aggiungi dev'essere idempotente (l'hook `debugEditorSheet` non lo era e riapriva il tool appena chiuso).

## Editor e scansioni

15. **L'editor non va riempito sul main thread.** Costruire due immagini per pagina in `init` costava 0,9 s a pagina su una scansione (20 pagine = 18 s di editor congelato: «gli strumenti non funzionano, il tasto indietro non risponde»). Oggi: `refreshPages()` in background, `pages: [EditorPage]`, immagini a piena dimensione su richiesta per la pagina corrente ±1 (`loadedPageImages`). Invarianti da non rompere: `pageCount` viene dal documento; le operazioni di pagina aspettano `canEditPages`; `renderGeneration`/token scartano i render obsoleti; il render pigro copia la pagina sul main thread (con `detachedPage`) e disegna la copia in background. La miniatura costa quanto la pagina (decodifica della foto). La memoria non è stata misurata con Instruments.
16. **`AVCaptureDevice.RotationCoordinator` vuole il preview layer.** Con `previewLayer: nil` risponde per un layer ipotetico: anteprima ruotata di 90°. Il layer si passa al service (`attach(previewLayer:)`) che ricostruisce il coordinator; l'angolo va riapplicato a ogni `layoutSubviews` (una `AVCaptureConnection` mai impostata sta a 0°, landscape; SwiftUI non richiama `updateUIView` se il valore pubblicato non cambia). Filtra la console per `rotation:`.
17. **Una cache non `@Published` non ridisegna niente.** `DocumentScanViewModel.renderCache` è privata: finito il render nessuno lo sa e resta lo scatto grezzo («i filtri non funzionano alla prima»). Basta `objectWillChange.send()` quando un render atterra.
18. **Una soglia euristica non vale per una scelta esplicita.** `ScanQuad.isUsable` (`area > 0.16`) serve al `DocumentDetector` per proporre un contorno; il ritaglio dell'utente passa da `isRenderable` (rifiuta solo lato collassato e quadrilatero incrociato) in `ScanImageProcessor.corrected`. Se ricompare un «non ha effetto», cerca una soglia applicata a una scelta esplicita.
19. **Feedback di uno scatto non richiesto**: `.sensoryFeedback(.impact, trigger: pages.count)` sul conteggio pagine, non sul tentativo.

## Pager e onboarding

20. **`PagerTabStripView` 4.0.0 smette di seguire il binding `selection`** (onboarding che tornava alla prima pagina). Usa `TabView` + `.tabViewStyle(.page)` (swipe disabilitato con `.highPriorityGesture(DragGesture())`). L'onboarding non ha pager: un solo documento disegnato che si trasforma tra i passi (`OnboardingIllustrationView.swift`). Un asset con `template-rendering-intent: template` si disegna come sagoma piena (rettangolo bianco). `ImportTutorialView` ha testi non nel catalogo (restano inglesi).
