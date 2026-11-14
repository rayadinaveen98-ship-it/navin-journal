# APK 02 — atomic restore publication and durability boundary

**Status: fictional data only. Linux no-clobber + fsync tests verified; Android runtime proof and physical power-loss behavior still require confirmation.**

## Implemented

The [encrypted staged restorer](../packages/journal_core/lib/staged_product_restore.dart) first authenticates the independently keyed `NJR-RECOVERY-2` archive, validates the complete schema and attachment hashes, imports into a new SQLite3MultipleCiphers vault in one transaction, closes, and reopens it for exact schema comparison. Only then is publication allowed.

The new [native publication layer](../packages/journal_core/lib/native_restore_publisher.dart) replaces the earlier check-then-rename with a Linux-kernel `renameat2` call using `RENAME_NOREPLACE`, accessed through native `libc` FFI. It syncs staging files (including encrypted SQLite WAL/SHM if present), an explicitly non-secret readiness marker, the staging directory, and the parent directory before rename; then syncs the parent again afterward. The publisher **fails closed** if libc/symbol/syscall/filesystem/fsync is unavailable. It does not use a potentially overwriting `Directory.rename` fallback.

The marker `.navin-restore-ready-v1` says the stage reached its publication gate. **It is not authenticated and cannot establish data integrity by itself**; always reopen and cryptographically validate the encrypted journal before enabling it.

**Important failure semantics:** if a fault occurs after the kernel rename succeeds but before the parent fsync completes, the destination may already be present. It must never be automatically removed or silently retried as if absent. A new app session must inspect its marker and reopen the encrypted database before making any decision about recovery. Native `fsync` success is an application request for persistence, not independent proof of survival across power loss on every filesystem.

## Verified Linux tests

[25/25 encrypted-core test cases passed with strict Dart analysis](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43560381700). In addition to the previous whole-journal/Trash/media tests, the new checks cover:

- readiness absent before restoration, then present after verified publication;
- a competing file appearing **after staging and all syncs but immediately before the native rename** is never overwritten;
- an injected failure **after the rename** preserves the complete independently reopenable journal rather than deleting an ambiguously committed destination;
- two simultaneous attempts targeting the same nonexistent directory produce exactly **one success**, preserve all records and leave no abandoned staging folders.

The [CI gate](../.github/workflows/apk02-core-restore-durability.yml) runs Linux Dart formatter, strict analyzer, encrypted core tests and fault-injection tests. Other Android fixture workflows also compile against the new core; their results must be checked separately and are not implied by these Linux tests.

## Still required before private journal data

1. Android API-34 native `renameat2`/fsync integration on the clean-install archive flow, including wrong-key and retry cases.
2. Real device and filesystem behavior across abrupt process kill, forced reboot and low-storage failure, including recovery of complete-but-ambiguously-acknowledged restores.
3. A documented, user-safe resume/cancel decision for orphaned staging directories; never delete unknown or externally occupied content.
4. Robust archive streaming for large diaries and media, versioned migrations, independent recovery-key custody/entry and irreversible loss warnings.
5. Reviewer-audited key/envelope lifecycle, secure transient export/import file handling, production restore UI and physical phone/tablet quality signoff.

**Do not enter personal diary entries into any APK 02 diagnostic build.**
