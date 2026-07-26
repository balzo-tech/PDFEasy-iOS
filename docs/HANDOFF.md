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
   app and `ShareFileExtension`. **142 keys** at the time, all translated (incl.
   the long-tail extraction of static UI strings).
   **Since phase 11**: EN / IT / ES, 582 keys, all three complete, checked by a lint.
8. **A2/A2b/A2c (margins + compression)** — `applyPostProcess` draws margins into
   a PDF context so text stays vector, and only rasterizes/JPEG-compresses
   image-only or image-heavy pages (`pageIsImageHeavy`). Covered by
   text-preservation unit tests.
   **Superseded by phase 9**: `applyPostProcess` is deleted — nothing could reach
   it any more once the compression picker was removed. `pageIsImageHeavy` lives
   on in `PdfCompressUtility`, which is where compressing happens now.
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
- ~~**A2** — apply margins/compression to real PDFs~~. **Dropped in phase 9**:
  there is no margins/compression-on-share path left to test. What replaces it is
  the Compress tool's own checklist under Phase 7, plus Phase 9's "watch out".
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
- ~~**Localization interpolated strings**~~ — **done in phase 10.** No Xcode
  extraction pass was needed in the end: the keys were already in the catalog
  (`Page %lld`, `%lld of %lld`, `Welcome in %@:\nConvert & Edit`, …), they had
  simply never been translated.
- **`AppleAttribution` package** — the old branch added it as an *unused*
  dependency; re-adding it as dead weight was skipped. If attribution is actually
  wanted it needs a real integration (init + config in `AppDelegate`).

### Backlog (from the old `NEXT_TASKS.md`)
- Extend the test suite: append paths, `PdfScanUtility` progress, `Pdf.shareData`.
- A6: header cleanup + rename the misspelled `pdfexpert/Applicaction/` →
  `Application/`; async/await modernization (large, module by module).
- ~~A localization lint to flag raw string literals in new views.~~ **Done in phase 11**: `pdfexpert/Scripts/localization_lint.py`, `bundle exec fastlane lint`.

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
(phase 3, reader markup) · ~~smart compression presets~~ ✅ done (phase 7) ·
~~App Intents / Shortcuts / Widget~~ ✅ done (phase 5) · ~~archive organization
with folders/search/tags~~ ✅ done (search #12, folders and tags phase 6) ·
~~compare PDFs~~ ✅ done (phase 7) · auto-rename · certificate signing via
Stirling `cert-sign` (only if the market asks for it).

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
  `xcodebuild test -project pdfexpert.xcodeproj -scheme "PdfExpert Staging" -destination "platform=iOS Simulator,name=iPhone 17 Pro" -configuration "Staging Debug" CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES ONLY_ACTIVE_ARCH=YES ARCHS=arm64 -derivedDataPath <isolated-dir>`
  (use an isolated DerivedData if Xcode is open). Or `bundle exec fastlane test`.
  Since phase 6 the ad-hoc signing is **required**: with `CODE_SIGNING_ALLOWED=NO`
  the app has no iCloud entitlement and CoreData+CloudKit traps inside
  `CKContainer` while setting the mirroring up, killing the test host before it
  connects (`Early unexpected exit … crashed before establishing connection`).
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

## Phase 6 (2026-07-25) — folders and tags in the archive

The last piece of the roadmap's "phase 4 — automation" bucket: organising the
archive. Free, on-device, no premium gate. Suite 166 → 178 tests.

### Model

Two new Core Data entities, `Folder` (`CDFolder`) and `Tag` (`CDTag`), each with
`name`, `colorIndex` and `creationDate`. `Pdf` gained a to-one `folder` and a
to-many `tags`, both `nullify`, both with inverses — deleting a folder keeps its
documents, they just become unfiled. Folders are **flat on purpose**: a document
is in one folder or in none, and anything cutting across folders is what tags
are for.

- **Filing never goes through `savePdf`.** `Repository.setFolder(_:for:)` and
  `setTags(_:for:)` touch the relationship alone; `CDPdf.update(withPdf:)`
  deliberately leaves both untouched. Otherwise moving a document into a folder
  would rewrite its whole blob and re-run text extraction — and any later save
  from the editor would silently drop the filing.
- `ArchiveColor` is an index, not a hex string: the hues stay a design decision
  and can be retuned without migrating data or CloudKit records.
- Creating a folder or tag whose name already exists returns the existing one
  (case-insensitively), so the same pile does not end up split in two.

### UI

`FilesFilterBar` above the archive — All · folders · Unfiled · tags — one folder
at a time, tags on top of it, and **multiple tags narrow rather than widen** (a
document must carry all of them). The bar only appears once something has been
created. Filing itself lives in the document's own context menu ("Move to",
"Tags"), where a new folder or tag can be created and is applied to that
document straight away. `ArchiveOrganizerView` (filter bar or the ⋯ menu) is
where they get renamed, recoloured and deleted. Cards and rows show the folder
name and coloured tag dots.

