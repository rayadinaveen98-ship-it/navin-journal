# APK 02 — Reversible encrypted per-page Trash and Restore

**Verified:** 14 November 2026 · Stage 5 functional integration · **fictional-data-only diagnostic**.

## What changed

- The encrypted Library's Reader now offers **Move page to Trash**, with an explicit **Keep page / Move to Trash** confirmation. Cancelling performs no write.
- A **Page Trash** section lists tombstoned entries in the currently selected notebook. Items are excluded from the normal Saved pages list and preset search. The page can be restored using its original ID, title/body and journal association. No permanent erase is offered.
- The existing **JournalVault** transactions handle Trash/Restore, preserving the encrypted page, revisions and monotonically advancing version. The single-owner **JournalEditorWorker** validates exact expected version and active journal ownership before any mutation; it rejects archived/trashed notebooks and cross-notebook IDs, and never silently relocates a page.
- The worker returns one authoritative, selected-journal-only `EncryptedJournalShelf` containing active and trashed entries, so Flutter cannot accidentally show entries from another notebook. No plaintext journal index, preferences mirror or network transfer was introduced.
- Journal-level rename/archive/Trash and the existing Writer/Reader flow are unchanged.

## Automated evidence

**Full Library/Android debug gate:** [Run 43577505729](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43577505729) — **PASSED**.

- Strict Flutter analysis **PASS**
- Autosave controller **46/46**
- Encrypted editor/recovery worker **35/35**
- Visual/editor Flutter widgets **16/16**
- Real encrypted Library and index Flutter tests **26/26**, including 3 new page-management cases
- Read-only recovery review **5/5**
- Android Library/Reader/Writer **debug APK built and uploaded**
- Uploaded artifact: `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`, GitHub artifact ID **14107705471**.

**Native regression:** [API-34 Android HOME/force-stop run 43577505674](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43577505674) — **PASSED**. Confirms the previous synthetic Telugu autosave/Keystore/reopen diagnostic still works with this feature branch; this is not a physical-device page Trash/Restore test.

**Merged:** [PR #6](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/6), squash commit `3bf1a1dd03261842bd9de35b11f417d3f9ee12d0`.

## Key edge cases verified

1. A fictional page saved as v1 and edited as v2 remains unchanged after Trash cancellation. Confirmed Trash advances to v3 without deleting prior history, and restoring advances to v4 in its original journal, with revisions v1, v2 and v3 preserved.
2. A page in an archived journal cannot be trashed via the Reader or directly through the worker.
3. Cross-notebook page IDs and stale expected versions are rejected; the affected encrypted page remains unchanged and integrity checks pass.

## Release boundary and next actual product work

**Do not use APK 02 for real diaries.** This is a debug test of the same encrypted data model; it is not a secure private-data beta. Physical phone/tablet UX, Telugu keyboard acceptance, independently recoverable backup/restore UX, permission/key custody design, low-storage/power-loss testing and security audit are open. No permanent deletion or production user-entered page names/content is enabled.

Next meaningful functionality: connect the already-tested portable encrypted backup/export and clean-vault restore engine to a **safe, explicit user-controlled recovery experience**. Never promise a recoverable diary until an independent recovery key/export has been demonstrated outside the original device. This is more important than adding another isolated cosmetic QA screen.
