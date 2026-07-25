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
12. **Full-text archive search (product feature)** — the archive now has a
    `.searchable` bar filtering by **filename + page text** (case/diacritic-
    insensitive, in-memory over the loaded list). New optional Core Data attribute
    `CDPdf.searchableText` (lightweight auto-migration; the model is
    `usedWithCloudKit`), populated on every save via `PDFUtility.extractText(from:)`
    and mapped onto the `Pdf` struct. `ArchiveViewModel.filteredItems` + a "no
    results" view + EN/IT keys. **No backfill** (chosen): PDFs saved before this
    match by filename only until re-saved or OCR'd. Covered by 2 `extractText`
    unit tests (filter logic needs a real `NSManagedObjectID`, so it's on-device).

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
- **Full-text search** — type in the archive search bar: matches by filename and
  by page text (OCR'd or born-digital); old PDFs match by filename only (no
  backfill). **CloudKit:** the new `searchableText` attribute must be **deployed
  to the Production CloudKit schema** (CloudKit Dashboard) before release — dev
  creates it automatically, production does not. Verify iCloud sync still works.

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
~~merge/split/extract pages~~ ✅ done (phase 1) · ~~rich annotations~~ ✅ done
(phase 3, reader markup) · smart compression presets (S/M) · App Intents /
Shortcuts / Widget (M — phase 4) · archive organization with
folders/~~search~~/tags (M — search ✅ done, see #12) · compare PDFs
(dropped from phase 3, still unplanned).

## Phase 3 (2026-07-25) — on-device round 2 + PSPDFKit removal

Branch `feature/phase-3`, six commits, suite 96 → 154 tests. Plan:
`~/.claude/plans/glowing-herding-galaxy.md`.

1. **PSPDFKit removed** (release blocker: no license ⇒ 1-hour demo mode,
   "not for redistribution", trial watermark). Its single use, Office→PDF, is
   now `DocumentRenderUtility` (WebKit + `UIPrintPageRenderer` A4 pagination) with
   an optional high-fidelity fallback through Stirling `/api/v1/convert/file/pdf`
   — offered explicitly, gated premium, never silent. `OfficeImportCoordinator`
   owns that flow for Home, editor and chat.
2. **Web page → PDF** and **Markdown → PDF** (free, on-device).
3. **Remove blank pages / Flatten / Invert colors** (free), on the shared
   `PdfOverlayUtility.redrawPages` rebuild.
4. **PDF permissions** (premium): printing/copying flags via `CGPDFContext`.
5. **Redaction** (premium): touched pages are rasterized, so covered text leaves
   the file; saved as a `-redacted` copy.
6. **Reader annotations** (premium): highlight / underline / strikethrough,
   persisted to the archive.

Deviations from the plan, both deliberate:
- Permissions are a **separate tool** rather than an extension of "PDF Protector".
  That flow keeps `pdf.password` as model state applied at share time; carrying
  permissions the same way needed a new Core Data attribute, and with the model
  `usedWithCloudKit` that means a production schema deploy. **No schema change
  landed in phase 3.**
- Annotations offer **undo**, not tap-to-delete: a delete gesture on `PDFView`
  fights its own text selection.

Still to verify on device (not CLI-checkable): real `.docx/.xlsx/.pptx/.pages`
conversion quality and the fallback prompt; web pages behind cookie banners;
redaction box placement on rotated pages at various zoom levels; the annotation
save/discard flow; the 14-row "…" menu on a small device.

## Build / project notes (still true — save time)

- **Non-standard build configs**: `Staging Debug`, `Production Debug`,
  `Staging Release`, `Production Release`. There is NO plain `Debug`/`Release` —
  passing one makes xcodebuild silently fall back to `Production Release` and emit
  misleading `Unable to resolve module` errors. Always pass an explicit config.
- **Local build needs `ProjectInfo.plist`**: `pdfexpert/Resources/ProjectInfo.plist`
  is git-ignored (holds `OPENAI_API_KEY`, and now `STIRLING_API_KEY`) and must exist
  locally. A placeholder is enough to compile; use the real key to exercise ChatPDF.
  The plist is **no longer bundled** into the app. At build time the "Generate Secrets"
  run-script phase (runs before Compile Sources; see `pdfexpert/Scripts/generate_secrets.sh`)
  reads the plist and emits `pdfexpert/Generated/ObfuscatedSecrets.swift` (git-ignored)
  with each key XOR-obfuscated against a fresh random pad. `ProjectInfo.openAiApiKey` /
  `ProjectInfo.stirlingApiKey` deobfuscate it at runtime via `ObfuscatedSecret`. Result:
  no cleartext key in the IPA and nothing recognizable in `strings` on the binary. To
  set the real key, just edit the git-ignored plist and rebuild — nothing else. This
  only raises the bar; a runtime attacker can still extract keys, so the eventual fix
  is still a server-side proxy.
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
- **PSPDFKit is gone** (removed in phase 3 — it could not ship without a paid
  license). Office→PDF is on-device via `DocumentRenderUtility`, with the Stirling
  API as an opt-in high-fidelity fallback. Per-image PDF recompression (the A2c
  "surgical" path) has no on-device equivalent; the current heuristic keeps
  flattening image-heavy pages instead.

## How to resume

1. `git checkout main && git pull` (HEAD should be the localization commit).
2. Drop a real (or placeholder) `pdfexpert/Resources/ProjectInfo.plist` in place.
3. Pick from "Remaining": the highest-leverage next steps are the **on-device A2/
   A4/A5 verifications**, then the **interpolated-string localization pass** in
   Xcode, then a product feature (OCR is the strongest premium hook).
4. Land each unit as its own small change against `main`.

## Phase 4 (2026-07-25) — UI rebuild on iOS 26 / Liquid Glass

Full visual and structural rework of the app. The tools, view models and PDF
utilities are unchanged; what changed is the shell, the navigation and every
screen's presentation.

### Decisions taken with the product owner

- **Minimum iOS is now 26.0** (was 16.4), on every target and configuration.
  Liquid Glass (`glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`,
  the `Tab` API with roles, `tabBarMinimizeBehavior`, `ToolbarSpacer`) is used
  directly, with no availability branches.
- **The app follows the system appearance.** `INFOPLIST_KEY_UIUserInterfaceStyle
  = Dark` is gone from all four configs.
- **Typography is SF with Dynamic Type.** Poppins is no longer used;
  `FontPalette` survives as a shim that maps the old `font*(withSize:)` calls
  onto system text styles, so the untouched screens scale too.
- **Information architecture is files-first**: Files · Tools · ChatPDF, plus a
  search tab carrying the system `.search` role.

### What landed

1. **Design system** — `Style/ColorPalette.swift` is now semantic and defined in
   code (`background`, `surface`, `textPrimary`, `accent`, per-category tints…),
   each token with a light and a dark value; the old names (`primaryBG`,
   `thirdText`, …) remain as aliases. `Style/DesignSystem.swift` holds spacing,
   radii, motion and the two surface treatments — **opaque for content, glass
   only for floating chrome**. New shared components live in
   `Views/Components/`.
2. **Shell** — `MainTabView` uses the iOS 26 `Tab` API, the tab bar minimizes on
   scroll, and `MainTab` gained titles/symbols. `MainCoordinator` gained
   `runTool(_:)` + `pendingToolAction`, so any screen can start a tool flow (the
   flows themselves still live on the Tools screen).
3. **Files** (`Views/Files/`, replaces `ArchiveView`) — grid or list, sortable,
   searchable, context menu per document, a glass "New" button, and
   `ContentUnavailableView` empty/error states.
4. **Tools** (`Views/Tools/`, replaces `HomeView`) — every tool now described
   once in `ToolCatalog` (title, subtitle, SF symbol, family, premium flag,
   search keywords). The screen has a search field, a quick-actions strip backed
   by `ToolUsageTracker` (real usage, persisted), and one grid per family.
5. **Search** (`Views/Search/`) — one field over documents (filename + indexed
   text) and tools.
6. **Editor** — the fourteen-row form sheet became a grouped `Menu`; the four
   common edits sit in a glass bar over the page; save is a prominent toolbar
   button; the page strip shows numbers and a tinted selection.
7. **Reader** — page runs edge to edge, markup bar and page counter float in
   glass, reading modes moved into a menu.
8. **Settings** — grouped list with subscription state, restore purchases,
   legal links and the app version.
9. **Localization** — 162 new Italian translations added to
   `Localizable.xcstrings` (459 keys total).

### Watch out

- **The signature sheet must stay white with black ink.** It used to rely on the
  app being dark-only (`ColorPalette.primaryText` as a background). It now uses
  the fixed `signatureSheet` / `signatureInk` / `signatureInkSecondary` tokens —
  do not swap those for theme-aware ones.
- **ATT is skipped on the simulator** (`#if targetEnvironment(simulator)` in
  `AppTrackingTransparencyImpl`), otherwise the prompt sits in front of every
  screen during development. Device behaviour is unchanged.
- **Debug hooks** (all `#if DEBUG`, driven by `UserDefaults`, useful because the
  simulator takes no programmatic taps):
  `xcrun simctl spawn booted defaults write <bundle-id> debugInitialTab -int 1`
  (0 files, 1 tools, 2 chat, 3 search), `debugShowSettings`, `debugSeedArchive`
  (fills an empty archive with copies of the bundled test PDF), `debugOpenEditor`.
- **Simulator runs need a signed build**: `CODE_SIGNING_ALLOWED=NO` produces an
  app without the iCloud entitlement and CoreData+CloudKit throws on launch. Use
  `CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES`.
- The staging `Info.plist` (git-ignored) registers only the `pdfpro` URL scheme
  while the code builds `pdfprostaging://` — deeplinks do not resolve on staging
  unless that scheme is added.
- Still to check on a device: the three paywall variants and the signature flow
  in light appearance, and the tool sheets that were only re-tinted (they follow
  the tokens, but they were not redesigned).

## Phase 5 (2026-07-25) — App Intents, Shortcuts and a widget

The app now reaches outside itself: Siri, the Shortcuts app and the Home Screen.

### App Intents (in the app target, `pdfexpert/Intents/`)

- `PdfToolEntity` + `PdfToolQuery` expose the whole `ToolCatalog` to Shortcuts,
  matching on the same fields the in-app search uses, keywords included. Adding
  a tool to the catalog therefore adds it to Shortcuts too.
- `OpenPdfToolIntent` / `OpenFilesIntent` / `ScanDocumentShortcutIntent` open the
  app on a tool, on the archive, or on the scanner, going through
  `MainCoordinator.runTool(_:)`.
- File intents that run **without opening the app**: `MergePdfsIntent`,
  `RotatePdfIntent`, `RemoveBlankPagesIntent` (free) and `ExtractPdfTextIntent`
  (premium). They reuse `PDFUtility` / `PdfCleanupUtility` and run PDFKit off the
  main thread. A paywall cannot be presented from a background intent, so a
  gated intent throws `PdfIntentError.premiumRequired` instead.
- `PdfExpertShortcuts` registers five zero-setup phrases. The build embeds
  `Metadata.appintents` in the app bundle — check it there if an intent seems to
  be missing.

### Widget (`PdfProWidget`, new target)

- `RecentDocumentsWidget` (small/medium/large) and `QuickActionsWidget`
  (small/medium). Both open the app through the URL scheme, so the extension
  stays out of the app's dependency graph (no Factory, no Core Data).
- Data comes from `pdfexpert/Shared/SharedDocumentStore.swift`, shared between
  app and widget: the app writes a JSON snapshot plus small PNG thumbnails into
  `group.eu.balzo.pdfexpert` on every archive refresh, then calls
  `WidgetCenter.reloadAllTimelines()`. **The widget deliberately does not open
  the Core Data store** — it is CloudKit-backed and lives in the app container.
- The widget has its own bundle, so its strings live in
  `PdfProWidget/Localizable.xcstrings` (EN/IT), separate from the app catalog.

### Deeplinks

`Deeplink` now understands `document/<core-data-uri>` and `tool/<identifier>` on
top of the tab hosts, and `HomeAction.identifier` is the shared id used by the
widget, the intents and the usage tracker. Covered by `DeeplinkTests` (12 tests,
suite is now 166).

### Target notes (worth knowing before touching the project file)

- The widget target was added with the `xcodeproj` gem. Two traps: `new_target`
  also creates plain `Debug`/`Release` configurations that must be deleted (this
  project only has the four custom ones), and `INFOPLIST_KEY_NSExtensionPointIdentifier`
  **does not exist** — the widget needs a partial `Info.plist` carrying
  `NSExtension`, merged with the generated one via `GENERATE_INFOPLIST_FILE = YES`
  plus `INFOPLIST_FILE`.
- The widget bundle id must stay prefixed with the app's, per configuration:
  `eu.balzo.pdfexpert[.staging].widget`. It carries the app group entitlement and
  `-D STAGING` on the staging configurations, so it picks the right URL scheme.
- Verify the extension is registered with:
  `xcrun simctl spawn booted pluginkit -m -v | grep pdfexpert`.

### Still to try on device

Siri phrases, the Shortcuts actions against real files, and both widget sizes on
the Home Screen (a widget cannot be added from the command line).