`ArchiveFilter` holds the rules as a value type over the `ArchiveFilterable`
protocol, so the 12 new tests exercise them without a Core Data stack. The
global search reuses them and therefore now matches folder and tag names too.

### Watch out

- **The CloudKit production schema must be deployed before release.** Two new
  record types plus the two relationships. Dev creates them automatically; for
  production, flip `InitializeCloudKitSchema` in `Persistence.swift` once against
  the dev environment, then Deploy Schema Changes in the CloudKit Dashboard. This
  is now blocking together with the older `searchableText` attribute.
- **Running tests on a simulator now needs a signed build.** The model change
  makes CoreData+CloudKit run its setup request at launch, and without the iCloud
  entitlement `CKContainer` traps — the test host dies before the runner
  connects. Use `CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES
  CODE_SIGNING_ALLOWED=YES` instead of `CODE_SIGNING_ALLOWED=NO` (see the command
  in "Build / project notes").
- **No cross-device de-duplication.** Two devices offline can each create a
  folder called "Invoices" and iCloud will keep both. The Apple template's
  history-processing dedupe hook is present but commented out in
  `PersistenceController.storeRemoteChange`; wire it up if this shows up in the
  wild.
- Documents saved as a *new* document (redaction saves a `-redacted` copy, for
  instance) start unfiled — the copy is a new row.
- `debugSeedArchive` now also seeds two folders and two tags, and
  `debugShowOrganizer=YES` opens the Folders & Tags sheet at launch.

## Phase 7 (2026-07-25) — compression presets and PDF comparison

Two tools: **Compress PDF** (free) and **Compare PDFs** (premium). Suite 178 →
200 tests.

### Compress PDF

`PdfCompressUtility` with three presets — Light / Balanced / Maximum — each a
bound on resolution (2400 / 1600 / 1100 px on the longest side) plus a JPEG
quality. **Resolution is what actually shrinks a scan**; quality alone barely
dents a 4000 px page.

- Only the pages that are pixels are re-encoded (no extractable text, or
  image-heavy per `PDFUtility.pageIsImageHeavy`). A text page is left alone, so
  it stays selectable and crisp.
- The compression runs **on a copy of the original document**, replacing single
  pages, rather than assembling a new one. Rebuilding from scratch re-emits
  shared resources — the font above all — once per page, and a multi-page text
  document came out *bigger* than it went in (caught on device: 151 KB → 165 KB).
  When nothing is re-encoded the original size is reported as-is.
- Per page, whichever version is smaller wins; the tool can therefore never hand
  back a heavier file, and it says so plainly when a document cannot be shrunk
  (Save stays disabled).
- No estimate: the file is compressed for real while the sheet is open, and the
  preview is the first page of the *result*. The saved document is a new
  `-compressed` copy; the original stays as the way back.

### Compare PDFs (premium)

`PdfCompareUtility`, entirely on-device, answering in two ways because neither is
enough alone:

- **Text**: word-level LCS diff per page, grouped into runs ("hereby fully"
  rather than two entries). Falls back to line granularity above 1500×1500 words,
  where the quadratic matrix stops being worth it.
- **Visual**: both pages rendered to a common grayscale raster and compared over
  a 32-column grid; cells above a mean-difference threshold are reported, and the
  UI paints them over the page. The grid is row-major **from the top** — a
  bitmap context stores rows top-down while its coordinates run bottom-up, so
  drawing the page as-is already lands the top of the page in row 0. There is a
  test pinning that, because an inverted grid highlights the wrong areas.
