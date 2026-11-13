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

## A2 — Encrypted SQLite file feasibility [LINUX TESTS PASS; KEY LIFECYCLE PENDING]

**Verified CI:** [13/13 encrypted-storage tests passed on 13 November 2026](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43408840728), including Dart static analysis. **This does not complete A2's production-security gate.**

Source: [isolated sqlite3mc test package](../spikes/encrypted_store/README.md).

The Dart `sqlite3: 3.9.1` build hook selects `source: sqlite3mc` (SQLite3MultipleCiphers). The demonstration uses a freshly generated **32-byte random test key**, selects the `chacha20` cipher, supplies `PRAGMA hexkey`, rejects absent cipher support, and verifies an actual schema read before trusting the key. The application marker is checked **before enabling WAL** on existing files.

Passing tests cover:

1. Encrypted database created, reopened with the correct key, and checked for SQLite integrity.
2. Wrong key and missing key cannot read the encrypted schema; independently running ordinary Python SQLite also fails.
3. Unicode/Telugu/English/emoji survives encrypted reopen.
4. Test-only plaintext markers do not appear in raw database or WAL/SHM content scanned during active revision writes.
5. Encrypted revision history retains prior content and injected mid-transaction failures roll back.
6. Unexpected new schema is rejected without reset; cannot overwrite an existing vault or silently create a missing/empty one.
7. **Pre-existing plaintext database rejected without overwriting or erasing it.**
8. Destroyed key material fails early; test key `toString` is redacted.

**Limitations:** The test key is held in Dart memory and a temporary SQL string; clearing the input bytes does not guarantee all native/runtime copies are wiped. No device keychain, recovery code, safe key rotation, encryption of attachments/thumbnails/search indexes, actual app lock, Android/iOS build, accessibility review, or independent security assessment is provided.

**Still blocking A2 production approval:**

- Reviewed Android Keystore / iOS Keychain wrapping of the randomly generated vault key; biometric change, reboot, reinstall and device loss.
- User-controlled encrypted backup recovery **independent** of the device-only key.
- No plaintext data in logs, OS snapshot previews, attachments, search indexes, temp files or exports; targeted sentinel scans are not a full audit.
- Key rotation fault injection and recovery without silent reinitialization.
- Native dependency/license review and real device validation.

Upstream references:
- https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html
- https://utelle.github.io/SQLite3MultipleCiphers/docs/configuration/config_sql_pragmas/
- https://utelle.github.io/SQLite3MultipleCiphers/docs/faq/faq_overview/

## A2.2 — Device-wrapping-key lifecycle [PROTOCOL TESTED; NATIVE SOURCE COMPILED]

**Evidence:** [14/14 Linux key-envelope tests](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43410218147) and [successful Android API-35 Kotlin compilation](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43410753987). Detailed code/security notes: [A2.2 key lifecycle README](../spikes/key_lifecycle/README.md).

An isolated Dart coordinator creates an authenticated AES-GCM-wrapped **device-bound envelope** around the existing 32-byte database encryption key. Staged key rotation writes two aliases, verifies that the new device key unwraps the same DEK, promotes it, then removes and retires the previous alias in a separate step. Failure injection demonstrates recoverability at key checkpoints without resetting the encrypted journal database. The 14 tests use a **software AES-GCM test double**, not Android's real secure hardware.

The [Android candidate wrapper](../spikes/key_lifecycle/android/src/main/kotlin/com/navinjournal/security/spike/AndroidKeystoreKeyProtector.kt) uses AndroidKeyStore, AES-256-GCM and fail-closed alias handling. It **compiles** as an Android library but has not executed on a device or emulator. Its `setUserAuthenticationRequired(false)` is explicitly experimental; biometric/app-lock policy is not implemented. Portable recovery, iOS Keychain parity, backup exclusions, directory-fsync/multiprocess hardening, data-key rotation, and independent security review remain undone.

**A2 production gate stays OPEN.** Do not store real journal data or claim biometric/hardware-backed protection from compilation and software-model tests.

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
