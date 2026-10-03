# Trappole: test, UI test, screenshot, verifica a schermo

Leggilo prima di scrivere o lanciare UI test (`PdfExpertUITests/`), rifare gli screenshot dello store (`fastlane/screenshots-src/`), guardare la UI senza schermo, o dichiarare «funziona».

## UI test

1. **`XCUIElement.tap()` non funziona in questa app.**
   - Sintomo: il test aspetta e rinuncia su un bottone SwiftUI.
   - Causa: XCTest riporta i bottoni come `isHittable = false` (con `isEnabled` true).
   - Fai: `coordinate(withNormalizedOffset:).tap()`; nei file c'è l'helper `tap(_:)`. Gli UI test sono l'unico modo di premere un bottone da questa macchina (AppleScript bloccato, niente `idb`/`cliclick`).
2. **Tre navigation bar nell'albero insieme** (archivio dietro la cover, editor, tool spinto): una query non scopata è un terno al lotto e `element(boundBy: 0)` prende la prima dell'albero, non quella a schermo. Scopa sempre per titolo di barra; le tile del pannello hanno identificatore `editorTool.<rawValue>`.
3. **Un bundle UI reinstalla l'app pulita** (onboarding davanti, archivio vuoto). Launch argument: `-onboardingShown YES -debugSeedArchive YES` (`-debugPremium YES` per i tool premium, `-debugResetArchive YES` per svuotare, `-debugStorefront ZAF`, `-debugExitOffer YES`). Reinstallare **non** azzera gli `UserDefaults` dell'app: per l'onboarding serve `-onboardingShown NO`. I test sono fissati in inglese (`-AppleLanguages (en)`).
4. **`firstMatch` non è quello che pensi.** Quattro schermate hanno un bottone `Finish`; su iPad la sidebar dell'archivio resta nell'albero dietro al foglio e `cells.firstMatch` è la sua prima riga. Scopa per il contenitore giusto.
5. **Lo scheme esegue unit + UI (~4 minuti).** Giro veloce: `-only-testing:PdfExpertTests`.
6. **Gli UI test vedono solo i prodotti StoreKit di ASC** (vedi `prezzi-e-asc.md`). Per guardare un paywall senza Xcode: gli UI test allegano uno screenshot (`PaywallEntryUITests`, `DayPassPaywallUITests`); estrai con `xcrun xcresulttool export attachments --path <bundle>.xcresult --output-path <dir>` (nomi in `manifest.json`).

## Verifica dell'esito

