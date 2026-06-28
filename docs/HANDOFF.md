# Handoff — review fixes re-applied onto `main`

Updated 2026-06-28. Read this first when picking the work up in a fresh session.

## TL;DR

The review/bug-fix/refactor work that used to live on the diverged branch
`fix/review-bugs-and-pdf-refactor` (which was 111 commits behind a restructured
`main` and **not** mergeable) has been **re-applied by hand onto the current
`main`** and merged in. Everything below is on `main`, each piece built and/or
unit-tested on **Xcode 26.6 / iOS 26 SDK** (`Staging Debug`, iPhone 17 Pro
simulator).

What's left is mostly **on-device behavioral verification** (things the CLI
can't validate) plus a few intentionally-deferred refactors and the product
backlog — see "Remaining".

## What landed on `main`

In order:

1. **iOS 26 SDK build fix** — `PDFImageExtractor.swift`. The `CGPDF*Ref` types are
   now distinct opaque types instead of `OpaquePointer` typealiases; the generic
   accessors moved onto a `CGPDFContainerRef` marker protocol over `Self`.
   **Prerequisite:** without this the project does not compile on Xcode 26.
2. **Review quick wins** — stop logging the PDF password in clear
   (`HomeViewModel`/`PdfEditViewModel`); `PdfScanUtility` progress off-by-one;
   guard `videoDeviceInput` in `CameraService.focus/set(zoom:)`; stop
   force-unwrapping `photo.image`; break the `isPremium` retain cycle in
   `SubscribeViewModel`.
3. **PdfUtility hardening** — removed the `removePassword` 0-page crash + force
   unwraps, the `unlock` `CGDataProvider!`, the `applyPostProcess` empty-doc unwrap.
4. **A4 (subscription status)** — `subscriptionGroupStatus` now picks the
   access-granting status (Family Sharing / multiple statuses).
5. **`PdfExpertTests` unit-test target** — host = `PdfExpert`, the four custom
   build configs, added to the "PdfExpert Staging" scheme. 6 tests.
6. **fastlane** — `ci_build`, `test`, `beta`, `release` lanes.
7. **EN/IT String Catalog** — `Localizable.xcstrings` + `it` known region, on the
   app and `ShareFileExtension`. Now **142 keys, all translated** (incl. the
   long-tail extraction of static UI strings).
8. **A2/A2b/A2c (margins + compression)** — `applyPostProcess` draws margins into
   a PDF context so text stays vector, and only rasterizes/JPEG-compresses
   image-only or image-heavy pages (`pageIsImageHeavy`). Covered by
   text-preservation unit tests.
9. **A4 (concurrency)** — `Store`/`StoreImpl` isolated on the main actor; pure
   helpers and `isPremium` stay `nonisolated`.
10. **A5/A5b (presentation state machine)** — the per-modal `fullScreenCover`
    booleans collapse into one `activeSheet` + a single `.fullScreenCover(item:)`
    in `PdfEditView` and `HomeView`; the fixed `Task.sleep(0.25s)` delays became a
    next-runloop defer.
11. **OCR / searchable PDF (product feature)** — `OcrUtility` (new,
    `InternalUtils/`) runs on-device Vision text recognition (`VNRecognizeTextRequest`,
    `it-IT`+`en-US`) over a PDF's *image-only* pages and rebuilds each as the page
    bitmap + an **invisible** Core Text layer (`setTextDrawingMode(.invisible)`)
    positioned on Vision's boxes → selectable/searchable. Pages that already carry
    vector text are left untouched. Covered by 4 unit tests (`OcrUtilityTests`).
    Exposed two ways, both gated premium *before* running (paywall, then runs on
    successful purchase): (a) editor `…` menu → `EditAction.ocr` (own `asyncOcr`
    channel that **replaces** the document, vs `asyncPdf` which appends); (b) Home
    tool → `HomeAction.ocr` (import a PDF or scan → editor opens with the new
    `PdfEditStartAction.openOcr`, which runs the same gated flow). Added analytics
    (`AnalyticsScreen.ocr`, events `ocr_started`/`ocr_completed`), EN/IT catalog
    keys, an `isSystemImage` option on `OptionItem`/`OptionItemView` (SF Symbol
    `text.viewfinder`, no new asset), and a **placeholder** `home_ocr` imageset
    (a copy of `home_read` — swap for a dedicated illustration).

## Remaining

### Needs on-device / behavioral verification (the code is in, the behavior isn't CLI-checkable)
- **A5/A5b** — open & dismiss each modal (PdfEdit: camera, scanner, signature,
  fill-form, fill-widget; Home: camera, scanner), the camera/scanner
  convert-on-dismiss, the `startAction` auto-open, and the no-widget alert. Watch
  for a sheet that fails to present because another is still dismissing (that was
  the reason for the removed `Task.sleep`).
- **A4** — purchase / restore / Family Sharing with StoreKit Testing; confirm
  `isPremium` flips and persists across relaunch, and no main-thread hang.
- **A2** — apply margins/compression to real PDFs: text must stay selectable;
  mixed text+image PDFs must shrink while text pages stay vector (a caption on an
  image-heavy page is flattened — known tradeoff).
