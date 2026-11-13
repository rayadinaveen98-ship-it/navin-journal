# Navin Journal — Shared Encrypted Core

**Current status (2026-11-13): fictional-fixture Linux engineering tests only.**
**CI:** [43444827657](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43444827657) — 21/21 tests passed, strict analysis clean.

This package is the initial reusable storage/recovery engine for APK 02. It is not wired to APK 01 and is NOT approved for real private writing.

## Modules

- lib/journal_vault.dart: SQLite3MultipleCiphers whole-journal encrypted schema, journal and entry create/edit, version history, optimistic conflicts, archived/deleted records, encrypted in-db media blobs with SHA-256, consistent WAL snapshot, and independent-key v2 archive export.
- lib/staged_product_restore.dart: authenticated, staged import into a NEW encrypted directory; exact full-schema reopen verification; refuses known destination collisions and simulated partial-write failures.

## Run tests

Install the Dart SDK and resolve pub dependencies, then execute:
- dart pub get
- dart analyze --fatal-infos
- dart test --reporter expanded

The pubspec contains an explicit sqlite3mc build hook; ordinary SQLite must not be used.

## Verify these gates before real user data

- Android Keystore key custody + Flutter background isolate adapter + lifecycle autosave, crash recovery and full application install tests.
- Native atomic no-clobber directory publication and durability (fsync, power loss, disk full, migrations), replace-or-merge policy and key custody.
- Real clean-install restore with missing original Android Keystore alias and a separately retained recovery key.
- Media mutation/thumbnail/index protection, large-size bounded-memory archive streaming, secure memory/cache behavior and independent security review.
- Device/tablet accessibility, Telugu IME composition, native performance and signed stable beta.

Test fixture caps: 100 journals, 1,000 entries, 4,000 revisions, 25 attachments, 2 MiB/media, 6 MiB snapshot. These are NOT real product usage limits.

**No real diary content in this module yet. No APK 02 delivered yet.**
