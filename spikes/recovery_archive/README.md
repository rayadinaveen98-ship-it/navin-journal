# Stage 4 A4.1 — Portable recovery archive encryption proof

**Verified:** [GitHub Actions run 43430251517](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43430251517) — **16/16 Dart tests passed**; analyzer clean.

**Status:** A4.1 **isolated archive encryption and verification proof DONE**, using **fictional journal entries and media only**. **A4 production verified backup/restore NOT DONE**.

## Implemented

- [Portable authenticated archive codec](lib/recovery_archive.dart)
- [16 automated security/format tests](test/recovery_archive_test.dart)
- [Reproducible CI workflow](../../.github/workflows/recovery-archive.yml)

A4.1 creates a fresh **random 256-bit recovery key** distinct from any Android Keystore wrapping key or database encryption key. The key can be exported as a 43-character URL-safe, base64 encoded *offline recovery secret*. The archive itself is an AES-256-GCM authenticated container using the established `cryptography` package.

The ciphertext encloses all entries, Telugu–English/emoji text, journal IDs, attachment names, media types, counts, SHA-256 media hashes and export timestamp. The unencrypted envelope exposes only the archive format/version and cipher fields, required AES-GCM nonce, ciphertext and authentication tag. It does not expose entry titles, content or media names. A separate authenticated domain string binds the encryption to our archive version.

**Important:** A holder of the independently saved recovery key can decrypt. **Losing that key makes this archive unrecoverable.** No password option, key escrow or account-based recovery is provided or promised. The app must not silently store recovery keys alongside its archives, upload them, log them or give a false impression that Android's original Keystore is needed.

## Verification rules

The verification method returns an in-memory **verified preview**. It does not read, reset, overwrite or mutate the destination vault. It rejects:
- Wrong recovery key and tampering of nonce/tag/ciphertext.
- Unknown format/algorithm version; empty, malformed or truncated containers.
- Duplicate stable entry IDs and duplicate attachment IDs.
- Untrusted filenames with parent-directory traversal, slash/backslash or control characters; invalid media types.
- Large files, oversized media, entry body length or excessive entry/media counts.
- SHA-256 attachment data mismatch and internally inconsistent content counts.

Test suite covers 16 scenarios including correct-key roundtrip, cross-object key export/import, Telugu/emoji and media preservation, tampered-header/payload behavior and constraints. Test data uses only explicitly fictional examples.

### Why there are no zip-slip or decompression bomb classes here

The *A4.1* archive has **no ZIP entries and no decompression step**. Its manifest is inside the authenticated encrypted payload, and the verifier accepts only bounded JSON/base64 media. If the product later switches to ZIP streaming or compression, zip-slip, decompression bombs, unknown extensions, incremental verification and storage quotas need an independent test suite.

## Scope / missing work

1. **Not a password-recovery system.** The user must safely store a long random 256-bit key. Password-to-key derivation with a memory-hard KDF (or a documented, reviewed alternative) and honest password-recovery UX are missing.
2. **Not a real backup exporter.** This proof packages in-memory fictional data and has no transactionally consistent snapshot of real SQLite databases or attachments, file-save atomicity, storage quota handling or export progress UI.
3. **Not a transactional importer.** There is intentionally **no database restore method**. A4.2 must stage validated entries and media into a clean destination, check duplicate IDs/schema compatibility, verify receipt and hashes, then commit or roll back without overwriting existing data.
4. **Not clean-device recovery.** Tests run in one Linux CI context with exported and reimported recovery secrets; actual Android device replacement, lost original Keystore keys, reinstall and restored-key UX need independent verification.
5. **Not production reviewed.** Memory lifetime of recovery keys, platform screen/clipboard exposure, lock screen, biometric policy, filesystem permissions, anti-rollback/versioning, archive corruption during actual file writes and an independent security audit remain open.
6. **Bounded test format.** Current limits are small to simplify reliable verification (1,000 entries, 25 media items, 2 MiB per media and ~6 MiB encrypted payload). Production archive format must support large journals and attachments via a streamed design, not remove bounds blindly.

## Next acceptance gate: A4.2

- Implement a transactionally staged clean-vault restore, with **no effect on existing vault on wrong key, malformed archive or failed import**.
- Test multiple entries/revisions, media deduplication, parent-journal relationships, schema migration, import conflicts, disk full and actual interruption.
- Test full archive export, copied archive and key, and clean-device recovery in a separate Android emulator/install using no original device-bound key.
- User-review recovery instructions, key custody, export/import confirmations and a visible verified/not-verified state.

**Keep archive-key material and real diary content out of the diagnostic harness.** This package is test-only.

Related: [Stage 4 engineering report](../../docs/STAGE4_ENGINEERING_SPIKE.md), [privacy and recovery requirements](../../docs/DATA_PRIVACY_RELIABILITY.md).
