# Navin Journal — Stage 5D.1 archive provenance compatibility RFC

**Status: PROPOSED DESIGN ONLY. Requires founder architecture approval. No executable application code, migration, merge, release or private-data permission is authorized by this RFC.**
**Date:** 16 November 2026. **Reference:** draft PR #25 at `82647f21086fb49831e5896d80980c6c62e86ec4`; verified 5/5 exact-head CI and 44 core + 63 editor tests. The merged `main` baseline remains `2bb5029210a2610fafc24ccf1a3a5e4e1c1988de` at the start of this review.

## 1. Current factual contract

- The **encrypted vault** in draft PR #25 proposes schema v2 with `conflict_copy_receipts` written in the same SQLite transaction as a new preserved page. `operation_id` is the existing random worker-session ID. This code is **draft / not merged**.
- The existing **portable outer archive** is `NJR-RECOVERY-2`, AES-256-GCM with version-specific AAD `navin-journal|product-recovery|version-2`. The authenticated *inner snapshot* is `NJR-PRODUCT-SNAPSHOT-1`: journals, entries, revisions and attachments only. `ProductSnapshotCodec` checks exact keys and rejects unknown fields.
- The current restorer authenticates and validates the archive before staging, imports into a **new absent** encrypted vault, independently reopens and checks equivalence, then publishes with no-clobber native rename and fsync. Never merge a backup into a live vault.
- PR #25 intentionally **refuses snapshot/export when a conflict receipt exists**. This is safer than producing an apparently complete backup which would lose replay/provenance data, but it must not become the long-term user experience.

## 2. Options evaluated

| Option | Advantage | Principal risk | Recommendation |
| --- | --- | --- | --- |
| A — New authenticated outer `NJR-RECOVERY-3` plus inner `NJR-PRODUCT-SNAPSHOT-2` with receipts | Explicit version and AAD separation; complete restore; old-format import can remain supported | Additional codec and migration tests required | **Preferred proposal** |
| B — Keep outer `NJR-RECOVERY-2`, silently add inner snapshot fields | Smaller container diff | Old consumers reject payload; format obscures change; easy to mix version-specific tests | Reject |
| C — Separate encrypted receipts sidecar outside archive | Avoids inner-format change | Export/import atomicity and key/retention mismatch; missing sidecar can reintroduce duplicate-ACK ambiguity | Reject |
| D — Permanently block all backups after any conflict copy | Smallest immediate change | Permanently prevents an essential safety feature for ordinary journaling | Temporary fallback only |

**Proposed decision A:** Introduce `NJR-RECOVERY-3` and a new domain-separated AEAD context, while retaining **read-only import** of valid v2 archives into a clean vault. Never rewrite a user's existing v2 archive; never silently downgrade a v3 export. The legacy `NJR-RECOVERY-1` prototype is a different, narrower format and is not a replacement for full-schema backup.

## 3. Proposed authenticated v3 snapshot contract

Versioned *plaintext only in protected transient memory*, authenticated inside a v3 encrypted container:

    format: NJR-PRODUCT-SNAPSHOT-2
    exportedAtUtc: ISO-8601 UTC
    journals: [existing exact journal records]
    entries: [existing exact entry records]
    revisions: [existing exact revision records]
    attachments: [existing exact media records with verified SHA-256]
    conflictCopyReceipts: [
      { operationId, sourceEntryId, expectedOriginalVersion,
        competingOriginalVersion, copyEntryId, journalId, createdAtMs }
    ]

Fields above are authenticated and encrypted, including operation IDs and journal/page links. The v3 container may expose **only** its strictly bounded version, algorithm, random nonce, ciphertext and authentication tag; not journal titles, entry IDs, receipt counts or filenames. Use a **fresh 96-bit AES-GCM nonce** per export, a 256-bit independently held recovery key and distinct v3 AAD. Verify canonical base64 and exact outer keys. No local or cloud analytics of keys, plaintext or provenance.

**Validation invariants — all must be proved before staging:**

1. Exact format and exact field schema; reject duplicate IDs, unknown fields, out-of-range numbers, unsupported future versions, overly large arrays and malformed UTF-8. Keep bounded limits as **test-fixture limits**, not consumer product limits.
2. Each receipt has a unique operation ID and unique destination copy ID. Both source and copy exist among authenticated entries; source ID is not the copied ID.
3. The source's persisted version is at least the recorded `competingOriginalVersion`, which must be strictly greater than `expectedOriginalVersion` (minimum 1). The source revision chain must independently validate. Do not require its **current** journal or title to equal historical provenance after later moves/edits.
4. The copy may have been **edited, archived, moved, trashed or restored** after creation; validation must not require its present version to remain 1, current body to match the original copy snapshot, or current journal to equal the creation-time journal. Preserve historical receipt identity.
5. The recorded journal is a valid authenticated journal ID, but may now be archived or trashed. Creation timestamps must be plausible nonnegative bounded integers; do not infer chronology from ties in millisecond timestamps.
6. All attachments and historical revisions continue their existing checksum/ownership checks. Cross-references must fail closed rather than silently drop damaged receipts.
7. On v2 import only: validate old exact inner v1 schema, initialize an **empty** v2 encrypted receipt table, label the origin as legacy v2 archive and never claim recovered provenance that did not exist in that archive.

