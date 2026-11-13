# Stage 4 A3 — autosave state machine and encrypted transaction experiment

**Verification:** [33/33 Dart tests passed in CI run 43420715468](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43420715468), plus static analysis.  
**Date:** 2026-11-13  
**Data classification:** All fixtures are fictional. This is **not a release-ready diary, real Android autosave, or secure key lifecycle**.

## Implemented components

**A3.1 — [draft_autosave.dart](lib/draft_autosave.dart)** implements the editor's independent save-coordination state model: `pristine → dirty → saving → saved`, with explicit `error` and `conflict` states. It coalesces rapid typing, defers debounce during Telugu IME composition, provides explicit lifecycle `flush()`, retries failed writes, and refuses safe dismissal when unsaved content remains. Reentrant writes are serialized; edits made while a commit is in-flight cannot inherit the prior commit's `saved` status.

**A3.2 — [encrypted_draft_store.dart](lib/encrypted_draft_store.dart)** is a separate, deliberately temporary **SQLite3MultipleCiphers** adapter for encrypted test records, using a caller-provided random test key. It stores title/body together in one transaction with stable IDs, record versions and prior revisions. It refuses missing/wrong keys, unsupported schema versions and unacknowledged conflicting writes. An injected fault between revision storage and update rolls the transaction back; an injected fault *after* COMMIT but *before* acknowledgement is retried idempotently when the exact previous snapshot is already present.

The adapter is **not** the future unified product schema. We must reconcile the A1 journal/entry schema, A2 encrypted vault, A2.2 device keys and this A3 persistence experiment before exposing any user input.

## CI test coverage

[View 33 tests and runner logs](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43420715468)

- **21 controller tests**: pristine/dirty/saving/saved/error/conflict, delayed acknowledgements, multiple edits in-flight, no duplicate concurrent flush, retries, safe close refusal, Telugu/English/emoji preservation, IME composition start/end, forced lifecycle flush, empty-new-draft suppression, intentional clearing of an existing entry, and generic non-sensitive status labels.
- **12 encrypted SQLite tests**: correct-key reopen, title+body revision history, lost-ack idempotence on insert and update, atomic fault rollback, multi-connection version conflict, wrong-key fail-closed, plaintext sentinel scan across database/WAL, unsupported future schema rejection without reset, blank record rejection, changed draft after lost ACK conflict, and duplicate-save prevention.

**Critical nuance:** A lost acknowledgement after COMMIT cannot always be distinguished from an external writer's change. If the database's current snapshot no longer matches the exact pending write, the adapter raises a conflict and preserves the external committed content. It never silently overwrites it.

## Save indicator semantics

| State | Meaning |
|---|---|
| `pristine` | Never edited; no database record required |
| `dirty` | Current editor content is not acknowledged as committed |
| `saving` | Snapshot sent to storage, commit acknowledgement not yet received |
| `saved` | Storage layer acknowledged exact latest snapshot, version retained |
| `error` | Commit not acknowledged; draft remains in memory and requires retry |
| `conflict` | Existing committed version differs; review/resolution required |

There is no claim that a `saved` draft is **backed up, synced, restorable on another device, or durable through all power failures**. Those are separate statuses with separate proofs.

## Production blockers

1. **No real Android editor integration.** A3.1/A3.2 tests ran on Linux; there is no foreground-to-background lifecycle hook, Android force-stop/reopen experiment or IME test on real hardware.
2. **No durable unsaved edit recovery.** If Android kills the app after a keystroke but before the debounce/transaction, a memory-only unsaved draft may be lost. A production design needs explicit recovery policy and testing. Hiding the app does not guarantee a flush completed.
3. **No storage isolate.** The A3.2 adapter performs synchronous SQLite operations inside its Future-returning interface. It must move to a dedicated background isolate for smooth Flutter typing.
4. **No production encrypted vault.** Test-only SQLite3MultipleCiphers is used with a directly supplied key, not the complete A2.4 Android Keystore lifecycle adapter, reviewed secure-memory discipline or audited unified database schema.
5. **No attachment, search, backup, migrations, lock screen, multi-entry manager or conflict-resolution UI.**
6. **No real end-user data or release APK.** Never treat this spike as private-data ready.

## Next explicit engineering acceptance gates

- **A3.3:** Integrate the autosave coordinator into the *debug-only* Flutter Android harness with a dedicated encrypted storage worker; verify real typing, pause/resume, screen recreation, and editor "saved" status against acknowledged commits.
- **A3.4:** Fault-inject force-stop during/in-between autosave cycles; validate recovery of every **acknowledged** version and define disclosure for data still unsaved at kill time.
- **A2 security gate:** Physical Android Keystore, key-loss/reinstall behavior, portable recovery and independent review remain open.
- **A4:** Authenticated backup, clean-device restore and failure tests, independent of device-only keys.

Related: [Stage 4 tracker](../../docs/STAGE4_ENGINEERING_SPIKE.md), [A2.4 Flutter bridge](../flutter_bridge_probe/README.md), [product reliability requirements](../../docs/DATA_PRIVACY_RELIABILITY.md).
