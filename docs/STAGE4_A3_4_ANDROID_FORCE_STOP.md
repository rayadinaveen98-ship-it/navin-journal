# Stage 4 A3.4 — Android process force-stop / encrypted recovery test

**Status (13 Nov 2026): ANDROID API-35 EMULATOR VERIFIED.** [Passing GitHub Actions run 43427287021](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43427287021) recorded **ACK_V1 → ADB force-stop → ACK_V2 → ADB force-stop → RECOVERED_V2**, then cleanly removed the fictional test fixture. Physical-device, power-loss, reinstall and clean-device restore remain OPEN.

## Why this is a separate test

The [44/44 Linux Dart autosave tests](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43425363790) established rollback and recoverability across **real Linux SIGKILL**, including before COMMIT, after COMMIT without acknowledgement, and after acknowledgement. They cannot establish how **Android Keystore keys, Flutter isolates and app-private data** behave across Android `am force-stop` and a fresh app process.

The [earlier A3.3 Android editor test run](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43422522118) built its APK but could not install it because Android's package service was unavailable. A3.3 widget/lifecycle assertions remained **unexecuted**. An updated cold-boot CI checks package manager readiness and runs suites sequentially; see [Flutter Android test workflow](../.github/workflows/flutter-keystore-bridge.yml).

## New implementation

- [Dedicated Dart test entrypoint](../spikes/flutter_bridge_probe/lib/crash_probe_main.dart): no real editor/user text; creates an encrypted SQLite3MultipleCiphers fixture with a **random key wrapped by actual AndroidKeyStore** and stored in private app files, never the cache or external storage.
- [Android test-only native bridge](../spikes/flutter_bridge_probe/native/MainActivity.kt): restricted diagnostic methods expose only the private directory, ADB launch phase and a small generic status marker. **Raw key material or journal text never enters the marker.**
- [Three-phase ADB script](../spikes/flutter_bridge_probe/ci/run_force_stop.sh): installs a disposable **debug test APK**, clears only the test app data at setup, launches it, waits for committed state, issues real `am force-stop`, confirms the original PID disappears, then launches a new process while keeping the same encrypted file and Keystore alias.
- [Dedicated CI workflow](../.github/workflows/android-force-stop-recovery.yml): builds debug fixture against Flutter stable with explicit `sqlite3mc` native hook; runs the three phases inside an Android API 35 emulator.

## Required Android runtime sequence

| Phase | Before force-stop | Required confirmation |
|---|---|---|
| 1. `write_v1` | Create a new encrypted app-private fixture; commit fictional Telugu-English v1 | `ACK_V1` emitted *after* database receipt, reread, and integrity check |
| 2. `reopen_and_write_v2` | New Android process reuses original stored wrapping-key envelope; verifies exact v1, commits v2 | `ACK_V2` emitted after v1 was recovered, v2 committed, and v2 reread |
| 3. `reopen_v2` | Third Android process reuses original AndroidKeyStore key and encrypted database without resetting | `RECOVERED_V2` emitted only if exact body, title, revision and integrity agree |

The script **force-stops after phases 1 and 2** and confirms `pidof` no longer returns the app process. The test never clears app data between phases; clearing app data would undermine the claim. When all checks pass, the debug-only test application is uninstalled.

## Scope and remaining release blockers

Even if CI turns green, this only shows **two already-acknowledged fictional saves** surviving Android emulator force-stop/relaunch with the same installed application. It **does not** prove:

- Unsaved keystrokes survive a kill before debounce or before SQLite acknowledgement.
- Sudden power loss, full storage, corrupted WAL, low-memory eviction, Android key invalidation, reboot, upgrade or reinstall.
- Actual Telugu keyboard IME composition from a physical keyboard.
- Hardware-backed/StrongBox key storage, biometric policy, secure memory wiping, or independent recoverable backups.
- The approved premium journal UI is connected, a production database schema is finalized, or a safe release APK exists.

**A3.4 dedicated Android emulator process-restart proof PASSED.** **A3.3 Flutter editor widget/lifecycle integration remains a separate pending gate**; physical-device security, reinstall/power-loss and authenticated clean-device backup/restore are not yet verified.
