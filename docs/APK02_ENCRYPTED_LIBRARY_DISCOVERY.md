# APK 02 — Encrypted Library discovery and read-only history

**Status: 16/16 real-worker Flutter integration/unit tests VERIFIED on Linux. Android debug APK compilation is a separate gate.** This feature only operates on fictional fixture pages. Private personal diary input remains disabled.

## Functional changes

### Preset search and sort

The actual [APK 02 fictional Library](../preview_app/lib/fictional_journal_library.dart) now offers four preapproved test searches: All pages, Telugu (`తెలుగు`), Afternoon and Imagined. The user can sort the matching entries by Newest, Oldest or Title A–Z. Empty results show a distinguishable, non-destructive state; count labels indicate how many matching scripted pages remain.

The [FictionalLibraryIndex](../preview_app/lib/fictional_library_index.dart) operates on the records already returned by the **actual encrypted background worker**. It matches title/body case-insensitively where appropriate, excludes Trash rows, sorts timestamps deterministically with stable ID tie-breaking, and returns an unmodifiable result list. It creates **no persistent plaintext search database, SharedPreferences cache, uploaded index, network request, or indexing file**. All source records remain in app memory until the view is dismissed or refreshed.

The fictional test limitation is intentional: there is no user-typed free-text query or ability to enter genuine journal content. Later, unrestricted search requires a private-beta security and UX gate.

### Actual historical versions in Reader

The Reader's **View earlier versions** control invokes `JournalEditorWorker.readRevisions(entryId)` through the same encrypted worker. It checks basic entry/journal/version consistency, displays prior versions as explicitly **read-only**, and shows an empty-state message when there are no earlier versions. The existing current page remains unchanged.

The Reader has **no Restore previous version, Overwrite, Delete history or Publish** command. On return to Library, historical view state is cleared. Errors are generic so accidental sensitive details do not leak through exception messages.

### UI continuity

The approved Still Pages / Memory Atelier palette and Folded Page branding remain unchanged. The existing scripted Writing Studio, recovery-safety navigation, save-status states and previously verified encryption flow remain intact.

## Verified test results

[Successful real-worker Flutter CI run 43567462174](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43567462174) passed strict static analysis and **16/16** tests. It includes six pure index tests (stable timestamp/title sorting, case folding, Telugu title/body matching, Trash exclusion, no results, unmodifiable outputs) and ten real encrypted Library → Reader → Writer widget tests. Three new UI tests cover Telugu/English saved pages and preset filters, earlier version inspection without alteration, and version-1 empty history. The pre-existing seven UI tests also passed.

The [APK 02 fictional Library Android build](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/workflows/apk02-library-debug.yml) gates its debug APK on these sixteen tests as well as its existing encrypted editor/recovery and visual checks. **Do not claim a new APK artifact or physical Android UX test until verified.**

## Remaining development gates

1. Multi-journal navigation backed by the encrypted journal list; define journal switch and lifecycle rules before adding user-created journals.
2. Full consumer writing with proper input-method composition, accessibility, keyboard behavior and safe background-save states; keep private entry disabled until encryption/recovery/key custody gates pass.
3. Scalable **encrypted** full-text search on large journals, not permanent plaintext indexing, including cross-language queries and low-memory tests.
4. Secure handling of Trash, archive, exports and attachments, plus user-facing recovery-key experience and physical device testing.
5. Real Android tablet and phone UX approval, power-loss / low-storage and independent security review before signing a private beta.

**No real diary content in APK 02.** Diagnostic scripted content only.
