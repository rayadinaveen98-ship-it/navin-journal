# APK 02 — Encrypted fictional notebook management

**Checkpoint:** 14 November 2026. Stage 5 diagnostic (scripted fictional fixtures only).
**Status:** PASS in [Android debug CI 43570357719](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43570357719), merged via [PR #2](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/2), squash commit `09c72f20327e84588f3e266a60dedcd0c11e6db8`.

## Delivered

- From the approved Library visual surface, the selected fictional notebook can be renamed using **scripted** names; archived/unarchived without losing any entries; and moved into a **reversible** notebook Trash.
- Moving a notebook to Trash requires an explicit confirmation; Cancel leaves the encrypted catalog untouched. **No permanent erase control exists** in this diagnostic.
- Trashed notebooks are removed from the active switcher and listed in a separate restorable section, without exposing their journal pages in the active list.
- Restoring keeps the original journal ID, encrypted entry list, revision history, and archived state. The app does not silently switch to a restored notebook or replace any existing journal.
- The existing background `JournalEditorWorker` is the only SQLite owner. New management commands produce one acknowledged post-operation `EncryptedJournalShelf` response containing the authoritative selected journal, full catalog and selected-journal entries.
- The worker itself rejects attempts to trash the **last accessible journal**, not merely the UI. A journal being trashed or restored cannot turn an unrelated notebook's page into the selected journal.
- Journal metadata and content are held only in ephemeral Flutter memory, not plaintext SharedPreferences, local search database, network requests or index files.
- All genuine user-entered titles, journal names and diary text remain disabled in this fictional build.

## Passing automated checks

[GitHub Actions run 43570357719](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43570357719):

- Flutter/Dart analysis: **PASS**
- Encrypted editor/recovery worker contract suite: **35/35 PASS**
- Stable Flutter visual/editor widgets: **13/13 PASS**
- Real encrypted Library navigation and pure index suites: **22/22 PASS** (including 3 new journal-management widget tests)
- Read-only recovery assessment widgets: **5/5 PASS**
- Android debug APK: **compiled successfully** and uploaded as GitHub Actions artifact **14104268095**, name `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`.

The three added Flutter integration tests cover: (1) rename/archive/unarchive/confirmed Trash/cancel/restore while preserving v2+history; (2) last-journal protection enforced in both worker and UI; (3) restored archived notebook remaining read-only with no involuntary change in selection.

## Not proven / not permitted

**Do not use this APK with any real private journal data.** Physical phone/tablet input and native lifecycle, production writing, accessibility, key custody, secure archive UX, power-loss/OEM variation, long-term durable recovery, signed release and independent security assessment remain unverified. Passing Linux widget tests and compiling an Android APK are **not** proof of physical Android UX or of private-data beta readiness.

## Next development gate

Finish the realistic Writing Studio lifecycle and keyboard/input-method handling in a strictly synthetic-input test harness. Verify switching, edits, and autosave acknowledgements through Android/emulator and physical device checks before approving any real diary input.
