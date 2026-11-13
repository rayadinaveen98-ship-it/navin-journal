# Navin Journal — APK 02 shared encrypted journal core handoff

**Date:** 13 November 2026
**State:** P0 journaling + recovery core, FICTIONAL FIXTURES ONLY.
**Verified CI:** [Navin Journal Encrypted Core P0 run 43444827657](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43444827657): **21/21 tests passed**, strict Dart analysis passed.
**APK 01:** [visual preview build run 43441554960](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43441554960): 6/6 widget tests passed, compiled Android debug APK. That preview still has NO SAVING.

## Implemented and verified in shared core

Source: [packages/journal_core](../packages/journal_core).

- SQLite3MultipleCiphers encrypted whole-journal database with an app marker and schema validation; no plaintext SQLite fallback.
- Fictional journal create, rename, archive/restore, Trash.
- Fictional entry create, edit, read, list, version history, move between journals, Trash and restore into a writable journal.
- Optimistic version check rejects stale edits. An injected exception after recording an old revision rolls back the entire SQL transaction.
- Encrypted SQLite attachment BLOBs linked to entries with SHA-256 digests (bounded fixture sizes).
- Snapshot of **all** journals, entries, revisions, Trash metadata and attached bytes captured from one WAL-consistent SQLite transaction. A test with a concurrent second SQLite writer verifies no mixed-version export.
- Export of that snapshot into independently keyed AES-256-GCM recovery archive version 2, without creating a plaintext backup file.
- Verified, test-only staging into a **new** encrypted database using a separate supplied destination key. All imported relationships and media commit transactionally, then the new vault is independently reopened and compared byte-for-byte against the authenticated source state before publication.
- Restore verified even after deleting the original fixture database and original database key.
- Wrong recovery keys, changed archive, unknown destination key, nine injected restore faults, occupied targets and a late destination collision are handled without intentional modification of existing destination files.

**All 21 journal_core tests passed on Linux CI.** The previously verified **56/56 recovery_archive tests** remain a distinct suite; do not count them as Android or app integration tests.

## Security and functionality still OPEN

This code is NOT suitable for private user data or a public release:

1. **Android app bridge:** connect real Flutter editor UI and lifecycle to shared journal operations through a background isolate. The APK 01 UI is sample-only, not connected to this core.
2. **Device-bound key protection:** integrate Android Keystore envelope lifecycle into real project installation. A3.3 actual Flutter editor emulator gate remains unresolved; A3.4 isolated Android force-stop was verified, but is not this package.
3. **Crash-safe no-clobber restore:** Directory.exists + rename has a race and is NOT a native atomic no-replace; durable file/directory fsync, disk-full tests, shutdown/power-loss and migration proof are still required. Never restore over an existing vault.
4. **Large archives:** the logical schema currently has test-only caps of 100 journals / 1,000 entries / 4,000 previous revisions / 25 attachments / 6 MiB total payload; production must use bounded-memory streaming/chunking with authenticated parts and safe media handling.
5. **Key and plaintext custody:** a Dart TestVaultKey and in-memory plaintext maps are used; memory wiping is best-effort and has not received an independent security audit. Need verified recovery-key UX, Android key retirement rules, protected screenshots/switcher/search/temporary files/thumbnail policy.
6. **Real app capabilities:** no live save UX, media picker, background autosave, app lock, export/share, search index, lifecycle recovery on the core, cloud sync, real database migration, localization, completed product navigation or tablet review.
7. **Device proof:** physical Android phone/tablet, emulator fresh install with loss of the original Keystore alias, native IME and Unicode, accessibility, Android API coverage, and signed beta release.
8. **History semantics:** attachments are linked and validated, but media mutations are not yet represented in historical revisions or user-facing Undo; this must be defined before shipping edit/remove media.

## Concrete next executable milestone

**APK 02 vertical slice A:** wire one actual Flutter Write/Read editor to encrypted journal_core through the existing Android Keystore adapter and an off-main-isolate service. Persist one **fictional test entry** through app termination/relaunch on a fresh emulator. Keep all real-data input blocked and label the build debug-only until secure recovery and lifecycle validation pass.

**APK 02 vertical slice B:** connect journals CRUD, edit/version history and Trash; implement an explicit real-storage save state; validate the crash, key and recovery boundaries.

**APK 02 private beta release gate:** independently recover complete archive on a clean Android install without original Keystore material, complete no-clobber/durability/security review, device/tablet and accessibility QA, and a stable signed build. Only then allow users to enter actual private journals.

**No new feature scope / design direction changes:** Stage 3 A+C + Midnight Archive approval remains the visual baseline.
