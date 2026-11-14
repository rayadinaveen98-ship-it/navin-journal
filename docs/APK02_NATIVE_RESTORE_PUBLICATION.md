# APK 02 — atomic restore publication and durability boundary

**Status: fictional data only. Linux atomic no-clobber/fsync tests and Android API-34 restore integration VERIFIED. Actual device power-loss, storage exhaustion and production durability remain UNVERIFIED.**

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

## Interruption, ENOSPC and abandoned-stage safeguards

[30/30 encrypted-core tests passed in updated CI run 43561573198](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43561573198), including **simulated** ENOSPC at ten pre-publication checkpoints and after the kernel rename, **actual Linux SIGKILL** of independent restore workers at four checkpoints, and a bounded **read-only** quarantine inventory of leftover staging paths. A staged marker is never a valid-publication proof. Failed prepublication work is not exposed as a finished journal, while ambiguous post-rename work is preserved for independently authenticated reopen. The test fixture alone removes its own interrupted staging directories after verifying their existence; the product library does not auto-delete them.

[Detailed test evidence and recovery policy](APK02_INTERRUPTED_RESTORE_SAFETY.md). These checks **do not** establish actual exhaustion of an Android device's storage, sudden hardware power loss, or safe consumer orphan cleanup/resumption. OEM-device and physical failure tests remain required.

## Android integration evidence

- [Successful Android clean reinstall and independent-key recovery run 43560295633](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43560295633) compiled the new FFI-linked restore code, verified native `renameat2` and file/directory syncs at runtime, and passed all four `PORTABLE_EXPORT_READY`, `PORTABLE_WRONG_KEY`, `PORTABLE_RESTORE_OK` and `PORTABLE_REOPEN_OK` stages with a real uninstall and fresh Android Keystore. **29/29 editor/recovery tests and 13/13 Flutter tests** also passed. This is a scripted small fictional archive, not a real-user backup tool.
- [Successful Android Keystore force-stop recovery run 43560295627](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43560295627) confirmed `ACK_V1`, `ACK_V2`, `RECOVERED_V2` after two real force-stops, with 29/29 editor/recovery tests and Flutter checks. This protects regression coverage for the existing editor path.
- These runs verify **Android API-34 emulator support** for the new FFI pathway under normal operation. They do not verify a racing filesystem attacker on Android, arbitrary device OEMs/filesystems, abrupt power loss, disk-full behavior, or guaranteed durability of storage hardware.

## Still required before private journal data

1. Real Android device and OEM filesystem validation of no-clobber/failure behavior, including fault injection after native publication; the API-34 emulator integration succeeded but is not equivalent to a physical durability test.
2. Real device and filesystem behavior across abrupt process kill, forced reboot and low-storage failure, including recovery of complete-but-ambiguously-acknowledged restores.
3. A user-safe authenticated resume/discard decision for orphaned staging directories. A read-only detector is now implemented and Linux tested, but it intentionally cannot delete or resume unknown content.
4. Robust archive streaming for large diaries and media, versioned migrations, independent recovery-key custody/entry and irreversible loss warnings.
5. Reviewer-audited key/envelope lifecycle, secure transient export/import file handling, production restore UI and physical phone/tablet quality signoff.

**Do not enter personal diary entries into any APK 02 diagnostic build.**