- **Pages are aligned first**, by LCS over their text, then unmatched runs are
  re-paired when they are similar enough (Jaccard ≥ 0.4). Without that second
  pass an *edited* page shows up as one removal plus one insertion instead of a
  page that changed — which is what it did before the tests caught it. Two scans
  carry no text to align on, so alignment falls back to position.
- Comparing writes nothing: there is no document to save and neither input can be
  damaged.

### Watch out

- The visual diff normalizes both pages to the left page's aspect ratio.
  Comparing a portrait against a landscape is meaningless pixel by pixel; the
  grid will simply report most of the page as changed.
- Compression on a long document is a real workload: it renders and JPEG-encodes
  every image page, and measures each page twice to decide. There is progress,
  but check the timing on a 100-page scan on a device.
- Debug hooks: `debugRunTool -string compress|compare` opens either tool at
  launch (compare uses two synthetic contracts and skips the paywall, since the
  file picker cannot be driven from the CLI), and `debugCompareMode -string
  visual` opens the result on the visual tab.

## Phase 8 (2026-07-26) — dedicated iPad interface

Until now the iPad shipped the phone UI at iPad size: the same four-tab bar, the
same one-document-at-a-time flow, and three idiom workarounds (`FormSheet`,
`FilePicker`, `actionDialog`) as the entire extent of the adaptation. This phase
adds a real iPad shell, keeps the phone one untouched, and picks between them by
size class so a window resized in Stage Manager or dropped into Slide Over gets
the right one live.

### The shell

`RootShellView` is the new root under `.main`. It owns `archiveViewModel`,
`homeViewModel` and `chatPdfSelectionViewModel` and hands them to whichever shell
is on screen — deliberately, because crossing the size-class boundary rebuilds
the shell, and view models living inside it would take the scroll position, the
filters and any half-finished tool flow with them. It also carries the two
app-wide modals (the editor cover, the settings sheet) that used to hang off
`MainTabView`.

- Compact → `MainTabView`, unchanged apart from taking the view models as
  parameters.
- Regular → `MainSplitView`, a three-column `NavigationSplitView`:
  - **Sidebar** (`MainSidebarView`): the four sections, then the archive's own
    structure. Folders are part of the `List` selection because picking one *is*
    navigation; tags are toggle rows because several can be on at once. The
    selection is derived from `(coordinator.tab, archive.folderFilter)` rather
    than stored, so a filter cleared anywhere else is reflected without a second
    source of truth.
  - **Content**: Files grid / Tools list / ChatPDF picker / Search results.
  - **Detail**: `DocumentDetailView`, `ToolDetailView`, or the ChatPDF
    conversation.
- Column widths are set narrow on purpose (sidebar 200–300, content 300+): with
  the defaults the system dropped to two columns on an iPad held in portrait.

`MainTab` stays the single source of truth for the section, so deeplinks,
`runTool` and `goToArchive` work in both shells with no special casing.

### What changed in the existing screens

- `FilesView`, `ToolsView`, `ChatPdfSelectionView`, `GlobalSearchView` now take
  their view model as an `@ObservedObject` instead of resolving it themselves,
  and take an optional `selection` binding. Bound (split layout) means a tap
  selects rather than opens, the folder/tag chip bar is dropped (the sidebar has
  it), and the Tools catalog renders as rows — a column that fits one tile per
  row is a list, not a grid.
- Document actions were pulled out of `FilesView` into `DocumentActionsMenu`
  (`DocumentActions.swift`), shared with the detail pane's toolbar menu.
- `Pdf.documentId` is the new selection identity. `Pdf`'s synthesized `Hashable`
  follows its `PDFDocument` instance, so a document re-read after a refresh never
  equals the copy a view holds; the store URI does survive. It is the same string
  the widget and the deeplinks already used.
- `PdfEditView` reflows on regular width: thumbnails become a vertical rail
  (`pageRailView`), and the four frequent edits move from the floating glass bar
  into the toolbar. The phone layout is untouched.
- The signature sheet is 620×560 on iPad (was 400×385 everywhere), the canvas
  inside it 260pt tall, and `PencilKitView` gains an optional `PKToolPicker` plus
  the `.default` drawing policy — which is what gives palm rejection while a
  Pencil is paired.

### Keyboard, drag and drop, pointer