## 4. Atomic restoration and verification

1. Inspect the container's limited format indicator and select only an allowlisted codec. Authenticate AEAD tag with the corresponding version-specific AAD **before** interpreting any inner data or touching destination storage.
2. Strictly validate the complete authenticated snapshot and receipt references in memory. Refuse corruption, wrong key, unsupported versions, over-limit payloads or missing fields without creating a visible journal.
3. Restore journals, entries, revisions, attachments **and receipts** to a fresh encrypted schema-v2 destination inside one database transaction. Load receipt rows last, after the referenced entries. Destination must be absent; never merge with an active user vault.
4. Reopen using the separate destination database key. Verify SQLite integrity and exact authenticated semantic equivalence, including every receipt field, not only totals. The `exportedAtUtc` timestamp may be excluded from comparison because a new snapshot is generated.
5. Publish through the existing no-clobber, fsync-based path only after verification. If a post-rename acknowledgment is unknown, retain the destination and independently authenticate/reopen it later; never auto-delete or reissue a destructive attempt.
6. Reconcile by source ID plus operation ID after reopen. A restored receipt can prove a particular copy exists. A missing receipt must **not** be assumed proof that a previous save failed, especially when the input is a legacy archive.

## 5. Compatibility matrix

| Source | Reader | Expected result |
| --- | --- | --- |
| v2 archive with snapshot v1 | New v3-capable reader | Authenticated import into new schema-v2 empty-ledger vault; existing data preserved |
| v3 archive with snapshot v2 | New v3-capable reader | Authenticated import including exact encrypted conflict-copy receipts; verify after reopen |
| v3 archive | Old v2-only reader | Explicit unsupported-version refusal; no deletion, no import |
| Tampered / wrong-key / mixed AAD / missing receipt | Any reader | Reject before publication; no fallback that discards provenance |
| Valid v3 imported while target already exists | Any reader | Refuse overwrite; staged no-clobber publication only |

**Migration and rollback warning:** Opening an existing database with PR #25 schema v2 upgrades it additively. A prior v1-only binary rejects schema v2; reversible binary downgrade is **not** currently evidenced. Do not enable automatic production migration without a version-aware upgrade and retention policy, user-safe rollback messaging, and verified full-data restore.

## 6. Proposed change boundaries (not approved implementation)

- **A — Format codec:** `spikes/recovery_archive/lib/product_snapshot.dart`, `product_encrypted_archive.dart` and bounded malformed/corrupt fixture tests; keep v2 decrypt compatibility explicitly separated.
- **B — Vault/core:** `packages/journal_core/lib/journal_vault.dart` snapshot/empty import and receipt referential checks; authenticated snapshot must be captured from **one WAL read transaction**, including the receipt table.
- **C — Restore:** `packages/journal_core/lib/staged_product_restore.dart` and semantic equivalence comparator, receipt verification, fault and kill tests; do not change no-clobber publisher.
- **D — Isolate/API and UI:** `packages/journal_editor` background worker v3 export/import dispatch; *fictional only*, user UI disabled until independently approved.
- **E — QA:** Linux unit/fault tests, actual Android API34 separate-key clean uninstall/reinstall, older v2 archive fixture, large-content limits, Telugu, changes after copy, duplicate lost ACK, wrong key, corruption, missing source/copy, renamed/moved/trashed original or copy, pre/post-commit kills and physical OEM device checks.

## 7. Release conditions and unanswered decisions

- Founder approval required for **new v3 archive version** and compatibility matrix, plus final approval to merge draft PR #25's schema v2 after code/security review. Prefer separate implementation PRs to isolate blast radius.
- Security review must cover unique nonces and key custody, copied bytes/temporary memory, Android document provider exposure, state/error messages, legacy unsupported behavior, restored receipt trust and backup retention. No cloud/payments dependency proposed.
- Test-fixture export already held entirely in memory and is limited to 6 MiB plaintext; a real diary/media product requires streaming/bounded-memory design and battery/low-storage verification before unrestricted data.
- Physical phone/tablet UI/TalkBack/Telugu tests and explicit founder private-beta/release decision are **OPEN**. Do not count emulator CI as physical-device certification.

**Recommended sequence:** approve archive decision → isolated v3 codec/validator tests → transactional core and no-clobber restore tests → editor worker and emulator gates → user conflict-review screen → physical acceptance → separate release decision. Until then PR #25's fail-closed export remains the honest behavior.