- **OCR** — run on a real scanned PDF (editor `…` → Make Searchable, and Home →
  Make Searchable via file/scan): paywall shows for non-premium and OCR runs after
  purchase; progress bar; resulting text is selectable/searchable; a PDF that is
  already all-text comes back unchanged (no user feedback yet — see deferred).
  Watch big/many-page scans for time + memory (pages render at 2x, capped 4000px).

### Intentionally deferred
- **A5 page-model unification** — `pageImages` + `pdfThumbnails` →
  `pages: [PdfPagePreview]` with background preview generation. Riskier
  data-model refactor (page display/reorder/delete), not headless-verifiable.
  Only the state-machine part of A5 was done.
- **Localization interpolated strings** — ~7 strings with interpolation
  (`"Page \(n)"`, `"\(x) of \(y)"`, `"Welcome in \(AppTitle)…"`) need an Xcode
  build-time extraction pass to generate their `%@/%lld` catalog keys. The static
  strings are all done.
- **`AppleAttribution` package** — the old branch added it as an *unused*
  dependency; re-adding it as dead weight was skipped. If attribution is actually
  wanted it needs a real integration (init + config in `AppDelegate`).

### Backlog (from the old `NEXT_TASKS.md`)
- Extend the test suite: append paths, `PdfScanUtility` progress, `Pdf.shareData`.
- A6: header cleanup + rename the misspelled `pdfexpert/Applicaction/` →
  `Application/`; async/await modernization (large, module by module).
- A localization lint to flag raw string literals in new views.

### OCR follow-ups
- ✅ **Word-level text layer** — done. The invisible layer is now placed per word
  via `candidate.boundingBox(for: range)` (line-level fallback), for tight
  selection. (`OcrUtility.drawInvisibleText`/`drawText`.)
- ✅ **Output size** — done. OCR'd pages re-embed the bitmap JPEG-compressed
  (`OcrUtility.defaultJpegQuality = 0.7`, param threaded through `makeSearchable`).
  Unit test asserts the compressed output is smaller.
- **"Already searchable" feedback** (deferred) — when no page needs OCR the
  document is returned unchanged silently; consider an alert/toast.
- **`home_ocr` illustration** (deferred) — currently a placeholder copy of
  `home_read`; swap for a dedicated asset.
- **Per-page `jpegQuality` from the user's `CompressionOption`** (deferred) —
  currently a fixed 0.7; could honor `pdf.compression` when set.

### Product features (roadmap)
~~OCR / searchable PDF~~ ✅ done (see "What landed" #11; refinements above) ·
merge/split/extract pages (M) · rich annotations (M/L) · smart compression
presets (S/M) · App Intents / Shortcuts / Widget (M) · archive organization with
folders/search/tags (M).

## Build / project notes (still true — save time)

- **Non-standard build configs**: `Staging Debug`, `Production Debug`,
  `Staging Release`, `Production Release`. There is NO plain `Debug`/`Release` —
  passing one makes xcodebuild silently fall back to `Production Release` and emit
  misleading `Unable to resolve module` errors. Always pass an explicit config.
- **Local build needs `ProjectInfo.plist`**: `pdfexpert/Resources/ProjectInfo.plist`
  is git-ignored (holds `CHAT_PDF_API_KEY`) and must exist locally. A placeholder
  is enough to compile; use the real key to exercise ChatPDF.
- Per-env `Info.plist` / `GoogleService-Info.plist` live in
  `pdfexpert/Resources/{Staging,Production}` and are git-ignored too.
- **Verify build/test from CLI (Apple Silicon)**:
  `xcodebuild test -project pdfexpert.xcodeproj -scheme "PdfExpert Staging" -destination "platform=iOS Simulator,name=iPhone 17 Pro" -configuration "Staging Debug" CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=YES ARCHS=arm64 -derivedDataPath <isolated-dir>`
  (use an isolated DerivedData if Xcode is open). Or `bundle exec fastlane test`.
- The unit-test target was created with the `xcodeproj` Ruby gem (it handles the
  custom configs cleanly). The test host boots Firebase under tests (harmless
  keychain noise); do NOT make `AppDelegate` skip Firebase under tests — it
  crashes the host. `PdfEditViewModel`/`HomeViewModel` resolve `@Injected`
  eagerly, so mock `repository`/`store`/`analyticsManager` in VM tests.
- **CI on Xcode 26**: the SDK-26 `PDFImageExtractor` fix is required to compile
  there; it only uses the concrete CGPDF types, so it's backward-compatible with
  older Xcode too.
- PSPDFKit runs in **trial** (no license key). True per-image PDF recompression
  (the A2c "surgical" path) needs a licensed PSPDFKit Document Editor; the current
  heuristic flattens image-heavy pages instead.

## How to resume

1. `git checkout main && git pull` (HEAD should be the localization commit).
2. Drop a real (or placeholder) `pdfexpert/Resources/ProjectInfo.plist` in place.
3. Pick from "Remaining": the highest-leverage next steps are the **on-device A2/
   A4/A5 verifications**, then the **interpolated-string localization pass** in
   Xcode, then a product feature (OCR is the strongest premium hook).
4. Land each unit as its own small change against `main`.
