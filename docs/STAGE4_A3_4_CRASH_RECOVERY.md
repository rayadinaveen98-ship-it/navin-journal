# Stage 4 A3.4 — Actual process termination and encrypted SQLite recovery

**Status:** **LINUX SIGKILL PROOF VERIFIED — 44/44 tests** passed on 13 November 2026. **Android force-stop, reboot, app recreation and physical-device tests remain OPEN.**

[GitHub Actions run 43425363790](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43425363790) passed the combined Dart autosave suite and static analysis.

## What was actually killed

A test launches a **separate Dart VM process** with an encrypted SQLite3MultipleCiphers connection and fixture-only data. The parent sends an actual Linux **SIGKILL**, waits for the process to exit, opens the same encrypted database in a fresh connection, and compares exact committed content, revision history and integrity.

Sources:
- [Child writer and exact interruption markers](../spikes/autosave_coordinator/bin/crash_writer.dart)
- [Three Linux process-kill regression tests](../spikes/autosave_coordinator/test/process_kill_test.dart)
- [Encrypted storage adapter](../spikes/autosave_coordinator/lib/encrypted_draft_store.dart)
- [Editor autosave coordinator](../spikes/autosave_coordinator/lib/draft_autosave.dart)

## Verified cases

| Interruption | Expected and verified outcome |
|---|---|
| Termination **inside** an unfinished revision transaction | WAL rollback protects the last committed version (v1); no partly inserted revision |
| Termination **after COMMIT**, but **before acknowledgement** is delivered | New exact version (v2) is recoverable; retry with the original expected version and identical snapshot returns existing v2 without duplication |
| Termination **after acknowledgement** | Latest committed version (v2) survives a fresh process and encrypted database reopen |

**Total:** 41 previous A3 tests + 3 new real SIGKILL tests = **44/44**. Only fictional strings were used.

This is materially different from exception fault-injection in the same process. It exercises native SQLite process loss at exact transaction boundaries.

## What this does *not* prove

- Android `am force-stop`, OS low-memory kill, reboot, app reinstall or real device restore were **not performed** by these Linux tests.
- Text typed **but not committed** before a kill cannot be promised recoverable. The UI must not claim `Saved locally` until the storage receipt has arrived.
- No actual Android Keystore unlock after process restart was exercised by this Linux worker test. A2/A2.4's **separate** Android Keystore proof cannot be combined into a single end-to-end production assurance.
- Kernel crash or sudden power loss was **not** simulated by SIGKILL. Filesystem fsync and device-specific data durability remain to test.
- The database key is a temporary test secret. The process kill test passes it through test-only stdin; there is **no** secure portable recovery mechanism.
- No production Flutter writing screen, app-data location contract, encrypted attachments, native icon or finished APK exists. The A3.3 Android widget/lifecycle emulator suite is a separate gate.

## Next acceptance gates

1. Resolve [A3.3 Android emulator installation/lifecycle CI](STAGE4_A3_3_ANDROID_EDITOR.md); a previous run [43422522118](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43422522118) compiled the debug APK but **failed to install** because the emulator package manager was unavailable. The CI now waits for Android package-manager readiness and runs integration suites sequentially.
2. Build a dedicated *test-only persistent fixture* in Android app-private support storage (not cache) with a Keystore envelope preserved across an actual **ADB force-stop and relaunch**. Verify exact last-acknowledged bytes and versions in a genuinely new app process.
3. Test interruption during a commit, low-storage, Android background policy, real Telugu IME composition and physical phone/tablet.
4. Reconcile test database schema with the unified production journal model before any real user writes.
5. Design independently recoverable authenticated encrypted backup and verify clean-device restore. Keystore keys alone cannot restore across device changes.

**Release gate:** A3.4 is **PARTIALLY VERIFIED (Linux process termination only)**. Do not claim crash-proof Android autosave or private-data-ready release.
