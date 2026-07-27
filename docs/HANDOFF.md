# Handoff — PdfExpert / PDF Easy

Updated 2026-07-27. Read this first when picking the work up in a fresh session.

## Where things stand

Twenty-three phases of work sit on `main`. The app is feature-complete for the release
that is planned: iPhone and iPad, EN / IT / ES, 637 catalog keys, 315 unit tests
and 4 UI tests green, and a localization lint in CI. Every phase below was built and tested on
**Xcode 26.6 / iOS 26 SDK** (`Staging Debug`, iPhone 17 Pro and iPad Pro 13"
simulators).

**`main` is pushed and in sync with `origin/main`** as of `e20214f` — phases 6
through 11 went up together, since none of them had been pushed before.

**The one thing to know before anything else: nothing in phases 4–11 has been
tried on a real device.** Everything was verified from simulator screenshots, unit
tests and scripts. Anything needing a tap, a hardware key, a drag, an Apple Pencil
or a real purchase is unverified. The accumulated checklist is the memory note
`device-test-setup`, and each phase below has its own "watch out".

## How to resume

1. `git checkout main && git pull`.
2. Drop a real (or placeholder) `pdfexpert/Resources/ProjectInfo.plist` in place,
   or nothing compiles. See "Build / project notes".
3. `bundle exec fastlane lint` — should say `clean`. For the tests use
   `xcodebuild test -project pdfexpert.xcodeproj -scheme "PdfExpert Staging"
   -configuration "Staging Debug" -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
   CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES CODE_SIGNING_ALLOWED=YES`:
   the `fastlane test` lane passes `CODE_SIGNING_ALLOWED=NO` and the test host
   crashes on launch without the iCloud entitlement (see phase 12's "watch out").
   Both should be clean before you touch anything.
4. Pick the next task. **The only things standing between the app and a release
   are not code**: deploying the CloudKit production schema, the real API keys,
   the Firebase `stirling_api_enabled` flip, and the device test run. See
   "Remaining" and the `open-work-backlog` memory note.
5. Land each unit as its own small change against `main`.

## The phases, in order

Sections below, newest last. Phases 1–2 predate this document; what they left
behind is in "What landed on `main`".

| Phase | What |
|---|---|
| 3 | On-device round 2, PSPDFKit removed |
| 4 | UI rebuilt on iOS 26 / Liquid Glass |
| 5 | App Intents, Siri shortcuts, Home Screen widget |
| 6 | Folders and tags in the archive |
| 7 | Compression presets and PDF comparison |
| 8 | Dedicated iPad interface |
| 9 | One way to compress (the old picker removed) |
| 10 | Spanish, and the Italian long tail |
| 11 | A localization lint, and the 27 strings it found |
| 12 | The rest of the tool sheets on a wide window |
| 13 | The document proposes its own name |
| 14 | A scanner of our own: camera, review, Scanner tab, Shortcuts |
| 15 | The editor restructured: one tool list, a page bar, pushed tools |
| 16 | The last five tool flows pushed too, and one paywall for all of them |
| 16b | A UI test bundle: the editor's tools and the back button, tapped |
| 17 | The editor stops freezing: pages are drawn in the background |
| 18 | Rotate the whole document — the Shortcuts action does something again |
| 19 | The editor stops hoarding: page images are drawn on demand (A5) |
| 20 | Branch removed: one analytics platform, no attribution SDK |
| 21 | AppleAttribution in: Search Ads attribution, install id on the purchase |
| 22 | Facebook removed: the last linked-but-idle SDK |
| 23 | A6: the folder spelled right, 39 headers, and the three missing tests |

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

### Release blockers — none of them are code

1. **Deploy the CloudKit production schema.** `searchableText` (phase 2), the
   `Folder` / `Tag` record types with their relationships (phase 6), and
   `sourceType` on `Pdf` (phase 14 — it is what the Scanner tab filters on). The
   dev environment creates these on its own; production does not, and the app
   will fail to sync without them.
2. **Real keys in the local/CI `ProjectInfo.plist`**: `OPENAI_API_KEY` (ChatPDF),
   `STIRLING_API_KEY` (the six conversion tools).
3. **Flip `stirling_api_enabled=true`** in Firebase Remote Config, or those six
   tools stay invisible in the catalog.
4. **The device test run.** See the `device-test-setup` memory note — it is the
   accumulated checklist for phases 1–11, and it needs an iPad as well as an
   iPhone since phase 8. **Phase 14 raises the stakes here**: the scanner's
   camera has never run against real frames, and a simulator cannot run it.

### Needs on-device / behavioral verification (the code is in, the behavior isn't CLI-checkable)
- **A5/A5b** — open & dismiss each modal (PdfEdit: camera, scanner, signature,
  fill-form, fill-widget; Home: camera, scanner), the camera/scanner
  convert-on-dismiss, the `startAction` auto-open, and the no-widget alert. Watch
  for a sheet that fails to present because another is still dismissing (that was
  the reason for the removed `Task.sleep`).
- **The scanner (phase 14)** — the whole camera half: does the outline sit on the
  page, does the automatic shutter fire when the phone settles and not before,
  does the flash reach the paper, does the crop from the still line up, is a
  filtered page legible, does an iPad in landscape come out upright. Then the
  ends: Save as PDF lands in the Scanner tab, Save as images lands in Photos
  after the add-only prompt, and the Shortcuts actions run against real files.
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
- ~~**A5 page-model unification**~~ — **done in phase 19**: `pageImages` +
  `pdfThumbnails` became one `pages: [EditorPage]`, and the full-size images are
  drawn on demand around the page on screen. Still wants a device run on a real
  scan (see the phase's "watch out").
- ~~**Localization interpolated strings**~~ — **done in phase 10.** No Xcode
  extraction pass was needed in the end: the keys were already in the catalog
  (`Page %lld`, `%lld of %lld`, `Welcome in %@:\nConvert & Edit`, …), they had
  simply never been translated.
- ~~**`AppleAttribution` package**~~ — **done in phase 21**, and as the real
  integration this entry always asked for rather than the unused dependency the
  old branch added: configured in `AppDelegate`, purchases forwarded, install id
  on the transaction. It needs `APPLE_ATTRIBUTION_API_KEY` in `ProjectInfo.plist`
  to do anything — see the phase's "watch out".

### Backlog (from the old `NEXT_TASKS.md`)
- Extend the test suite: append paths, `PdfScanUtility` progress, `Pdf.shareData`.
- ~~A6: header cleanup + rename the misspelled `pdfexpert/Applicaction/` →
  `Application/`~~ **done in phase 23**, tests included. What is left of A6 is the
  async/await modernization, deliberately not done — see that phase.
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

## Phase 12 (2026-07-26) — the rest of the tool sheets on a wide window

Phase 8 gave the iPad a shell and phase 9 bounded the Compress sheet. Every other
tool sheet was still a phone layout at iPad size: a row of controls stretched
across the whole window, a label a hand's width from its own switch, and two
thirds of the glass empty. This phase applies the same treatment to all of them.

### The rule, in one place

`DS.Layout.readableWidth` (620pt, the same number the signature sheet already
used) and `View.readableColumn(_:)` in `DesignSystem.swift`. It is a plain width
cap plus a centring frame — deliberately **not** a size-class branch, because a
phone never reaches the cap, so the phone layout is untouched by construction,
and a window resized in Stage Manager crosses no threshold. Apply it to the
content *before* the background, so the background still covers the window.

`PdfCompressView` was rewritten to use it instead of its own `620` literal.

### Where it went

| Sheet | Note |
|---|---|
| `PdfCompareSetupView` | whole column |
| `PdfCompareResultView` | the mode picker and the text diff. The **visual** diff is deliberately left full-width: reading it means telling two renderings of a page apart |
| `PdfRedactEditorView` | the hint and the page controls only — the page itself keeps the window, because drawing a box over the right words is precision work |
| `PdfPermissionsView` | whole column |
| `PdfWatermarkView` | whole column |
| `PdfPageNumberView` | whole column, plus the 3×2 position grid capped at 340pt **on regular width only** — the mock-ups are a picture of one page's corners and only read as that side by side, and a phone is already narrow enough to leave alone |
| `PdfMetadataView` | whole column (form + footer button) |
| `SuggestedFieldsFormView` | whole column |
| `PdfMarkdownImportView` | whole column — Markdown is prose |
| `PdfPageRangeEditorView` | whole column |
| `PdfSortView` | whole column |
| `PdfPageSelectionView` | capped at **420**, not 620: a row is a number and a thumbnail, so a wide one is mostly empty space with the selection highlight stretched across it |

Left alone, on purpose: anything presented as an `alert` or through `formSheet`
(the export format picker, the password prompt, the web-import prompt, the
Convert and Stirling disclosures) — the system already bounds those on iPad — and
the page-centric views (`PdfReaderView`, `PdfImageViewerView`, `PdfFillFormView`,
`PdfFillWidgetView`, `PdfSignatureView`), where full width is the point.

### Getting the screens on screen

The sheets could not be inspected before because reaching them needs taps a
simulator will not deliver. The debug hooks now cover them:

- `debugRunTool` gained `redact`, `permissions`, `split` (opens the page-range
  editor), `markdown`, `sort` (three copies of the test document stand in for a
  multi-file pick) and `read`, alongside the existing `compress` / `compare`.
- `debugEditorSheet` (`pageNumbers` / `watermark` / `metadata`) opens the
  editor's own sheets, which otherwise sit behind the More menu.
- `debugReaderSheet=pages` opens the reader's page picker.
- `debugPremium` makes `StoreImpl` report a subscription, so the premium sheets
  open instead of the paywall. It is honoured in `subscriptionStatusToIsPremium`,
  which every path to `isPremium` goes through, and sent once in `init` because
  the startup refresh can throw before publishing anything.

All `#if DEBUG`. Set them with
`xcrun simctl spawn booted defaults write <bundle-id> <key> …` — **not** as
launch arguments: `debugInitialTab` is read with `object(forKey:) as? Int` and
the argument domain hands back a string.

### Verification

Each of the twelve sheets was screenshotted on an iPad Pro 13" simulator
(1032pt wide, portrait) and read back; permissions, page numbers and page
selection were also shot on an iPhone 17 Pro to confirm the phone layout did not
move. 195 unit tests green, localization lint clean.

### Watch out

- **`bundle exec fastlane test` fails in this environment** and it is not the
  code: the lane passes `CODE_SIGNING_ALLOWED=NO`, which strips the iCloud
  entitlement, and the test host crashes in `NSPersistentCloudKitContainer`
  before the runner connects (the same trap phase 4 documented under "Build /
  project notes"). Verified on a clean `main` too. The suite passes with
  `xcodebuild test … CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=YES
  CODE_SIGNING_ALLOWED=YES`. Fixing the lane is a one-line change nobody has
  made yet, because it also affects CI.
- **A CLI build rewrites `Localizable.xcstrings`** (Xcode's string extraction
  reformats the file, adds the App Intents keys and a blank key). It looks like a
  16k-line diff and turns the lint red. Discard it — `git checkout --
  pdfexpert/Resources/Localizable.xcstrings` — unless you actually added strings.
- Landscape was not shot: `osascript` cannot send the rotate keystroke without
  Accessibility permission. A wider window only widens the margins — the cap has
  no thresholds — but nobody has looked at it.
- `PdfPageSelectionView` numbers its rows from **0** (`Text("\(index)")`) while
  the reader says "1 of 3". Pre-existing, left alone: it is a one-line change but
  a visible one, in three languages, and not what this phase was about.

## Phase 13 (2026-07-26) — the document proposes its own name

The last open item from the phase-4 roadmap. A scanned or converted document was
saved as `File-07-26-2026` unless the user went and typed a name, and almost
nobody does.

**Proposed, never applied.** The editor reads a name off the document and offers
it in a bar under the toolbar: *Suggested name — Lorem ipsum — [Use] [×]*. Doing
nothing leaves the document named exactly as it was. Applying a name for someone
is a name they then have to go and undo, and the app cannot tell a bad guess from
a good one.

### Where the name comes from — `PdfTitleUtility`

Two sources, in order:

1. **The `Title` metadata field**, when it holds something a person would
   recognise.
2. **The first page's typography**: of the first 25 lines, the one set in the
   largest type wins; ties go to whichever is higher on the page. On an invoice, a
   contract, a letter and a report that line is the title, which is a far better
   signal than "the first line" — that is usually a letterhead or a date.

Both sources go through the same plausibility check, because both produce the
same junk. Rejected: file URLs and paths, placeholders (`untitled`, `document`,
`sin título`, …), lines with no letters at all (dates, rules, page numbers),
anything over 140 characters (a body paragraph), and **filename-shaped strings** —
no spaces plus an underscore, a dash or a digit (`file-sample_100kB`,
`IMG_2026_07_26`, `scan0001`). That last rule came out of the simulator: the
bundled test document carries `file-sample_100kB` in its title field, and the
first version of this proposed it. A genuine one-word title (`Contratto`) carries
none of those marks and survives.

Shaping: `Microsoft Word - Contract.docx` → `Contract` (the prefix and the known
office extensions are stripped), whitespace collapsed, characters a filename
cannot carry replaced — **after** the plausibility check, since stripping the
slashes out of a URL first would turn it into a perfectly good-looking title —
and a cut to 60 characters on a word boundary.

### When it is offered

`PdfEditViewModel.refreshFilenameSuggestion()`, gated on
`Pdf.isGeneratedFilename` — the offer only appears while the document still
carries the app-generated `File-MM-dd-YYYY`. A document already called something
is called that on purpose. Recomputed on appear, on `updatePdf` and on page
append, because the text can arrive after the document does: a scan has nothing
to read until OCR has run. Dismissed once, gone for that editing session.
`useSuggestedFilename()` writes through the same published property a manual
rename uses, so the close warning and the `pdfRenamed` event stay in one place.

### Verification

21 new unit tests (**216** total, up from 195): the utility's two sources, every
rejection rule, the shaping, and the view-model gate (offered / not offered when
already named / applied / dismissed). Seen on an iPhone 17 Pro and an iPad Pro
13" simulator through the new `debugRunTool -string editor`, which opens the
editor on an unnamed copy of the test document — `Pdf(data:)` keeps the generated
filename, which is what the offer keys off. Catalog at **585** keys: `Suggested
name`, `Use`, `Dismiss`, all three translated. Lint clean.

### Watch out

- The heuristic reads `page.attributedString` for the **first page only**, so its
  cost does not grow with the document. It has not been measured on a page with
  thousands of runs.
- A scanned document has no text until OCR runs. The suggestion appears after
  it, through the `updatePdf` path — that is by design, but it means the bar can
  turn up a while after the document opened.
- Nothing renames documents already in the archive; this is the editor only. A
  bulk "rename my old scans" pass would be a different feature, with different
  risks.
- The bar sits in a `safeAreaInset(edge: .top)` on the whole editor, so on iPad
  it centres on the window rather than on the page area beside the thumbnail
  rail. It reads fine; it is not perfectly aligned with the page.


## Phase 14 (2026-07-26) — a scanner of our own

Scanning was `VNDocumentCameraViewController`: Apple's screen, Apple's shutter,
Apple's idea of a filter, and no way in between the capture and the PDF. It is
now a camera the app owns end to end, with its own tab.

### The pipeline

`ScannedPage` (`Models/Entities/ScannedPage.swift`) is the unit: the untouched
capture plus three edits — a `ScanQuad` (where the page is), a `ScanFilter`, and
a `ScanRotation`. **Nothing is ever flattened into the capture.** Every render
re-derives from the original, so a crop can be redone, a filter swapped, a page
un-rotated, at any point before Save and without generation loss.

`ScanImageProcessor` turns one into pixels, always in this order: straighten
(`CIPerspectiveCorrection`) → filter → turn. Filtering first would measure
contrast over the table the page is lying on, and `CIColorThresholdOtsu` in
particular would pick its threshold from the wrong histogram. Filters are
Original / Document (`CIDocumentEnhancer`) / Greyscale / Black & white.

`DocumentDetector` is an actor over Vision's `DetectDocumentSegmentationRequest`
(the iOS 18+ Swift API, not the `VN…` one). It runs twice per page: on the video
frames, for the live outline, and again on the still, because the capture is
sharper than the preview and gives a crop that lines up with the pixels actually
being straightened.

**Three coordinate conventions meet here** and every conversion lives in
`ScanQuad`: Vision measures from the bottom left, Core Image from the bottom left
in pixels, the screen from the top left. `ScanGeometryTests` exists mostly to
keep that straight — a flip does not crash, it silently mirrors the scan.

### The camera

`ScanCaptureService` runs one `AVCaptureSession` with two outputs: a video data
output the detector watches (one detection in flight at a time, frames dropped
rather than queued) and a photo output for the page itself. It is separate from
`CameraService`, which stays what it was for Image to PDF.

The automatic shutter fires after `ScanAutoShutterSteadyFrames` (8) consecutive
detections that moved less than `ScanAutoShutterTolerance` (0.022 of the frame)
**from the previous frame** — measuring against the first frame would let a slow
drift accumulate into "steady". After a capture it disarms until the camera is
pointed somewhere else, or it would take the same page twice.

Both connections and the preview layer are pinned to
`videoRotationAngleForHorizonLevelPreview` — the *preview* angle, deliberately,
for the still too. With two angles in play there is no single mapping from a
normalized quad to the filled preview, and the outline drifts off the page.

### The screens (`Views/Scan/`)

- `ScanFlowView` owns the session: camera → review → save, plus the
  discard confirmation. Two modes: `.newDocument` (names it, saves it, offers
  Photos) and `.handOff`, which returns `[ScannedPage]` to whoever opened it —
  the editor appending pages, ChatPDF importing, the "file or scan" import sheet.
- `ScanCameraView`: outline overlay, flash, filter, automatic-shutter toggle,
  pinch zoom, tap to focus, thumbnail of the stack, shutter with the countdown
  ring drawn around it.
- `ScanReviewView`: a pager over the pages, with Adjust / Filters / Rotate /
  Delete, Retake, and a separate reorder sheet (dragging thumbnails inside the
  pager would fight the swipe).
- `ScanCropView`: four handles with a loupe, because a finger covers exactly the
  corner it is placing. It works on the **unrotated original** — that is the
  frame the corners are measured against.
- `ScannerHomeView`: the Scanner tab. Grid, search, empty state, round scan
  button.

### Where the scans live

In the same archive as everything else. `Pdf.source` (`PdfSource`, backed by a
new optional `sourceType` on `CDPdf`) marks what the camera made, and the Scanner
tab is the archive narrowed to it. Two stores would have meant two places to
search, two things to sync and two answers to "where did my file go".

**This adds a column to the CloudKit schema** — one more reason the production
deploy in "Remaining" has to happen before release.

Saving as images goes to Photos with add-only authorization
(`PhotoLibrarySaver`), which is a softer prompt than full library access;
`INFOPLIST_KEY_NSPhotoLibraryAddUsageDescription` was added to all four configs.

### Shortcuts and Siri (`Intents/ScanIntents.swift`)

Split the way scanning splits. `ScanDocumentIntent` opens the app on the scanner
— a camera needs a person — carrying a filter and an automatic-shutter flag
through `MainCoordinator.startScan(request:)`. Everything after the shutter needs
no camera, so it runs in the background on images the shortcut already has:

- `ScanImagesToPdfIntent` — images → detected, straightened, filtered PDF.
- `EnhanceScanImagesIntent` — images → straightened, filtered images.
- `ScanTextFromImagesIntent` — straighten first, then recognize (premium, like
  the other text extraction).
- `ScannedDocumentEntity` + query, `GetScanFileIntent`, `OpenScanIntent`,
  `OpenScansIntent` — the saved scans, findable and passable.

Three new zero-setup phrases in `PdfExpertShortcuts`. The old
`ScanDocumentShortcutIntent` is gone, replaced by the parameterized one.

### Verification

40 new unit tests (**256** total, up from 216) across `ScanGeometryTests` and
`ScanImageProcessorTests`: usability rules, corner relabelling, both coordinate
flips, the preview mapping, crop/rotate/filter on real pixels, page bounds and
document assembly. Catalog at **630** keys, all three languages, lint clean.
Seen on an iPhone 17 Pro and an iPad Pro 13" simulator through new debug hooks:

```
xcrun simctl spawn booted defaults write <bundle-id> debugStartScan -bool YES
xcrun simctl spawn booted defaults write <bundle-id> debugScanPages -bool YES  # two drawn pages, review screen
xcrun simctl spawn booted defaults write <bundle-id> debugScanSave  -bool YES  # …and the save sheet
```

### Watch out

- **The camera itself is untested.** A simulator has no camera: detection, the
  automatic shutter, the torch, the rotation coordinator, tap-to-focus and pinch
  zoom have never run against real frames. Everything above the shutter line is
  verified; nothing below it is.
- The steadiness thresholds (8 frames, 0.022) are reasoned, not measured. They
  are the first thing to tune on a device.
- `Otsu` on a dim page is the case to try in the black & white filter; it is also
  the one most likely to need a fallback.
- The Scanner tab reads `PdfSource.scan`, which only exists from this build on.
  Documents scanned by earlier versions stay in Files and do not appear there.
  That is intentional — there is no way to tell retroactively.
- Rendering caches by `ScannedPage.renderKey` and clears the whole cache past 60
  entries. A very long session re-renders after that, which is a stutter, not a
  bug.


## Phase 15 (2026-07-26) — the editor restructured

The editor knew about every tool it could run, four times over, and presented
them two different ways.

### What it looked like before

- `PdfEditView`: 722 lines, **53 modifiers** stacked on one `body` — seven
  `asyncView`s, a dozen alerts, a `fullScreenCover` with eight cases and seven
  `show*View` flow modifiers.
- **Four parallel lists of "what the editor can do"**: `PrimaryEdit` (4 cases),
  `EditAction` (14), `ActiveSheet` (8) and `PdfEditStartAction` (10) — while
  `ToolCatalog` already described 36 tools with title, symbol, category tint and
  premium flag. The "…" menu wrote out its own copies of names the catalog had.
- Two presentation mechanisms with nothing in common: `activeSheet` covers, and
  per-tool `show*View` modifiers each driven by a `show` flag inside its own view
  model.
- Three "…and it worked" alerts, identical down to their two buttons.

Adding a tool meant touching at least four places, and its name could drift in
each one.

### What it is now

**One list.** `EditorTool` (`Views/Pdf/EditorTool.swift`) is the single
vocabulary. Title, symbol, tint and premium badge come from `ToolCatalog`
whenever the catalog knows the tool; the enum only spells out what the catalog
has no entry for, because it is an editor gesture rather than a tool — rotating,
duplicating, reordering. `EditorToolTests` fails if a name ever drifts.

**One decision per tool about how it appears** — `EditorTool.presentation`:

| | |
|---|---|
| `.immediate` | runs now: rotate, duplicate, flatten, invert, remove blank pages, OCR |
| `.push` | a screen on the editor's stack: reorder, page numbers, watermark, document info |
| `.flow` | the tool's own view model owns the presentation |

`.flow` is the honest name for the tools that are more than a question — split,
extract, export, compress, permissions, redact — each of which is an import, a
form, a saved second document and an alert. Signing and form filling are also
`.flow`: they are direct manipulation of the page, and a navigation bar over the
canvas would be in the way. **Those flows were not converted**; that is the
obvious next slice. *(Phase 16 converted five of the six — everything but
redaction.)*

**Pushing works because of `ToolScreen`.** Every tool form used to hard-code its
own `NavigationStack` plus a close button, which is precisely why the editor
could only cover itself with them. `ToolScreen` moves that decision to the host
through `@Environment(\.isPushedToolScreen)`: modal from the Tools tab, pushed
from the editor, same view. `@Environment(\.dismiss)` needs no special casing —
it pops or closes as appropriate. Five screens were converted (watermark, page
numbers, document info, permissions form, compress editor); the diff per file is
a handful of lines.

The stack itself moved from `PdfFlowView` into `PdfEditView`, which needs to own
the path it pushes onto. `PdfFlowView` keeps the closing logic and hands it down
as `onClose`, because it — not the editor — knows what dismissing means.

**The page has its own bar.** Rotate left, rotate right, duplicate, delete,
reorder, always visible under the page. Four of those were entries in a menu of
eighteen, at the same depth as "PDF permissions"; the fifth, **duplicate, is
new** (`duplicateCurrentPage`, the one page operation the editor was missing).
Reordering is now a screen with the system's own move handles — the thumbnail
strip still drags, but a strip that scrolls in the direction of the drag cannot
move a page past its own window.

**The "…" menu is gone**, replaced by a tool panel behind a wrench: a searchable
grid grouped and tinted by the catalog's own categories, PRO badges included, and
tools that need more than one page greyed out rather than hidden.

**The alerts moved out** into `pdfEditAlerts` (`PdfEditAlerts.swift`), and the
three success alerts became one `EditorOutcome`.

Result: `PdfEditView` 722 → 517 lines, its body 53 → 15 modifiers, the rest in
five files that each say what they are.

### Verification

20 new tests (**276** total, up from 256): that every tool's name and symbol
still come from the catalog, that pushed tools have a route and non-pushed ones
do not, that every route is reachable, panel grouping and search, and the page
maths — duplicate, delete-by-index and move all edit three parallel arrays (the
document, the page images, the thumbnails) and any of them drifting shows the
wrong page. Catalog at **636** keys, lint clean. Seen on an iPhone 17 Pro and an
iPad Pro 13" simulator; two new debug hooks:

```
xcrun simctl spawn booted defaults write <bundle-id> debugEditorSheet -string tools    # the tool panel
xcrun simctl spawn booted defaults write <bundle-id> debugEditorSheet -string reorder  # the reorder screen
```

### Watch out

- **Nothing here was tapped on a device.** The bars, the panel, the pushed
  screens and the back-swipe are all verified from screenshots and tests.
- `⌘↑` / `⌘↓` for page turning used to hang off the menu. They now live on two
  invisible buttons behind the editor — present, so the shortcuts still resolve.
  Worth confirming on an iPad with a keyboard.
- The pushed tools inherit the editor's navigation bar. A tool that wants a large
  title or its own toolbar will have to say so; none currently does.
- Compress and permissions kept their modal flows but their forms went through
  `ToolScreen`, so their chrome changed slightly: a close button where compress
  used to have "Cancel".
- `EditAction` still exists, now private to `PdfEditViewModel` — the dispatcher's
  internal vocabulary. It is not a second public list, but it is still a list.


## Phase 16 (2026-07-27) — the last five flows became screens

Phase 15 left five tools covering the editor instead of being pushed onto it —
split, extract pages, export, compress and PDF permissions — and named the reason
in its own "watch out": each is more than a question, and its view model owned
where its form appeared. This is that slice.

### The one idea

Each flow's entry point was doing two things at once: *prepare* — take the
document, validate it, work out what the form starts from — and *present* — raise
the flag its own `show*View` modifier binds a cover to. Splitting them in two is
the whole change:

```swift
// what the Tools tab calls: import, then prepare + present
func split(pdf: Pdf?, onSplitCompleted: SplitCompletedCallback?)
// what the editor calls: prepare only, synchronously, and say if there is
// anything to show
@discardableResult
func prepare(pdf: Pdf, onSplitCompleted: SplitCompletedCallback?) -> Bool
```

The editor pushes only when `prepare` says yes, so **splitting a one-page
document now reports that instead of opening a screen with nothing on it** — it
used to present the range editor and then fail.

Coming back is the mirror image. Each flow already had a flag meaning "the form
is up" (`showPageRangeEditor`, `formatPickerShow`, `editorShow`, `formShow`); the
Tools tab binds it to a cover, and the editor watches it and pops:

```swift
.popWhenFormCloses(self.viewModel.editorShow)   // Views/Pdf/EditorToolScreens.swift
```

Nothing in the flows had to learn which host they got. `save()`, `cancel()`,
`confirm()` and `onFormatSelected()` are untouched.

### What landed

- **`EditorRoute` +5 cases**, `EditorTool.presentation` `.flow` → `.push` for the
  five, and `EditorRoute` is now `CaseIterable` so the "every route is reachable"
  test maintains itself.
- **`EditorToolScreens.swift`** (new): `popWhenFormCloses`, plus the five pushed
  screens. Split and extract share one generic screen over a `PageRangeFlow`
  protocol, because they are the same screen — the range editor's own view model
  is a `@StateObject` there, so a redraw cannot throw away half-typed bounds.
- **Export got a screen** rather than a sheet, and `PdfExportFormat` now carries
  its own title and symbol so both hosts describe a format the same way.
- **The page-range editor stopped saying "Split"** to someone extracting pages:
  its title and its button arrive from the caller. It also went through
  `ToolScreen`, which is what lets it be pushed at all.
- **One paywall in the editor**, not one per tool. `ocrMonetizationShow`,
  `pageNumbersMonetizationShow` and `watermarkMonetizationShow` — each with its
  own pending flag and its own `onXMonetizationClose` — are a single
  `monetizationShow` plus `pendingPremiumTool`, and a purchase resumes by
  re-running `run(tool)`. Permissions joined them for free.
- **Each flow's modifier split in two**: `show*View` (import + form + outcomes,
  for the Tools tab) and `*Outcomes` (loader, errors, success alert, and for
  export the share sheet and paywall). The editor applies only the second — the
  first would put the same form on screen twice.
- `EditAction` lost eight of its fourteen cases, three of which were already
  unreachable; `editOptionListShow` was write-only and is gone.

### Verification

12 new tests (**288** total): that the five are pushed and that signing, form
filling and redaction are not; that splitting or extracting from a one-page
document pushes nothing and reports the error; that export opens for everyone and
permissions only for a subscriber; and that a purchase carries on into the tool it
gated while a dismissed paywall opens nothing, ever. Lint clean, catalog
unchanged at 636 keys — every string this needed already existed.

Seen on an iPhone 17 Pro and an iPad Pro 13" simulator, both presentations. Five
new debug hooks:

```
xcrun simctl spawn booted defaults write <bundle-id> debugEditorSheet -string split|extract|export|compress|permissions
```

### Watch out

- **Nothing here was tapped on a device**, and the interesting half is the half a
  screenshot cannot show: confirm → pop → work → alert. Worth walking through all
  five, plus the back button mid-form.
- Leaving a pushed tool by the back button is a cancellation, wired to
  `onDisappear`. It is deliberately safe to run after a *confirmed* one too,
  because by then the work holds its own copy of the document — but that is an
  ordering argument, not something the type system enforces. Changing the order
  of the work inside `confirm()` / `save()` could break it quietly.
- Export is the exception on both counts: it gates on the format, so its paywall
  belongs to the flow rather than to the editor, and nothing is released when its
  screen goes away — the work starts after the screen is gone and reads the
  document then.
- `PdfEditStartAction.openRotate` sets `rotateOptionsShow`, which nothing has
  presented since phase 15 removed the rotate sheet. The Shortcuts "rotate"
  action therefore opens the editor and does nothing visible. Pre-existing, not
  touched here, and worth a decision: the page bar rotates in one tap now.


## Phase 16b (2026-07-27) — a bundle that taps

Every phase in this document ends with "nothing here was tapped on a device",
and the reason was structural: a simulator takes screenshots, and a screenshot
is taken by something that never touched anything. `PdfExpertUITests` closes
that gap for the editor, which is where it mattered most — a tool is chosen in a
sheet that dismisses while the screen it asked for is pushed underneath it, and
that is two presentations in one turn.

Four tests, run by the same `PdfExpert Staging` scheme as the unit suite:

- every one of the nine pushed tools opens from the panel, **and the system back
  button returns to the document** — nine screens, eighteen taps;
- the immediate tools (invert colours, remove blank pages) report back and their
  alert closes;
- a tool opened and abandoned twice in a row leaves nothing behind;
- without a subscription a gated tool shows the paywall instead of itself, and
  closing the paywall leaves the document where it was.

All four pass. The tools work, and so does the back button.

### Three things to know before writing another one

- **`XCUIElement.tap()` does not work in this app.** XCTest reports our SwiftUI
  buttons as `isHittable == false` while `isEnabled` is true, and `tap()` waits
  for hittability and gives up. A synthesized touch at the same point lands
  correctly — the archive opens the editor from a coordinate tap and not from
  `tap()`. Everything goes through the file's own `tap(_:)`, which taps the
  centre of the frame.
- **A UI test bundle installs the app fresh**, so onboarding is waiting on the
  other side of every launch and the archive is empty. Hence
  `-onboardingShown YES -debugSeedArchive YES` as launch arguments; those *do*
  reach `UserDefaults`, unlike what the older debug notes suggest.
- **Three navigation bars are in the tree at once** — the archive's behind the
  editor cover, the editor's, and the tool's. `navigationBars.buttons["…"]`
  matches across all of them, and `element(boundBy: 0)` picks whichever the tree
  lists first, which is not the one on screen. Scope every query by bar title.
  The panel's tiles carry `editorTool.<rawValue>` identifiers for the same
  reason: half of them share a title with a button in the bar under the page.

### Watch out

- The suite now runs unit *and* UI tests: about four minutes rather than twenty
  seconds. `-only-testing:PdfExpertTests` keeps the fast loop.
- The UI tests are pinned to English (`-AppleLanguages (en)`) because they
  recognise screens by their titles.
- `PdfEditViewModel.onAppear` runs **again every time a pushed tool is popped**.
  Harmless today — the start action is consumed on first use — but anything
  added there has to be idempotent. The debug sheet hook now guards against it;
  without the guard the tool reopened itself and there was no way back.


## Phase 17 (2026-07-27) — the editor stops freezing

The report was "the tools don't work, and neither does the back button", on an
iPhone, on a real document. The UI tests said otherwise, and they were right:
nothing was broken. The editor was busy.

Opening a document built two images for every page — one for the pager, one for
the strip — synchronously, inside `init`. On a text document that is free. On a
scan it is not, and the measurement is the whole story:

| | full-size pass | thumbnail pass | one page |
|---|---|---|---|
| 20-page scan | 9.5s | 9.3s | 0.45s |

**0.9s per page, on a Mac.** The cost is decoding the photograph inside each
page, and it is paid twice per page whatever size comes out — a thumbnail is as
expensive as the page. So a twenty-page scan froze the editor for eighteen
seconds before it drew anything, and `updatePdf` ran the same two passes again
after every tool that changes the document. To the person holding the phone,
an editor that ignores taps for eighteen seconds and an editor that is broken
are the same editor.

### What changed

`refreshImages()` + `refreshThumbnails()` became one `refreshPages()` that draws
on a background queue and publishes a page at a time. The editor now opens
immediately on any document, and the pages fill in as they are drawn.

Three things had to come with it:

- **`pageCount` comes from the document, not from the images of it.** The page
  bar, the tool panel and the page counter used `pageImages.count`, which is now
  zero for a moment; they would have said "you have no pages" to someone holding
  a fifty-page scan.
- **The page operations wait.** Delete, duplicate, move, rotate-all and the strip
  drag each edit three lists in step, so `canEditPages` holds them until there is
  one image per page, and the bars are disabled and dimmed until then. A page
  added mid-draw abandons the render and starts it again rather than appending
  twice.
- **`renderGeneration`** drops the results of a render whose document has since
  been replaced — which is what every tool does.

### Verification

Three new tests (**291** unit, plus the 4 UI): opening a ten-page scan returns in
under a second and reports itself as still preparing; the first page arrives
without waiting for the tenth, with the pager and the strip in step; a short
document is ready immediately. Before the change the first of those took about
nine seconds.

### Watch out

- **This has still not been done on a device**, which is where the original
  report came from. It is the same document that should be tried: a real scan of
  twenty-odd pages, opened, edited with a tool, and reordered.
- The background render walks a `PDFDocument` that the main thread must not
  mutate at the same time. Nothing does today — the mutators wait on
  `canEditPages` and the tools replace the document rather than editing it — but
  that is an invariant held by convention, not by the type system.
- Rotating a *single* page still redraws it synchronously (0.45s on a scan page).
  That is a hitch on one tap, not a freeze, and it was left alone.
- Memory is untouched: a page image is about 2 MB, so a fifty-page document
  still holds ~100 MB of images. That is the next thing to look at, and it wants
  the page model unified first (backlog item A5).

## Phase 18 (2026-07-27) — rotate the whole document

### The problem

The Shortcuts action "Rotate PDF" — and the catalog tool behind it — opened the
editor and did nothing visible. `PdfEditStartAction.openRotate` raised
`rotateOptionsShow`, a flag that since phase 15 no view was watching: the sheet
of rotation options it used to present had been replaced by the two rotate
buttons in the bar under the page. So the flag was set, nothing appeared, and
`rotateAllPages(clockwise:)` sat in the view model with no caller at all.

Two halves of the same tool, and only one of them was reachable: the bar turns
*this page*, and nothing turned *the document*. The catalog kept promising both
("Turn one page or all of them").

### What changed

- **`EditorTool.rotateAllPages`**, an `.immediate` tool, first in the "Organize
  pages" group of the panel. It runs `rotateAllPages(clockwise: true)` — a
  quarter turn right, the same direction the bar's right button turns, and three
  taps gets you back where you started.
- **`.openRotate` runs that tool** instead of raising a flag. `rotateOptionsShow`
  is gone.
- **The start action waits for the pages.** Every page operation guards on
  `canEditPages`, which is false while the pages are still being drawn — and a
  Shortcuts action arrives *before* they are. It would have been dropped on the
  floor exactly as before. `whenPagesAreReady(_:)` holds it until the drawing
  finishes; `finishPreparingPages()` is now the one place the drawing is declared
  over, so there is one place for anything waiting on it to run.

The name is the editor's own ("Rotate all pages", a key that was already in the
catalog with its IT/ES translations), not the catalog entry's: `.rotatePdf`
covers the whole of rotating, and this is only the half the page bar does not do.
It borrows the catalog's `organize` tint so it sits with its neighbours.

### Verification

Three new tests (**294** unit, plus the 4 UI): rotating one page leaves the
others alone, rotating the document turns every page, and the start action
rotates a document whose pages have not finished drawing (that test fails against
the old code by doing nothing at all).

### Watch out

- The rotation is 90° clockwise with no confirmation. It is undoable by tapping
  three more times, but there is no undo *button* anywhere in the editor.
- On a long scan the tool redraws every page afterwards (`refreshPages`), so the
  strip repopulates over a few seconds. The pages themselves are correct
  immediately.

## Phase 19 (2026-07-27) — the editor stops hoarding (A5)

### The problem

Phase 17 stopped the editor freezing; it left the other half of the same story
alone, and said so. The editor held **two images for every page, for the whole
session**: `pageImages` (the page at its own size, ~2 MB) and `pdfThumbnails`
(the strip, 80×80). Fifty pages of scan meant ~100 MB of pictures — and the pager
shows one page at a time, so about 96 MB of it was pages nobody was looking at.

Two parallel arrays plus the document is also three lists that every page
operation had to edit in step, and each of them had its own way of going wrong.
The drag in the thumbnail strip found the page being dragged by comparing
`UIImage`s, which for two identical scanned pages finds whichever came first.

### What changed

**One list, with identity.** `pageImages` + `pdfThumbnails` became
`pages: [EditorPage]`, one entry per page, carrying the thumbnail and a `UUID`.
The identity is the point: pages get moved, copied and deleted, and an index is
not a name.

**The full-size images are drawn on demand**, keyed by that identity, and only
for the page on screen and its two neighbours (`loadedPageImages`,
`pageImageWindow = 1`). Two `didSet`s drive it — the page being looked at, and
the list of pages — so there is no way to change either and forget to update what
is drawn. A page that moves keeps its image; a page that scrolls away loses it.

**The renders are safe against edits.** A page is copied on the main thread and
the *copy* is drawn in the background, so deleting or rotating a page while its
image is being drawn cannot pull the document out from under the render. Each
render carries a token; a page edited mid-render invalidates the token, and the
picture of the page as it was is thrown away instead of landing on top of the
edit.

**Opening got cheaper too**, as a side effect: the preparation pass now draws
only the thumbnails, so the photograph inside each page of a scan is decoded once
instead of twice — half of phase 17's measured 0.9s per page.

**One bug fell out of it.** `handlePageReordering` swapped two pages in the
document but *moved* the entry in the arrays. Those agree only for neighbouring
pages, so dragging a thumbnail two places along in one go showed one order and
saved another. Both are swaps now.

### Verification

Five new tests (**299** unit, plus the 4 UI): a 40-page document keeps at most
three page images drawn; walking all 40 pages ends holding three, not forty, with
the first page dropped; the neighbours of the page on screen are drawn ahead of
being reached and the page beyond them is not; a page keeps its drawn image when
it moves; and the reorder swap agrees with the document.

### Watch out

- **Not tried on a device.** The thing to try is the same scan phase 17 wants: a
  real twenty-page scan, swiped end to end (the pager should stay sharp, with at
  most a moment of thumbnail while a page is drawn), then reordered by dragging a
  thumbnail several places along, then rotated.
- A page whose full-size image has not arrived shows **its thumbnail stretched**,
  which is legible but visibly soft. On a text document this is imperceptible; on
  a scan it is a moment. If it reads badly on the device, the answer is a bigger
  thumbnail (`K.Misc.ThumbnailEditSize`), not a bigger window.
- The strip still holds a thumbnail per page — 80×80 at native scale is ~230 KB,
  so a fifty-page document keeps ~11 MB. That is the next thing, if memory ever
  comes up again.
- `EditorPage` lives in `PdfEditViewModel.swift` rather than its own file, to
  avoid a `project.pbxproj` edit for one struct.

## Phase 20 (2026-07-27) — Branch removed

### Why

Branch was one of the two analytics platforms (`AnalyticsManagerImpl` fans every
event out to a list of them) and the only attribution SDK. It was also, in this
codebase, not working: there is no `branch_key` in the Info.plist of either
environment, so every launch logged

```
[branch.io] Branch.m(346) Error: Branch init error: The Branch user session has not been initialized.
```

and nothing was ever attributed. Removing it on request.

### What went

- `BranchAnalyticsPlatform.swift` — the platform, including the one event it
  treated specially: `checkoutCompleted` became Branch's standard `.subscribe` /
  `.startTrial` with price, currency and product name.
- `AttributionManager` **and its implementation** — Branch was the whole of it.
  Its three call sites went with it: `onAppDidFinishLaunching` in `AppDelegate`
  (which called `initSession`), `onOpenUrl` in `ContentView`, and
  `onHandleATTAuthorizationStatus` in `AppTrackingTransparencyImpl`.
- The `BranchSDK` package (`ios-branch-sdk-spm`), out of `project.pbxproj` and
  `Package.resolved`.

### What stayed

- **Firebase Analytics keeps every event**, `checkoutCompleted` included — it was
  always sent to both. Nothing that was measured in Firebase changed.
- **Deeplinks still work.** Branch's own `initSession` callback was a `print` and
  a `// TODO: Implement Deeplink from here`; the app's real URL handling is
  `MainCoordinator.handleOpenUrl`, which `ContentView.onOpenURL` still calls.
- **ATT still runs.** The prompt, the `appTrackingTransparancyAuthorized` event
  and the Facebook advertiser-tracking hook are untouched; only the line handing
  the status to Branch is gone.

### What was lost, on purpose

Campaign attribution. Nothing now connects an install or a subscription to the
campaign that produced it — no Branch, no AppsFlyer, no Adjust, and
`AppleAttribution` was never integrated (see "Intentionally deferred"). If paid
acquisition is planned before release, this is the gap.

### Watch out

- If the local, git-ignored `Info.plist` files of either environment carry a
  `branch_key` or `branch_universal_link_domains`, they are now dead keys and can
  go. The tracked template (`pdfexpert/Resources/InfoTemplate.plist`) never had
  them.
- Any Branch link already in the wild (an email campaign, an ad) will still open
  the App Store, but the app will no longer read the parameters behind it.
- The Facebook SDK is still linked and still initialized in `AppDelegate`, with
  advertiser-ID collection commented out. It is the next piece of dead weight, if
  the same sweep continues.

## Phase 21 (2026-07-27) — AppleAttribution in Branch's place

### What it is

`AppleAttribution` (Jedisoft's `grogu-ios` SDK, SPM, iOS 13+, pinned to **0.3.0**
from `github.com/jedisoft-srl/grogu-ios`). It captures the AdServices token at
install and reports purchases, so revenue can be traced back to the Apple Search
Ads campaign and **keyword** that produced the install. No IDFA, no ATT prompt —
AdServices is exempt by design and the identifier is a per-install anonymous UUID.

Phase 20 left the app with no attribution at all; this fills that hole with the
package the backlog had been holding open since the beginning.

### How it is wired

- **`AppleAttributionPlatform`** — an `AnalyticsPlatform` like the Firebase one,
  registered alongside it in `AnalyticsManagerImpl`. It forwards only
  `checkoutCompleted`: `.trialStarted` when the product carries a free trial,
  `.subscribed` with revenue and currency otherwise, `.purchase` for a
  consumable. The SDK's event set is closed and the rest of the app's ninety
  events have no counterpart in it — no account to sign up for, and renewals do
  not come from the client at all.
- **`AppDelegate`** — `configure(apiKey:)` at launch, *only* if the key is
  non-empty: `configure` is idempotent and cannot be undone, so an empty key
  would leave the SDK running against nothing for the session.
- **`StoreImpl.purchase`** — the install id now rides along as the purchase's
  `appAccountToken`. This is the half that makes server-side attribution work:
  Apple echoes that UUID in every later transaction and in the App Store Server
  Notifications, so a renewal or a trial converting — both of which happen with
  the app closed — can be tied back to the install that was attributed. Set once,
  on the first purchase; Apple inherits it for the life of the subscription.
- **`APPLE_ATTRIBUTION_API_KEY`** — a third secret, through the same XOR path as
  the OpenAI and Stirling keys (`generate_secrets.sh` → `ObfuscatedSecrets` →
  `ProjectInfo`).

### One thing that reads oddly, and why

`AppleAttributionPlatform` never names the SDK's `SubscriptionPlan` type. It
cannot: the app has a `SubscriptionPlan` protocol of its own that wins the name
lookup, and qualifying it as `AppleAttribution.SubscriptionPlan` does not resolve
either, because the SDK's module name is shadowed by its own facade enum of the
same name. So the plan is built by inference — `.init` from the event case, the
period from `.init` — which is why the period is spelled out in each branch of
the switch rather than passed as a value.

### Verification

Four new tests (**303** unit, plus the 4 UI) on the one piece of judgement in the
mapping: StoreKit reports a weekly plan as either "1 week" or "7 days" and the
SDK has three buckets, so every spelling of week, month and year is pinned, and
the in-between periods (two months, two weeks) round *down* — a two-month plan
reported as annual would overstate what a keyword earns.

### Watch out

- **Nothing is sent until `APPLE_ATTRIBUTION_API_KEY` is in the git-ignored
  `pdfexpert/Resources/ProjectInfo.plist`.** It is not there today, so the build
  prints `warning: APPLE_ATTRIBUTION_API_KEY missing from ProjectInfo.plist` and
  the SDK stays switched off. That is the intended default, not a failure.
- **Only reproducible on a device**, and only against a real Search Ads campaign:
  AdServices returns no token on the simulator.
- The `appAccountToken` is set at purchase time. Subscriptions bought *before*
  this ships carry no token and cannot be attributed retroactively.
- Xcode rewrote `Package.resolved` into its current format (v3, with
  `originHash`) while resolving the new package — hence the large diff on a file
  that only gained one pin.
- App Store Connect privacy labels are the app's job, not the SDK's: it ships its
  own `PrivacyInfo.xcprivacy` with `NSPrivacyTracking = false`, but Purchase
  History / Product Interaction / Identifier still need declaring, and the
  privacy policy needs to cover attribution and purchase data. The SDK's README
  also flags GDPR as a separate legal question from Apple's policy.

## Phase 22 (2026-07-27) — Facebook removed

### Why

The same sweep as phase 20, on the last SDK that was linked but did nothing.
`FacebookCore` was initialized in `AppDelegate` on every launch, and the only
thing the app ever asked of it — turning advertiser-ID collection on or off with
the ATT answer — had been commented out:

```swift
private func updateFacebookAdvertiseTrackingSettings() {
    let enableAdvertiserTracking = self.permissionGranted ?? false
    #if FACEBOOK
//        Settings.isAdvertiserIDCollectionEnabled = enableAdvertiserTracking
    #endif
}
```

The plists confirmed it: `FacebookAutoLogAppEventsEnabled = false`,
`FacebookAdvertiserIDCollectionEnabled = false`. An SDK in the binary, an
initializer at launch, a URL scheme in the Info.plist, and no data either way.

### What went

- `import FacebookCore` and the `ApplicationDelegate.shared.application(…)` call
  in `AppDelegate`.
- `updateFacebookAdvertiseTrackingSettings` in `AppTrackingTransparencyImpl`,
  its two call sites, and the now-empty `init` that existed only to call it.
- The `facebook-ios-sdk` package, out of `project.pbxproj` and
  `Package.resolved`.
- **The `FACEBOOK` compilation condition** from all four app configurations —
  `OTHER_SWIFT_FLAGS` keeps `STAGING` / `PRODUCTION`, which is all it was ever
  carrying besides.
- The `fb735833828044207` URL scheme and the five `Facebook*` keys, from
  `InfoTemplate.plist` **and from the two git-ignored `Info.plist` files** (they
  are the ones the build actually reads; a copy of both was taken first). The
  `pdfpro` / `pdfprostaging` schemes are untouched.

### What this does not change

ATT. The prompt, the `appTrackingTransparancyAuthorized` event and the whole
`AppTrackingTransparency` service stay exactly as they were — the Facebook call
was one line inside them, not the reason they exist.

### Watch out

- If Facebook ads are ever bought for this app, the SDK has to come back for the
  install to be attributed. What is in the binary today attributes Apple Search
  Ads only (phase 21).
- The Facebook app id `735833828044207` still exists on Meta's side; nothing was
  deleted there.

## Phase 23 (2026-07-27) — A6, minus the part that was not worth doing

A6 was one backlog line covering four jobs of very different size. Three of them
are done here; the fourth is deliberately left, with a reason.

### The folder

`pdfexpert/Applicaction/` — misspelled since the beginning — is now
`pdfexpert/Application/`. Four files, and the group in `project.pbxproj` with it.

### The headers

Thirty-nine files carried the name of the project they were copied from:
`ChatAI` (15), `StoryKidsAI` (11), `SwiftCamera` (5), `FourBooks` (3),
`ForYouAndMe` (3), `FastCheckIn`, `OpenAI chat-dalle`. They now say `PdfExpert`
(or `PdfExpertTests`). Four `Copyright © … 4Books` / `dPro` lines were dropped
rather than rewritten: this app is not theirs, and inventing a new copyright line
is not a header fix. The `Created by` attributions are untouched — they are true.

### The tests

`PdfAppendAndShareTests`, twelve of them, over the three areas the old
`NEXT_TASKS.md` had been asking for. They share a theme: each is a place where
the document the user ends up with can quietly differ from the one they were
looking at.

- **Appending.** A page added to the editor keeps the strip in step with the
  document, whether it arrives as an image or as another PDF — and, the case the
  code comments warn about, a page that arrives *while the editor is still
  drawing* is not counted twice.
- **Scan progress.** `makeDocument` reports once per page, in order, ending on
  the total — including for a page that fails to render, because a bar that stops
  short of the end reads as a hang. `convertScan` starts determinate (the page
  count is known before anything is rendered) and a scan of nothing reports an
  error rather than an empty document.
- **Sharing.** What comes out of the share sheet is the document as it was saved,
  page text included — the promise phase 9 made when it stopped re-processing on
  the way out. A protected document goes out protected, and the temporary file is
  cleaned up afterwards.

Two of those tests needed `currentAnalyticsPdfInputType` set first: the append
path asserts on it, and in the app the picker always sets it on the way in.

### What was left, and why

**The async/await modernization.** There are 98 `DispatchQueue` calls in the app
and most of them are deliberate: the page rendering of phase 19, and the
one-runloop deferrals that let a sheet finish dismissing before the next thing is
presented (they replaced fixed `Task.sleep` delays, which is a fix worth
keeping). Converting them buys nothing visible and risks timing regressions that
no test would catch. The 18 completion-handler APIs are a more defensible target,
but that is a change with its own verification burden and it can be done where it
actually helps, one flow at a time.

### Verification

**315** unit tests (12 new), plus the 4 UI tests. Build and localization lint
clean.
