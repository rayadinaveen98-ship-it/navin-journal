# Data, privacy and reliability — requirements v0.1

**Security status:** Requirements only; no implementation or independent security audit.

## Storage model

- Entries have stable IDs, journal IDs, creation and last-edit instants, separately optional event-time and time-zone metadata, tags, blocks, references and revision ancestry.
- Store media as managed attachment objects with immutable content checksums, size/MIME metadata, ownership references, and garbage-collection policy.
- Deleted objects enter explicit Trash with recovery semantics. No silent hard-delete during a routine sync.
- Durable storage must use transactional writes and tested crash recovery. Ensure a usable local vault even without account/network.

## Editing and autosave

- Writing is locally committed on a short, predictable interval and at safe lifecycle checkpoints; distinguish *saved locally*, *syncing*, *synced*, and *error*.
- Unmodified empty draft pages should not generate permanent blank entries.
- Draft/revision state survives process death; old committed revision remains intact on write failure.
- Attachments import atomically with rollback or safe staging.

## Encryption & key management

- Use established, reviewed cryptographic implementations; authenticated encryption for contents and attachments.
- Secrets must be protected by platform secure storage and a documented recovery method where feasible.
- Device biometrics may authorize local unlock; they are **not** a universal encryption-key recovery path.
- User-controlled encrypted archives should support integrity checks and documented password/key derivation.
- Encryption must include indexes, thumbnails, temporary copies and backups; minimize metadata leakage and clipboard/notification exposure.
- Don't claim end-to-end encryption until architecture and tests demonstrate the provider cannot access plaintext.
- No journaling content in logs, crash reporting, telemetry or AI requests by default.

## Sync (optional, later)

- Idempotent operations with per-entry revision ancestry and clocks sufficient to identify concurrency.
- Preserve divergent edits and present human-resolvable conflicts rather than last-write-wins.
- Pause and resume after intermittent networks; clear error states.
- Client-side encrypted payload; server metadata minimization; no secret keys in repository.
- Explicit opt-in, clear costs, provider dependency handling, and recovery design.
- Sync is not backup. A deletion propagated via sync can remove all active copies; backup history remains separately recoverable under stated retention.

## Backup/restore

- Archive manifest includes schema version, app version, journals and entry counts, media counts/sizes, cryptographic hashes and export creation timestamp.
- Archive can be verified without overwriting current journal.
- Restore stages data, checks manifest/hashes/keys, handles duplicates and schema migrations, then commits.
- Export plain readable formats (Markdown/text + media and documented structured format); PDF is human-readable but not authoritative for full fidelity.
- A recovery rehearsal must succeed on a clean device before release.
- Explicitly explain risks of losing encryption keys, failed backups and cloud-provider limitations.

## Threats to test

- Crash during typing, attachment import, backup creation, restore, and migration.
- Database corruption, insufficient disk, invalid media, OS permission revocation.
- Concurrent edits across devices, clock skew, time-zone migration, offline merge.
- Unencrypted index/cache/temporary files or attachment thumbnail leakage.
- User loses password/key, reinstall wipes local data, cloud quota exhausted.
- Unauthorized unlock, journal preview leakage in app switcher and notifications.
- Backup archive tampering, zip slip / path traversal, decompression bombs and oversized files.

## Go/no-go

A release requires passing the signed-off test matrix in `ACCEPTANCE_CRITERIA.md`. Security terminology is withheld from marketing until evidence exists. Data-loss bugs are release blockers.
