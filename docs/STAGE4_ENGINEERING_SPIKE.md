# Stage 4 engineering proof of concept — verified progress

**Date:** 13 November 2026  
**Current stage:** 4 — engineering spike, **active**  
**Visual specification:** Approved Still Pages + Memory Atelier; Midnight Archive dark; Folded Page visual mark  
**Production app status:** **No production journaling app, APK, or encrypted vault exists yet.**

## A1 — Reliable local transaction baseline [TESTED ON LINUX]

Source: [Dart SQLite reference store](../spikes/offline_store/lib/journal_store.dart)  
Tests: [Storage test fixtures](../spikes/offline_store/test/journal_store_test.dart)  
Validation: [Successful CI run 43405129229](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43405129229)

The isolated, **unencrypted** Dart spike uses SQLite `3.9.1` on Dart stable `3.14.0` in GitHub's Ubuntu 24.04 CI. It is based on `BEGIN IMMEDIATE` transactional writes, WAL, `PRAGMA synchronous=FULL`, foreign key enforcement, versioned entry edits, explicit soft deletion and restoration.

**18/18 Dart tests passed**, plus static analysis. The tests demonstrated:

- Data readable after closing and reopening a database file.
- Exact preservation of mixed Telugu/English and emoji, long-form text, and separate event timestamps.
- Stable record IDs through changes and journal moves.
- Rejection of stale-version edits and preservation of the latest committed content, including across two SQLite connections.
- Atomic rollback after injecting an exception between saving a revision and changing the current entry.
- Empty untouched drafts are not stored as blank entries.
- Entry and journal soft-delete/restore semantics, including an orphaned entry requiring an explicit valid destination.
- Archive distinct from Trash, and unknown future schemas rejected without resetting existing records.
- SQLite integrity and foreign-key checks, and parameterized SQL preserving SQL-like text as data.

This validates **transaction semantics in an isolated environment**, not a Flutter app, background autosave, file encryption or guaranteed durability against device power loss.

## Security warning — mandatory

The reference database contains **plaintext entries and revisions**. SQLite WAL, shared-memory/temp files, filenames and copies may also expose content or metadata. Do not connect it to a private journal UI or collect real diaries. It is for generated and fictional fixtures only.

A1 does **not** meet requirements R-002 (force-stop midtyping), R-009 (full disk), R-010/011 (backup/restore), R-012 (app unlock), R-018 (new device restore), or R-020 (full readable export).

## A2 — Encrypted vault and key lifecycle [NEXT: NOT IMPLEMENTED]

Current research candidates, **not approved dependencies**:

- Dart `sqlite3` 3.x native SQLCipher/SQLite3MultipleCiphers hook integration. The older `sqlcipher_flutter_libs` package is obsolete on 3.x and **must not** be used as the implementation plan.
- `drift` 2.x for future typed queries, schema migration and background execution. Do not add before measuring this simpler reference implementation.
- Platform-backed key protection, e.g. Android Keystore and Apple Keychain through reviewed Flutter plugins. A device keystore unlock is not a portable recovery key.

Required proof before handling real content:

1. Construct an encrypted database **from first open** with an encryption-capable native library; use fresh high-entropy vault key, never a literal key committed to source.
2. Attempt to open the encrypted file with ordinary SQLite. It must fail to decode table schema and actual journal text must not be discoverable in raw database/WAL/temporary files.
3. Validate that correct key permits access, wrong/lost key fails without resetting the vault, and key lifecycle across lock, app restart and device reboot is explained.
4. Test title/body and deleted revisions, indexes/search data, media caches, thumbnails, attachments and any backup copy for plaintext leakage.
5. Simulate Android reinstall, storage migration, biometric changes and device replacement. Do not silently delete data or reset security metadata on key unwrap errors.
6. Design an independent, user-controlled **recovery process** for exported encrypted archives. Biometric unlock alone cannot restore an archive on a new device.
7. Have the encryption and key recovery design reviewed; no "secure" marketing claims until runtime evidence exists on supported devices.

Related sources (must be reverified before implementation):
- https://pub.dev/packages/sqlite3
- https://pub.dev/packages/sqlcipher_flutter_libs (obsolete with sqlite3 3.x)
- https://pub.dev/packages/drift
- https://pub.dev/packages/flutter_secure_storage
- https://www.sqlite.org/pragma.html

## A3 — Autosave coordinator [NOT STARTED]

Target is a user-visible state machine: `pristine → dirty → saving → saved` and `error/retry`. Use a bounded debounce and lifecycle flush, but never mark a draft "saved locally" until the commit has succeeded. Explicitly test force-stop between keystrokes and commits, interruptions, full disk and IME composition.

The A1 `createEntry` and `editEntry` functions are synchronous transaction calls; they are **not autosave**. The Stage 3 HTML demo's `Add to demo journal` button is also **not autosave**.

## A4 — Verified backup and clean-device restore [NOT STARTED]

Archive must provide authenticated encryption, versioned manifest, media hashes, journal/entry counts and user-visible recovery instructions. Integrity verification must be performed *before* touching the destination vault. Invalid, tampered, missing-key or interrupted restores must leave the original vault intact.

## A5 — Native Flutter/Android device feasibility [NOT STARTED]

Validate editor state, Telugu soft keyboard/IME, safe areas, app lifecycle, background SQLite isolate, performance and accessible writing at 200% system font scaling on actual devices. Confirm compiler and Android adaptive icon resources (currently Stage 3 source-only).

## Recommended order

1. Treat A1 as a verified reference model and freeze it for comparison.
2. Begin A2 encrypted storage and key recovery **before** exposing a production editor to private data.
3. Build A3 journaling autosave on the encrypted store, then validate actual Android process-kill recovery.
4. Build A4 independently verified backup/restore.
5. Integrate and benchmark A5 on Flutter/Android, then expand to iOS/tablet/desktop as warranted.

Neither the A1 reference tests nor successful Stage 3 browser checks authorize a public app release.

## Related project decisions

- [Current decision register](DECISION_REGISTER.md)
- [P0 acceptance matrix](ACCEPTANCE_CRITERIA.md)
- [Data/privacy requirements](DATA_PRIVACY_RELIABILITY.md)
- [Stage 3 UX handoff](UX_CONNECTED_JOURNEY_STAGE3.md)
