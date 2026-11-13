# Navin Journal — Stage 4 A1 offline-storage spike

> **UNENCRYPTED. NOT A PRIVATE DIARY. DO NOT ENTER REAL JOURNAL CONTENT.**
>
> This is an isolated engineering experiment with fictional test fixtures. It
> cannot be shipped or wired into the product's private editor until encrypted
> storage and key management have been independently validated.

## Scope

This is a *pure Dart* reference store built on SQLite. It is intentionally
independent of the Stage 3 HTML prototypes and of a Flutter UI shell. Flutter
remains a **candidate**, not a finalized platform commitment.

Implementation: [lib/journal_store.dart](lib/journal_store.dart). Test fixtures
and failure injection: [test/journal_store_test.dart](test/journal_store_test.dart).

- SQLite file opens and reopens across process-like lifecycle boundaries.
- Schema migration gate via `PRAGMA user_version`; newer unknown schemas are
  rejected rather than reset.
- WAL and `synchronous=FULL`; foreign keys enabled and checked.
- Stable random IDs; user-provided strings sent as query parameters.
- Journals: create, rename, archive/unarchive, soft-delete and restore.
- Entries: create (nonempty only), read, edit/move, soft-delete and restore.
- Independent *event date* and *written/updated date* fields.
- Prior committed version saved in a revision table on each substantive edit.
- Explicit expected-version check to reject stale edits rather than silently
  overwriting newer content.
- An intentional fault-injection seam exercises atomic rollback between saving
  a prior revision and updating the current entry.
- Deleted parent journal does not silently orphan active entry records.
- Restore with missing/trashed original journal must specify a valid destination.

The package uses `sqlite3: 3.9.1`, fixed for this spike to make test
reproduction more predictable. It is **not** a final dependency approval or
a supply-chain security signoff.

## Run

Requires Dart >= 3.10 with build tools for native SQLite assets:

```sh
cd spikes/offline_store
dart pub get
dart format .
dart analyze --fatal-infos
dart test --reporter expanded
```

GitHub CI runs the same analysis and tests:
[Stage 4 Offline Store Spike workflow](../../.github/workflows/offline-store-spike.yml).

## Threat/data safety limits

**Do not use this implementation to store real content.** The database,
revision history, SQLite WAL and temporary files are **plaintext**. In addition,
it has no platform secure key store, actual autosave schedule, unsaved editor
draft protection, attachment vault, export/import, backup verification, sync,
screen capture protection, application lock or native performance profiling.

A successful transaction/reopen test is not the same as proving survival of
OS process death, low battery, full disk, device migration, encrypted backups
or the app being killed mid-typing. Those need separate tests.

## Stage 4 next engineering gates

1. **A1: SQLite transaction baseline** — automated tests of restart, Unicode,
   duplicate/conflict handling, edit revision rollback, journal/entry Trash.
2. **A2: Encryption boundary** — evaluate SQLCipher/SQLite3MultipleCiphers native
   integration, key management and metadata/WAL/temp-file exposure. Fail closed.
   No plaintext vault may be presented as production-secure.
3. **A3: Autosave coordinator** — distinguish unsaved, saving, saved and error;
   debounce edits; flush at lifecycle transitions; kill-process/reopen tests.
4. **A4: Backup/restore proof** — authenticated archive and manifest, staged
   integrity verification, safe error behavior on tamper and interrupted restore.
5. **A5: Flutter target viability** — real Android/tablet editor and keyboard
   test, memory/performance/a11y baselines and Build/App Signing check.

Until A2 is approved, any UI demonstration must use **fictional data only**.

## References

- [Data and privacy requirements](../../docs/DATA_PRIVACY_RELIABILITY.md)
- [Release acceptance matrix](../../docs/ACCEPTANCE_CRITERIA.md)
- [Stage 4 engineering tracker](../../docs/STAGE4_ENGINEERING_SPIKE.md)

SQLite upstream:
https://www.sqlite.org/lang_transaction.html
https://www.sqlite.org/pragma.html

Dart package:
https://pub.dev/packages/sqlite3