7. **Un percorso completato non è una prova: lo è solo lo stato finale.**
   - Caso: `StoreScreenshotsUITests` apriva il pannello firma, disegnava, Conferma abilitato: tutto verde, ma `firstMatch` prendeva un `Finish` sbagliato e la firma veniva scartata; lo screenshot di vetrina usciva con la pagina intatta.
   - Fai: dopo la sequenza asserisci ciò che doveva cambiare (modale sparita con `waitForNonExistence`, documento con l'annotazione, file cresciuto). Vale per ogni comando: `git push` può rispondere ok senza pushare (nessun upstream): verifica con `git ls-remote`.
8. **Quando una decisione si propaga da sola, il controllo va fatto dove si propaga, non dove è stata presa.** Un prezzo corretto in un paese e sbagliato negli altri 174 (equalizzazione Apple). Guarda l'immagine/l'output vero; fallo vedere all'utente.
9. **Test che verificano «non è bianco» controllano almeno due canali** (il bianco ha rosso pieno). Vedi `swiftui-e-pdfkit.md`.

## Screenshot dello store

10. **Il simulatore deve stare in piedi.** Conserva l'orientamento: un iPad coricato riporta una finestra 1376x1032 e cattura 1032x1376, e le coordinate normalizzate puntano altrove. Non correggere con `XCUIDevice.shared.orientation` (la cattura esce di traverso): shutdown + boot.
11. **Il container del simulatore sopravvive ai run.** Senza `-debugResetArchive` la seconda lingua apre l'archivio della prima; le firme non sono toccate dal reset, il seed le cancella a parte.
12. **La firma non si disegna, si semina:** `-debugSeedSignature "<nome>"` (font di sistema Snell Roundhand). Un drag sintetizzato traccia segmenti dritti. L'app posa la firma al centro; il test la trascina sulla riga con coordinate misurate (diverse tra iPhone e iPad): per questo il contratto sta in una pagina sola. Il gesto va lasciato assestare: `Finish` dentro l'animazione di rilascio butta la firma.
13. **La chat non si fotografa in simulatore** (il proxy vuole l'`originalTransactionId` di StoreKit): si cattura a mano da un telefono con abbonamento (`chat-material/`). Senza, si caricano cinque slide (ASC ne accetta da 1 a 10).
14. **`place-shots.sh` senza nome di lingua riscrive tutto**: nomina la lingua, `./place-shots.sh out de`. iPad: `DEVICE=ipad SLIDES=5 ./export.sh <lingua>`. Lingua del test: `TEST_RUNNER_SHOT_LANG`. Script in `fastlane/screenshots-src/` (vedi il suo `README.md`).

## Guardare l'app senza schermo

15. **`DebugWindowCapture`** (`pdfexpert/Utils/UI/DebugWindowCapture.swift`, solo `#if DEBUG`) fa fotografare all'app le proprie finestre; variabili d'ambiente `PDFPRO_CAPTURE_DIR` (accende tutto), `PDFPRO_CAPTURE_LABEL`, `PDFPRO_CAPTURE_GOTO` (`onboarding` o numero di `MainTab`), `PDFPRO_CAPTURE_OPEN`. Regole: `drawHierarchy(afterScreenUpdates: true)`, non `layer.render(in:)` (salta i materiali); fotografa **ogni** `UIWindow` (alert e picker vivono in finestre proprie); non fidarti di `print` se il processo è ucciso con `pkill` (scrivi su file); non concludere che manchi ciò che il sistema disegna fuori dalla finestra (barra del titolo Mac, status bar); prima foto dopo ~4 s, poi ogni 3.
16. **Hook di debug utili (UserDefaults/launch argument):** `debugRunTool` (apre un tool; l'app parte sulla tab Strumenti), `debugPremium`, `debugSeedArchive`, `debugStorefront`, `debugExitOffer`, `debugEditorSheet`. Es.: `xcrun simctl spawn booted defaults write eu.balzo.pdfexpert.staging debugRunTool -string background`.

## Vision e simulatore

17. **Vision non gira sul simulatore.** `GenerateForegroundInstanceMaskRequest` risponde `com.apple.Vision Code=9 "Could not create inference context"`: il ritaglio vero si prova solo su device (checklist in `docs/DEVICE-TEST.md`, sezione «Foto»). In DEBUG+simulatore `BackgroundRemovalUtility.debugPlaceholderMask` sostituisce un ovale (mai su device).
18. **Bug trovati dai test sulla rimozione sfondo, da non reintrodurre** (`pdfexpert/InternalUtils/BackgroundRemovalUtility.swift`): sotto ~940 px i raggi (frazioni del lato lungo) arrotondano a 0 in Core Image: minimo 1 px; erosione/sfocatura campionano fuori dal fotogramma: serve `clampedToExtent` o il bordo mangia il soggetto; un grigio o colore P3 non è RGB e `CIImage(color:)` lo rende nero: converti in sRGB; la maschera porta il valore in tutti i canali (alpha compreso). `CIMorphologyMinimum` cancella le ciocche sottili (alone sui capelli): si usa un choke sull'alpha, e la larghezza della rampa è la portata del choke.
19. **Il simulatore non ha entitlement iCloud:** CoreData+CloudKit fa trap; vedi `firma-e-release.md` (firma ad-hoc, `PDFPRO_DISABLE_CLOUDKIT=1`).
