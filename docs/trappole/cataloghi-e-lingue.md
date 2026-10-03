# Trappole: cataloghi xcstrings e lingue

Leggilo prima di toccare `Localizable.xcstrings`, aggiungere una lingua o una chiave localizzata, o allineare le schede dello store.

File: `pdfexpert/Resources/Localizable.xcstrings` (app; oggi 6 lingue: en, it, es, de, fr, nl; ~1015 chiavi) e `PdfProWidget/Localizable.xcstrings` (widget). Lint: `pdfexpert/Scripts/localization_lint.py`.

1. **Riscrivere il catalogo con `json.dump` standard produce un diff di migliaia di righe.**
   - Causa: Xcode scrive `"chiave" : valore` (spazio prima dei due punti), Python `"chiave": valore`.
   - Fai: `json.dumps(d, ensure_ascii=False, indent=2, separators=(",", " : ")) + "\n"`. Verifica prima di scrivere che un round-trip del file di HEAD torni identico byte per byte. **Attenzione: i due cataloghi possono avere stili diversi** (quello dell'app usa `" : "`, quello del widget aveva `": "`): rileva lo stile leggendo i primi 4000 byte e non riscrivere con un solo stile (diff da 46.000 righe). Controlla con `head -c 400` prima di scrivere.
2. **L'ordine delle chiavi non si ricalcola.** Xcode usa un confronto localizzato che `sorted()` non riproduce (i simboli non contano come crede Python); riordinare sposta mille righe. Parti dal file esistente e **inserisci** ogni chiave nuova subito dopo la vicina giusta. Non usare `sort_keys=True`.
3. **Xcode lascia una chiave vuota `""`** quando qualcuno apre il catalogo dall'IDE. `localization_lint.py` la segnala (`empty-key`) e blocca `fastlane test`/`lint`: toglila, non committarla.
4. **Le chiavi con plurale hanno `variations.plural` (`one`/`other`), non `stringUnit`.** Uno `stringUnit` singolo su una di esse è accettato da Xcode e fa sparire la forma singolare. Oggi sono 8 (`%lld checks passed`, `%lld compressed images`, `%lld documents`, `%lld pages changed`, `%lld photos on one sheet, with lines to cut along.`, `%lld scans`, `%lld tools`, `Removed %lld blank pages.`): **contale ogni volta** (cerca `variations` nelle localizzazioni) invece di fidarti di questa lista. Controllo: nel bundle, `Localizable.strings` + plurali in `Localizable.stringsdict` devono sommare al totale delle chiavi.
5. **Aggiungere una lingua: sei posti, e saltarne uno dà errori che sembrano altro.**
   1. I due `Localizable.xcstrings`: aggiungi `localizations.<lang>.stringUnit` a ogni chiave (plurali a parte).
   2. `knownRegions` in `pdfexpert.xcodeproj/project.pbxproj` (oggi `en, Base, it, es, de, fr, nl`). Senza, il catalogo compila ma la lingua non entra nel bundle: nessun `<lang>.lproj`, nessun errore.
   3. Il documento di scena, se la lingua serve agli screenshot: `K.Test.DebugContractName` / `DebugContractFilename` in `Constants.swift` più il PDF `pdfexpert/Resources/Test/contract-<lang>.pdf` (generato da `fastlane/screenshots-src/chat-material/<lang>.html` con Chrome headless `--headless --no-pdf-header-footer --print-to-pdf`).
   4. **Il PDF va aggiunto al target a mano nel `pbxproj`** (PBXFileReference + PBXBuildFile + gruppo + fase Resources; i `contract-*.pdf` sono referenziati uno per uno). Altrimenti il seed non salva il contratto e il test screenshot fallisce con «the seeded archive never appeared» (sembra un problema UI test, è una risorsa mancante).
   5. `StoreScreenshotsUITests.swift` (tabella `labels` copiata a mano dal catalogo, nome del contratto, domanda chat), `fastlane/screenshots-src/make-screenshots.sh` (`LANGS`) e `index.html` (titoli vetrina).
   6. `fastlane/metadata/<locale>/` con i file di testo (vedi `prezzi-e-asc.md`).
6. **Controllo che chiude il lavoro (non basta che compili).** Nel bundle costruito: `ls -d "$APP"/*.lproj` (deve comparire la lingua); `plutil -convert json -o - "$APP/<lang>.lproj/Localizable.strings"` e `.stringsdict`; il totale deve tornare con le chiavi del catalogo.
7. **La riga «Disponibile in...» di ogni `description.txt` va aggiornata in tutte le schede** (16-17 locali). Nelle lingue CJK non si trova cercando «disponibile»: cerca `영어`, `提供`, `英文`. Il rischio opposto del francese storico: la scheda prometteva una lingua che l'app non parlava; qui l'app parlerebbe una lingua che nessuna scheda nomina. **Scheda localizzata e app localizzata sono due cose diverse**: verifica con `knownRegions`, le chiavi nel catalogo e i `*.lproj` nel bundle.
8. **`Text(String)` non localizza**: solo l'overload `LocalizedStringKey` lo fa. Testi che arrivano come `String` (view model) passano da `String(localized:)`. Un testo non nel catalogo resta inglese in ogni lingua.
9. **Gli screenshot si fanno dopo la traduzione**: fotografano l'app che gira, quindi su un'app non tradotta escono in inglese qualunque lingua si passi.
10. **Una lingua nuova dello store non ha screenshot propri finché non li ha tutti** (iPhone e iPad): vedi `prezzi-e-asc.md`.
