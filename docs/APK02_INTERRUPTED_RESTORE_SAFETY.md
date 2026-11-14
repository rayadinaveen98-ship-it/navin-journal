# Navin Journal — interrupted restore and low-storage fault gate

**Status: Linux fault-injection VERIFIED with fictional content. Android normal recovery regressions are being checked separately.** This is not a private-data security or physical power-loss certification.

## Implementation

- [NativeRestorePublisher](../packages/journal_core/lib/native_restore_publisher.dart) exposes precise failure checkpoints around writing its readiness marker, syncing encrypted SQLite files, syncing staging/parent directories, the atomic no-clobber rename and syncing the parent afterward.
- [StagedProductRestorer](../packages/journal_core/lib/staged_product_restore.dart) reports a generic `ProductRestoreRejected` for a failed staged restore. An ordinary caught failure **before** atomic publication cleans up only the stage created by that operation, and never overwrites an existing journal.
- [RestoreStagingInventory](../packages/journal_core/lib/restore_staging_inventory.dart) lists matching staging candidates **read-only** and without following symlinks. It reports whether a database file and publication marker were observed, but does **not** authenticate either, infer ownership or offer deletion/retry/automatic promotion. If too many candidates exist, it fails rather than claiming the scan is complete.
- After a successful kernel rename, cleanup cannot delete the published directory, even if a simulated subsequent sync failure prevents the caller from receiving a success acknowledgement. The next app run must independently authenticate and reopen it before considering recovery.

## Verified Linux CI

[Durability run 43561427213](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43561427213) passed **30/30 encrypted-core tests** with strict Dart analyzer.

Five newly added tests include:

1. **ENOSPC before publication:** simulate OS `No space left on device` (errno 28) at ten distinct checkpoints, from stage creation and journal import to readiness-marker writing and pre-rename file/directory syncs. Every attempt fails closed and cleans up only its own uncommitted staging directory; no visible target is created. A later retry succeeds.
2. **ENOSPC after publication:** simulate errno 28 immediately after the atomic no-clobber rename but before parent-directory sync. The visible target is preserved, and the full encrypted database, revision and media can be independently opened and verified. Its acknowledgement remains ambiguous and must not be misreported as certain durability.
3. **Read-only inventory:** create an incomplete stage, a forged ready-looking stage, an unrelated file and a symlink with staging-like names. The inventory reports/quarantines all without reading journal contents, following links or deleting anything; presence of a marker is explicitly untrusted.
4. **Bounded scan:** exceed the inventory's 128-candidate safety limit and confirm that it refuses to silently report a partial inventory or delete anything.
5. **Real OS SIGKILL:** run the actual encrypted restorer in an independent Dart process and forcibly terminate it with signal 9 at stage creation, after DB commit, after writing the readiness marker, and immediately after the atomic rename. Before publication, the destination remains absent and a leftover staging directory is quarantined. After publication, the ready-looking target survives and exact encrypted content/history/media reopen successfully. The test removes its own fictional orphan fixtures afterward; production code does not do so automatically.

These are **simulated low-storage errors**, not tests that actually exhaust the device's storage. The SIGKILL tests are real process termination on Linux, not physical device power interruption.

## Safety decisions

- **Never infer readiness from directory names or a plaintext marker alone.** Recheck the database with its proper encryption key, integrity check and expected contents.
- **Never auto-delete orphan candidates.** Ownership and other-process activity are not proven by a matching name; later UX must provide a safe, independently validated decision.
- **Never treat a failed acknowledgement after rename as proof the restore failed or succeeded durably.** Preserve the target and verify on the next launch.
- **No fallback to a potentially overwriting rename.** A missing native `renameat2(RENAME_NOREPLACE)` implementation blocks publication.
- Keep only fictional test data in this gate. It does not enable personal journal input.

## Still required

Real Android OEM filesystem/low-storage failure tests, abrupt device reboot/power-loss survival, orphan-stage ownership and explicit recovery/retry UX, bounded-memory media streaming, crash-safe envelope/key lifecycle, independent security review and physical phone/tablet validation. The Android portable archive test verifies normal clean-uninstall/reinstall recovery but does **not** simulate exhausted storage or power loss.