- `PdfProCommands` (attached to the `WindowGroup`) holds the app-wide shortcuts:
  ⌘N / ⇧⌘S / ⇧⌘P / ⇧⌘I for new documents, ⌘1–⌘3 and ⌘F for the sections, ⌘, for
  settings. All of them no-op during onboarding and while the editor is open, so
  a shortcut never moves the ground behind a modal. Contextual ones live on the
  control they belong to: ⌘S (save, editor), ⌘E (edit, detail pane), ⌘↑/⌘↓ (page
  turning, in the editor's More menu so they are discoverable), ⌘↩ (start, tool
  detail).
- `DocumentDropDestination.swift` accepts PDFs and images dropped from other
  apps, on the Files grid and on the ChatPDF well — which advertised "drop your
  PDF here" without accepting a drop. One PDF is taken on its own; a batch of
  images becomes one document with a page each. `PdfFileTransfer` handles the
  other direction: dragging a card out produces the same file the share sheet
  would.
- Hover effects on document cards and rows, tool tiles and rows, quick actions,
  the ChatPDF well and the editor's rail cells.

### Watch out

- **Nothing that needs a tap, a key or a drag has been exercised** — the
  simulator takes no such input from the CLI, and the machine this was built on
  has no accessibility permission to drive it. Everything below compiles and the
  layouts around it are verified from screenshots, but a device or a manual
  simulator session is still owed for: drag and drop in both directions, every
  keyboard shortcut, the Pencil tool picker, and the sidebar's tag rows and
  "Folders & Tags" row (they are `Button`s inside a `List(selection:)`, which is
  the usual pattern for a non-selectable row but is worth a tap to confirm).
- Same for **landscape**: everything below was checked on iPad Pro 13" in
  portrait only, for the same reason. Portrait is the tighter case for a
  three-column split, so landscape should be safe, but it is unverified.
- The tool picker lets the user pick any ink colour, including one that will be
  invisible on a white page. The default is still black.
- `GlobalSearchView` deliberately keeps its own `ArchiveViewModel`: it drives
  `searchText`, and sharing the instance would leave the Files grid filtered by
  whatever was last typed into search.
- New debug hook: `debugSelectDocument -bool YES` previews the first document in
  the iPad detail column at launch, since the simulator cannot be tapped.

## Phase 9 (2026-07-26) — one way to compress

The app had two things called compression. The Compress tool from phase 7 does
the work and shows it: it compresses for real while the sheet is open, reports
the before/after, and refuses to hand back a heavier file. The older
`PdfCompressionPickerView` in the editor stored a `CompressionOption` on the
document, and that option was applied in exactly one place — `applyPostProcess`,
on the way into the share sheet.

Which meant the picker promised something the app never showed. Pick "Maximum
compression", save, and the document in the archive weighs precisely what it
weighed before; the only way to see any effect was to share the file and look at
what came out. Worth noting that `PdfDefaultCompression`/`PdfDefaultMarginsOption`
are `.noCompression`/`.noMargins` and `applyPostProcess` returned early when both
were at their default, so for every document that never went through that picker
the whole path was already a no-op.

What changed:

- The editor's "Compress" menu item now runs the Compress tool on the open
  document (`pdfCompressViewModel.run(pdf:onCompleted:)`), so there is one
  compressor in the app and it is the one that reports what it did. It still
  saves a `-compressed` copy rather than replacing the open document — that is
  deliberate, the original is the way back from a preset that went too far.
- `PdfCompressionPickerView` is gone, along with `PdfEditViewModel.compression`
  and `compressionShow`.
- `processToShare` no longer takes an `applyPostProcess` flag and no longer
  re-processes anything: **what you share is what you saved**. The flag is gone
  from `PdfShareCoordinator`, `sharePdf` and `PdfFileTransfer` too. As a side
  effect sharing from the archive is also cheaper — it used to round-trip the
  document through `PDFDocument` on every share.
- `PDFUtility.applyPostProcess` is deleted, and with it the six tests that
  covered it (suite 201 → 195). `pageIsImageHeavy` stays — `PdfCompressUtility`
  uses it. `PdfOverlayUtility` is untouched and still backs page numbers,
  watermark, flatten and invert.
