# Stage 5D.1-D — encrypted durable conflict-copy receipt (review candidate)

**Status:** PROPOSED CODE ON FEATURE BRANCH / NOT MERGED / NOT RELEASED. Fictional data only.  
**Baseline:** main at `2bb5029210a2610fafc24ccf1a3a5e4e1c1988de` (15 Nov 2026).  
**Review date:** 16 Nov 2026.

## Why this slice exists

PR #22 can preserve a conflicting fictional draft as a separate encrypted entry, but its deduplication table lives only in the worker isolate. A crash or unknown acknowledgement after SQLite COMMIT could make a new session unaware that a copy exists. A second blind create would risk a duplicate and a misleading confirmation.

## Proposed implementation for founder review

- Extend the fictional encrypted journal schema from **v1 to v2** with a dedicated `conflict_copy_receipts` table inside the encrypted SQLite database. Migration from the existing v1 vault is additive and transactionally versioned. It must not delete or rewrite the existing entries, revisions or attachments.
- A cryptographically random, existing editor-session token acts as an opaque operation ID. One SQL transaction creates the separate page and its receipt, recording source ID, source expected version, actual competing version, destination journal, copy ID and creation time. No journal text, key or path enters logs or unencrypted preferences.
- A replay with the same operation ID and identical source/version/text validates the committed encrypted copy rather than creating another one. Reuse with different content or source fails closed. The original and all its revisions remain untouched.
- Expose a read-only encrypted receipt lookup by source entry for post-restart reconciliation. A restarted worker **does not automatically create another page**; the future UX must first review prior receipts.
- Preserve the existing scripted-fictional-only Writing Studio guard. No production text input, consumer button, network service or payment change.

## Backup compatibility boundary — deliberately fail closed

Existing `NJR-PRODUCT-SNAPSHOT-1` archives can represent journal entries and revision history but **cannot represent conflict-copy receipts**. Until an authenticated archive-format extension and isolated clean-restore tests preserve this provenance, **snapshot/export must refuse a vault containing conflict-copy receipts**. This is a safety block, not completed recovery support. A user-facing backup flow and real-content permission must remain blocked.

The schema v2 change is a reviewable architectural proposal. It needs explicit founder acceptance and CI/security review before merge. No migration is applied to the main branch by this draft.

## Tests and acceptance gates

1. Original version 2, its earlier revision and separate preserved page all survive close/reopen unchanged.
2. Replay after a simulated lost acknowledgment returns the same page; a mismatched operation is rejected.
3. Injected interruption after entry insert and after receipt insert causes full rollback, with no partial page or orphan receipt.
4. An old encrypted v1 vault migrates on reopen without altering its original page.
5. The existing v1 archive path refuses a copied vault until the receipt-carrying archive format is implemented.
6. Worker shutdown/reopen exposes the earlier encrypted receipt, without automatically creating an extra page.
7. Required CI: encrypted core, editor/worker, scripted Flutter Library, actual Android DocumentsUI, Telugu HOME/force-stop and clean-reinstall recovery. All must be checked on the **exact PR head**, and existing failures recorded rather than bypassed.

## Explicitly not delivered

- Consumer conflict-review UI and its 200% font/TalkBack/Telugu verification.
- Cross-process persistence of *unsaved* editor text or of an operation ID before the first successful transaction.
- Recovery of receipt provenance through an exported backup; physical power-loss/OEM hardware verification.
- Private journal beta, Play Store build, production schema rollout, signing changes, or release.

**Decision gate:** review migration and fail-closed archive compatibility, validate all exact-head tests, then separately authorize merge. Physical phone/tablet acceptance and founder release approval remain open.
