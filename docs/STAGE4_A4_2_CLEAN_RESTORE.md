# Stage 4 A4.2 — Authenticated archive to staged encrypted SQLite restore

**Verified 13 November 2026:** [GitHub Actions run 43433845516](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43433845516) — **34/34 Dart tests passed**, with analyzer clean. This is an isolated **Linux fictional-data proof**, not a consumer restore feature.

## Implementation

- [Archive verification and independently held 256-bit key](../spikes/recovery_archive/lib/recovery_archive.dart) (A4.1)
- [Encrypted clean-vault staged restore](../spikes/recovery_archive/lib/staged_restore.dart) (A4.2)
- [18 staged restore scenarios](../spikes/recovery_archive/test/staged_restore_test.dart)
- [16 archive format/security scenarios](../spikes/recovery_archive/test/recovery_archive_test.dart)

The restore method **first authenticates and fully verifies** the supplied AES-256-GCM archive using its independent offline recovery key. No directory or database file is created before successful verification. The verified entries and attachments are then staged in a uniquely named **temporary directory under the same parent as the target**, using a **fresh, separate 256-bit destination database key** supplied by the caller.

For this test-only backend, SQLite3MultipleCiphers encrypts an entire database containing title, body, attachment name, MIME type, attachment bytes and SHA-256 digest in **one SQLite database**. The import is performed as one SQLite transaction. A failure at any injection checkpoint triggers rollback/close and cleanup of the temporary directory. After committing, the importer closes and **reopens** the staged encrypted database to compare exact ID/title/body, media bytes, hashes, and integrity. Only after all comparisons succeed does it rename the staged directory into a previously nonexistent destination path.

Unlike an archive copy, this restore derives **no key from the original device**. A new destination database key is separate from the independent archive-decryption key. This *does not yet connect that destination key to new-device AndroidKeyStore*; storing and recovering it securely is a production security task.

## Test outcomes

| Test category | Evidence |
|---|---|
| Correct-key restore into completely new encrypted SQLite vault | Verified |
| Multiple Telugu/English entries and binary media copied exactly | Verified |
| Destination database contains no literal plaintext sentinel or attachment name | Sampled binary test passed |
| Reopen with wrong destination key | Rejected |
| Wrong archive key / corrupted authentication tag / unknown format | Rejected before any staging |
| Existing vault directory or existing file at destination | Rejected without touching existing files |
| Seven failure checkpoints: stage/create/entry/media/before commit/after commit/before publish | Staged files cleaned up, no published destination |
| Target appears after staging but before publish | Rejected without deleting target |
| Empty archive | Valid empty encrypted vault, no bogus entries |
| Missing destination parent | Rejected without creating parents |

**Full runner:** [43433845516](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43433845516), all 16 A4.1 + 18 A4.2 test cases green.

## Critical limitations

1. **No existing-vault import/merge.** A4.2 intentionally restores only to a new, nonexistent folder. Duplicate IDs across a pre-existing consumer vault, media reconciliation, and user-visible conflict handling are not supported.
2. **Not race-free no-replace publication.** The final exists-check then directory rename can race with another process. The proof relies on a local same-parent filesystem and does not use native `renameat2(RENAME_NOREPLACE)` or a cross-process lock.
3. **No power-loss durability guarantee.** SQLite commits are synchronous FULL, but the staging directory and containing parent are not explicitly fsynced. A sudden power cut during rename or file writes is not tested. Directory promotion is not a substitute for a crash-safe platform-native transaction protocol.
4. **No Android clean-device/Keystore restore proof.** Linux tests simulate independent key custody without linking the new destination's randomly generated database key to Android Keystore. Reinstall, device replacement, media import and app-private storage remain to test.
5. **Not the product schema.** This spike has a deliberately simplified entries/media schema. It does not preserve the full target journal/revision/journal-ID/Trash/time-zone model. Migration mapping, schema compatibility, attachment references, content ordering and deletion semantics must be designed before real restore.
6. **No streamed large archive.** The bounded A4.1 format buffers archive and attachments in memory; it is limited to small fictional data and cannot back up years of private photos and writing.
7. **No password UX or independent security review.** The user-held key is a random 256-bit secret; loss is irreversible. No passphrase KDF, hardware-backed destination key management, account backup, biometric unlock, secure OS sharing, large-file tests or audited filesystem attack hardening exists.
8. **No production release.** Tests do not prove a finished journal app, live UI, physical Android device, or private-data-ready APK.

## Next acceptance gate

**A4.3:** Transfer the encrypted archive and separately retained recovery key to a fresh process/emulator install with no original device key; independently verify media/entries, create a new encrypted destination vault, verify original records and ensure no plaintext temporary files leak. A production Android app must also protect the *new* destination key and present a complete, explicit recovery workflow.

**A4 production gate remains OPEN.**