- Orphans removed: `MarginsOption.horizontalMargin`, `CompressionOption.quality`,
  `K.Misc.PdfMarginsColor`, `Pdf.updateCompression`, `Pdf.updateMargins`, the
  `compressionPicker` screen and `compressionOptionChanged` analytics events, and
  the dead `MarginsOption.iconImage` the redesign had left behind in
  `PdfEditView`.
- The Compress sheet is bounded and centred on a regular-width window; full-width
  rows left two thirds of an iPad empty.

### Watch out

- **The `compression` and `margins` attributes stay on `CDPdf`.** Nothing writes
  them any more and `Pdf` has no setters for them, but the store is CloudKit-backed
  and dropping a column is not worth a migration. They are read back so old
  documents round-trip unchanged.
- **Behaviour change for old documents**: anyone who had used the picker will now
  share the document as stored, i.e. bigger than before. There is no migration
  and no notice — the alternative was keeping a feature whose effect the app
  never showed.
- The one line not exercised is `handleEditAction(.compression)` → `run(...)`:
  reaching it needs a tap on the editor's More menu, which the CLI cannot do, and
  `PdfEditStartAction` has no `openCompression` case to drive it with. The tool
  itself was verified on iPad through `debugRunTool -string compress`.

## Phase 10 (2026-07-26) — Spanish, and the Italian long tail

The catalog is now EN / IT / ES, 572 keys, every one translated in all three.

**Italian was not actually complete.** 11 keys had been extracted by Xcode but
never translated — the interpolated long tail the backlog had been carrying for
months (`Page %lld`, `Range %lld`, `%@: %lld`, `Welcome in %@:\nConvert & Edit`,
`Enter the password of\n%@\nin order to import it.`, `From page number`,
`To page number`, …). No Xcode pass was needed: they were already in the file,
just empty. Phase 8 had added 12 more keys that were not in the catalog at all —
those were extracted from the source by hand and translated.

**Spanish is new**: `es` added to `knownRegions`, every key in the app catalog
and all 11 in the widget's own catalog. Both plural keys (`%lld documents`,
`%lld pages changed`) carry proper `one`/`other` variations rather than a single
form.

Terminology worth keeping consistent if more strings are added: *archivo* for
file, *carpeta* / *etiqueta* for folder / tag, *marca de agua* for watermark,
*censurar* for redact (what Acrobat uses in Spanish), *aplanar* for flatten,
*desinfectar* for sanitize, *combinar* for merge, *Ajustes* for Settings and
*Listo* for Done (both what iOS itself uses in Spanish).

### Two source-level fixes that came out of this

- `Text("")` in `ChatPdfView` — a scroll anchor — was being extracted as a blank
  catalog key no translator could act on. It is a `Color.clear` now, and the
  empty key is gone from the catalog.
- `Text("·")` in `DocumentTileView` is `Text(verbatim:)`, so a lone separator
  stops being offered for translation.
- The tool detail pane's button was `String(localized: "Start")`, which is the
  onboarding's Get-started key. There it means "begin", here it means "run this
  tool", and the two want different words in Italian *and* Spanish — so the
  button has its own `Run` key (Avvia / Iniciar).

### Verification

Built and run on the iPad simulator under `-AppleLanguages "(es)"` and `"(it)"`:
sidebar, tools column and detail empty states are correct in both. The compiled
bundle carries `en.lproj` (556), `it.lproj` (566) and `es.lproj` (566). A script
checked, for every key, that the placeholder set (`%@` / `%lld` / `%%`, positional
or not) and the newline count match the source — a dropped placeholder is a crash
at format time, and a dropped `\n` silently reflows a two-line title.

### Watch out

- `en.lproj` has 10 fewer keys than the other two. That is expected: those keys
  have no explicit `en` localization because the key *is* the English text.
- Nothing here was seen on a device, only in the simulator. Spanish is more
  verbose than English in places (`Clockwise` → *En el sentido de las agujas del
  reloj*); worth a look at the tightest labels — the editor's More menu, the
  compression presets, the paywall — on a small screen.
### Device-specific copy that phase 8 had made wrong

Two strings still assumed the app was iPhone-only, and both are fixed:

- The onboarding claim is now **"The PDF editor for iPhone and iPad"** —
  *L'editor PDF per iPhone e iPad* / *El editor de PDF para iPhone y iPad*. Note
  the Spanish uses **y** rather than *e*: the *e* exception only applies before a
  word that actually starts with an /i/ sound, and *iPad* is /ai̯/.
