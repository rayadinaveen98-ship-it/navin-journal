# Navin Journal — Stage 4 A2 encrypted SQLite feasibility spike

**Status:** **13/13 Dart tests PASSED** on Ubuntu 24.04 CI, 2026-11-13.  
**Use:** Fictional/test data only. **Not an Android private vault, not secure for actual diaries.**  
**Evidence:** [Passing encrypted-vault run 43408840728](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43408840728)

## Current implementation

- [Fail-closed encrypted store](lib/encrypted_journal_spike.dart)
- [Negative/positive security tests](test/encryption_test.dart)
- [CI workflow](../../.github/workflows/encrypted-store-spike.yml)

The package uses `sqlite3: 3.9.1` and its **3.x native build hook** configured for SQLite3MultipleCiphers:

```yaml
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

We currently select the `chacha20` cipher and pass **random 32-byte test key material** via `PRAGMA hexkey`. The key must be supplied by the caller and is never committed to the repository. This is NOT a production key-management design.

### Reproduce tests

```bash
cd spikes/encrypted_store
dart pub get
dart format .
dart analyze --fatal-infos
dart test --reporter expanded
```

Dart >=3.10, a host supported by sqlite3 native hooks, and Python 3 (for independent ordinary-SQLite negative checks) are required. CI used Dart 3.14.0 on Ubuntu.

### Verified test cases

1. Cipher-enabled native backend loads, database passes SQLite integrity check.
2. Exact Telugu + English + emoji content survives closing and reopening with the correct key.
3. Wrong randomly generated key is rejected; correct key still opens existing data.
4. Same sqlite3mc library without a key cannot query encrypted `sqlite_master`.
5. **Independent Python standard SQLite** cannot inspect the resulting database.
6. Raw database and WAL/SHM files (when present) contain no unencrypted fictional-text sentinel.
7. Prior revisions are stored in encrypted database pages; injected error mid-edit rolls back atomically.
8. Unknown newer schema is rejected without resetting records.
9. Creation refuses overwriting an existing vault; opening a missing file refuses silent creation.
10. Destroyed test key cannot reopen a database.
11. Existing **plaintext legacy SQLite file** is rejected, and remains readable to plain SQLite afterward.
12. Existing **empty** file is not silently converted into a vault.
13. Test key's string representation is redacted.

**Threat note:** Checking a sentinel is a targeted regression guard, *not* a cryptographic proof that every page, index, file, thumbnail, app log, or memory region is confidential.

## Design choices & non-claims

- We check `PRAGMA cipher` returns an actual value. Unrecognized SQLite PRAGMAs can otherwise be silently ignored and falsely imply encryption.
- We select the cipher and apply the key **before any regular SQL statement**.
- `PRAGMA hexkey` does not validate the key immediately; a real `sqlite_master` query forces verification. A wrong key must be rejected before any migration or journal-mode setting.
- For an existing database, the app/schema marker is verified before modifying journal settings.
- We do **not** migrate plaintext databases in place or overwrite unknown/unsupported formats automatically.
- `TestVaultKey.destroy()` zeroes its own byte array, but copies and strings created by the Dart/runtime/SQLite libraries **cannot be assumed wiped**. Do not present that method as strong production memory sanitization.
- No real private content enters these test files. Do not connect the spike to a user-facing journal yet.

## Still blocking Stage 4 A2 production approval

**Device keys and recovery**
- Android Keystore and iOS Keychain protected key wrapping, exact unlock/lifecycle semantics, biometric change, reboot, reinstall, accountless restore and lost-device outcomes.
- Separate user-controlled encrypted backup recovery: *device-only Keystore keys cannot recover a new-device archive*.
- Test key persistence and key unwrapping fail-closed on actual Android phone/tablet and iOS.

**Application confidentiality**
- Protect SQL search indexes, WAL/temp files, crash/analytics logs, screenshots/app switcher, clipboard, thumbnails and attachments.
- Enforce no unencrypted staging copy during data migration, attachment import, export or backup.
- Protect the database against wrong/missing key and malformed/corrupted data without inadvertent reset; app surface must explain recovery options.

**Native implementation**
- Verify Android/iOS native binaries, packages' own licensing, transitive licenses and third-party review.
- Exercise process kill, disk-full, OS update/reinstall, concurrency, performance, key rotation and real-world accessibility.
- Run an independent security review before claiming secure, private or end-to-end encrypted storage in public descriptions.

## Next implementation slices

- **A2.2:** Platform key-provider integration spike + safe key rotation with failure injection, *without* storing secrets in plaintext or in code.
- **A3:** Durable autosave state machine, executed against the encrypted store on target devices.
- **A4:** Versioned encrypted backup archive, authenticated integrity verification, and clean-device staged restoration.

See [Stage 4 engineering tracker](../../docs/STAGE4_ENGINEERING_SPIKE.md) and [product privacy requirements](../../docs/DATA_PRIVACY_RELIABILITY.md).

## Upstream reference

- https://pub.dev/documentation/sqlite3/latest/topics/hook-topic.html
- https://utelle.github.io/SQLite3MultipleCiphers/docs/configuration/config_sql_pragmas/
- https://utelle.github.io/SQLite3MultipleCiphers/docs/faq/faq_overview/
