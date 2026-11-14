# Navin Journal — Shared Encrypted Core

**Current status (2026-11-14): fictional-fixture Linux encrypted-core plus Android API-34 native recovery engineering verified.**
**CI:** [43561573198](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43561573198) — **30/30 core tests passed**, including simulated ENOSPC and real SIGKILL, strict analysis clean; [Android 43560295633](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43560295633) — portable clean-install recovery passed with new native no-clobber publisher.

This package is the initial reusable storage/recovery engine for APK 02. It is not wired to APK 01 and is NOT approved for real private writing.

## Modules

- lib/journal_vault.dart: SQLite3MultipleCiphers whole-journal encrypted schema, journal and entry create/edit, version history, optimistic conflicts, archived/deleted records, encrypted in-db media blobs with SHA-256, consistent WAL snapshot, and independent-key v2 archive export.
- lib/staged_product_restore.dart: authenticated, staged import into a NEW encrypted directory; exact full-schema reopen verification, simulated partial-write failures and safe publication.
- lib/native_restore_publisher.dart: Linux/Android libc FFI `renameat2(RENAME_NOREPLACE)` atomic no-overwrite publish, encrypted file/directory fsync and non-secret readiness marker; rejects unsupported platforms instead of unsafe fallback. **Power-loss durability is not yet independently verified.**
- lib/restore_staging_inventory.dart: read-only bounded inventory for interrupted restore directories; no secret reads, follow-symlink behavior, automatic cleanup, or silent publication; marker presence never authenticates a journal.

## Run tests

Install the Dart SDK and resolve pub dependencies, then execute:
- dart pub get
- dart analyze --fatal-infos
- dart test --reporter expanded

The pubspec contains an explicit sqlite3mc build hook; ordinary SQLite must not be used.

## Verify these gates before real user data

- Android API-34 fictional Keystore/worker crash recovery and clean-install restoration have passed, but physical device, key custody UX and real-data signoff remain open.
- No-clobber publish with native fsync is Linux/API-34 integration tested; new Linux tests also inject simulated ENOSPC and kill independent restore processes at four checkpoints. Still require physical power-loss, actual disk-full, OEM filesystem, safe orphan ownership/resumption, migrations and user-facing ambiguous-commit recovery.
- Independently retained recovery-key onboarding, secure transfer/export flow and readable restore UX are not yet implemented for users.
- Media mutation/thumbnail/index protection, large-size bounded-memory archive streaming, secure memory/cache behavior and independent security review.
- Device/tablet accessibility, Telugu IME composition, native performance and signed stable beta.

Test fixture caps: 100 journals, 1,000 entries, 4,000 revisions, 25 attachments, 2 MiB/media, 6 MiB snapshot. These are NOT real product usage limits.

**Fictional-only APK 02 Library/debug artifacts exist; no production or real-private-diary beta has been approved.**