- The camera-permission alert said "go to **your phone** Settings". It now says
  "go to Settings", which is also better in Italian and Spanish, where the system
  app has a name of its own (*Impostazioni* / *Ajustes*) that reads worse with a
  device bolted in front of it. Both variants of that message — the scanner one
  and the camera one — were updated.

And the reason the camera one mattered twice over: `CameraError.title/message/
dismissText/confirmText` returned **plain `String` literals**, which reach
`Text(_ verbatim:)` through the `String` overload. The entire camera alert was
therefore showing in English in every language, catalog or no catalog. They go
through `String(localized:)` now, and the missing keys (`No Permission`, `Camera
unavailable`, the take-pictures variant) were added. Catalog: 572 keys.

If more `String`-typed user-facing text turns up, the same trap applies — a
`Text(someString)` never localizes. That is what the "localization lint" item in
the backlog is for.

## Phase 11 (2026-07-26) — a localization lint, and the 27 strings it found

`pdfexpert/Scripts/localization_lint.py`. Run it with `bundle exec fastlane lint`;
the `test` lane runs it first, because there is no point compiling if a string was
left untranslated. Output is in Xcode's `file:line: error:` format, so it also
works wired up as a build phase. Exit 0 clean, 1 otherwise.

Three checks, each of which had already caught a real bug before it was written:

1. **untranslated-key** — a literal in a construct that localizes (`Text("…")`,
   `String(localized:)`, `Label(_:systemImage:)`, `.navigationTitle`, `.alert`,
   `Section`, `CommandMenu`, `.accessibilityLabel`, `prompt:`) with no catalog
   entry, or an entry missing a language. This is what phase 8 shipped twelve of.
2. **raw-string-text** — a `return "Some sentence"` not wrapped in
   `String(localized:)`. This is the `CameraError` trap from phase 10: a `String`
   reaches `Text` through the verbatim overload and never localizes.
3. **broken-translation / empty-key** — a translation whose placeholder set or
   newline count differs from the source, and blank catalog keys.

### What it found on the existing code

27 strings, all of them user-facing text that was appearing in English in every
language — **and eleven of them already had Italian and Spanish sitting in the
catalog, unused**, because the code never looked them up:

- `SharedErrors.swift` — most of the app's error messages (`Wrong Password`,
  `Your pdf is already protected`, `Your pdf has no pages.`, the seven copies of
  `Internal Error. Please try again later`)
- `ChatPdfManager`, `PickedImage`, `SubscribeViewModel`, `PdfEditViewModel` —
  the same shape, one enum each
- `PdfSignatureCanvasView` — the signature sheet's three tab labels
  (`Drawing` / `From Image` / `From Camera`)
- `SubscriptionViewUtility` — `FREE TRIAL for \(duration)`, now the
  `FREE TRIAL for %@` key

Ten keys had to be added; the rest just needed `String(localized:)`. Note that
`PdfExtractError` had been doing it correctly all along — the pattern was right
there, the other enums had simply never been updated to match. Catalog: 582 keys.

Two blank keys also came out of it: `Button("")` in `PdfPageRangeEditorView` was
an invisible hit area, now a `Color.clear` label.

### Watch out

- Check 2 is a **heuristic**: it fires on strings with a space that start with a
  capital, because anything looser drowns in symbol names and analytics values.
  A single-word label (`"Drawing"`) slips through — that one was caught by eye,
  not by the lint. If you add a one-word user-facing string, the lint will not
  help you.
- `LocalizedStringResource` and `LocalizedStringKey` returns are skipped: a bare
  literal in those already resolves against the catalog. That is why the App
  Intents' error strings are not flagged.
- Exceptions go in `ALLOWED_FILES` (currently just the analytics descriptions,
  which are wire values dashboards read) or `ALLOWED_RAW_STRINGS`, both with a
  written reason. There is deliberately no way to silence checks 1 and 3 — a
  literal that should not be translated belongs in `Text(verbatim:)`, which the
  lint ignores by design.
- The lint was tested against a probe file with three failing and three passing
  cases before being trusted; if you extend it, do that again. A lint that
  reports nothing looks identical to a clean codebase.
