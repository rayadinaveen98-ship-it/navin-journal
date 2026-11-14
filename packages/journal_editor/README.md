# APK 02 — Encrypted journal editor integration

**Stage:** developer-only fictional fixture. **Not** a private journaling application.

**Latest verified CI:** [Editor/recovery suite 43562993019](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43562993019) — **32/32 tests passed** with simulated ENOSPC at the real background isolate and strict analysis; [Android API-34 fault-injection/reinstall 43563086930](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43563086930) — **7/7 scripted fictional native markers**, 32 editor/recovery tests and 13 Flutter checks passed, with a real force-stop between ambiguous publication and Keystore reopen.

## What this adds

- [journal_core_draft_port.dart](lib/journal_core_draft_port.dart): implements the existing A3 DraftCommitPort against the real encrypted whole-journal core. A new blank draft obtains its database ID only after committing a meaningful entry; an existing entry loads its title, body and revision.
- This adapter reuses the existing A3 DraftAutosaveController (debounce, composing IME, dirty/saving/saved/error/conflict status, forced save on close) rather than maintaining another independent autosave state machine.
- Retries after a **simulated lost acknowledgement after an actual database COMMIT** are idempotent within the same editor session: no duplicate journal entry or phantom revision.
- Optimistic locking protects an entry edited in two sessions; a conflict must be resolved, never silently overwritten.
- Event dates are preserved across title/body-only updates. A draft with both empty title and empty body is not silently committed.
- [journal_editor_isolate.dart](lib/journal_editor_isolate.dart): owns the encrypted JournalVault on a dedicated background Dart isolate, not on Flutter's UI isolate. UI-facing async create/list/read/start-session/save/close operations use a generic error protocol; no entry text or key material appears in error messages.
- A new worker can independently reopen encrypted content after the previous worker has been closed; wrong keys and accidental create-over-existing fail closed.
- [journal_editor_session_test.dart](test/journal_editor_session_test.dart): 13 integration tests of encrypted autosave state, retries, IME composition and conflicts.
- [journal_editor_isolate_test.dart](test/journal_editor_isolate_test.dart): 9 integration tests of serialized worker ownership, complete persisted journal entries, revisions, shutdown and reopen, wrong keys and concurrent editor sessions.

- [portable_recovery_worker.dart](lib/portable_recovery_worker.dart): decrypts/authenticates independently keyed `NJR-RECOVERY-2` archives, stages a full journal into a *previously absent* destination with a new SQLite3MC database key on a background isolate, and rejects wrong keys/tampering/collisions. [portable_recovery_worker_test.dart](test/portable_recovery_worker_test.dart) adds six test cases.
- `JournalEditorWorker.exportRecoveryArchive` produces the portable authenticated archive from a consistent encrypted vault snapshot without storing a plaintext draft/export.

**32/32 Linux worker/editor/recovery tests passed.** The Android API-34 fictional-data reinstall probe also passed seven phases: encrypted export, wrong-key rejection, synthetic ENOSPC before publication, synthetic ENOSPC after publication, independent Keystore reopen after force-stop, ordinary restored-vault creation and ordinary force-stop reopen. These are engineering proofs only, **not** physical device disk-exhaustion/power-loss or private diary approval.

## Next integration boundary

Connect the actual Flutter Writing Studio to JournalEditorWorker with:

1. Platform MethodChannel -> AndroidKeyStore -> unlock/provision wrapped test database key.
2. A single app-lifetime worker connection and explicit open/create/unlock states, not a one-shot isolate per keystroke.
3. Stable journal IDs, session initial value, body/title TextEditingController, composition signals and SaveIndicator; never show "Saved locally" until the encrypted COMMIT is acknowledged.
4. Draft close/exit guard based on closeSafely(), and a recovery path after errors or conflict.
5. Automated Android emulator force-stop/relaunch, fresh install and hardware/tablet tests with fictional content.
6. Production-grade no-clobber encrypted recovery, durable export and key-loss design before entering **any real private diary text**.

## Important limitations

The current service accepts a caller-supplied experimental TestVaultKey. The Android Keystore bridge remains a separate diagnostic test entrypoint; the new worker has not yet been wired to the consumer Flutter UI. The Android runtime CI for the scripted APK02 bridge is separately tracked under [run 43447323791](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43447323791).

**Do not use a direct JournalCoreDraftPort from the Flutter UI isolate**; its SQL calls are synchronous. Always use JournalEditorWorker for nonblocking UI calls.

The fixture schema has test-only size caps; native memory/keystore custody, backup/restore, crash durability, migration, entry deletion behavior, secure thumbnail/search indexing and independent security review remain open. No user-facing APK 02 has been released.
