# APK 02 — Android simulated storage-exhaustion validation

**FICTIONAL FIXTURES ONLY. Android API-34 simulated ENOSPC + post-force-stop reopen VERIFIED (7/7 Android phases).** This is a developer diagnostic, not a consumer backup/restore UI.

## New diagnostic architecture

- [PortableRecoveryWorker](../packages/journal_editor/lib/portable_recovery_worker.dart) now supports a strictly allowlisted `faultCheckpointForDiagnostics` parameter for **non-release builds only**. It injects synthetic errno 28 (`ENOSPC`) while encrypted restoration runs off the Flutter UI isolate. Other checkpoint names are refused, and this never deliberately fills real storage.
- [Android fixture](../preview_app/lib/apk02_portable_recovery_main.dart) and [ADB script](../preview_app/ci/apk02_portable_reinstall.sh) add three separate phases **after the source app has been uninstalled, a clean app installed, and a wrong recovery key rejected**.
- **PORTABLE_ENOSPC_PRE:** inject after writing the staged readiness marker but before kernel no-replace rename. Expect `ProductRestoreRejected`, absent destination, no lingering owned staging paths and the encrypted archive still available.
- **PORTABLE_ENOSPC_POST:** use a different Android Keystore-backed destination key and inject after the successful `renameat2(RENAME_NOREPLACE)` but before parent-directory sync. Expect rejected acknowledgement, yet an existing published encrypted vault. The diagnostic must independently decrypt, integrity-check and compare fictional current/revision records; marker presence is insufficient.
- **PORTABLE_ENOSPC_REOPEN:** after a verified Android force-stop, unlock the new destination's Keystore envelope in a separate process and re-check the full fictional journal/history. No staging directories may remain.
- Finally, the **normal portable restore and reopen** still execute using the off-device encrypted archive, ensuring the test additions do not break ordinary clean-install recovery.

## Evidence and acceptance

Existing [Linux restore fault tests](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43561427213) passed 30/30 with actual SIGKILL and simulated ENOSPC. New editor-worker tests additionally check the synthetic pre-rename failure and retry, post-rename preservation and authenticated reopen, and invalid diagnostic checkpoint rejection.

[Android clean-reinstall workflow](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/workflows/apk02-portable-reinstall.yml) **passed as a whole** in run 43563086930, including all three new fault markers and four existing portable recovery markers. Keep this workflow as a regression gate for later implementation changes.

## Verified CI evidence

[Successful Android fault-injection and clean-reinstall run 43563086930](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43563086930) passed strict Flutter/Dart analysis, **32/32 encrypted editor/recovery tests**, **13/13 Flutter tests**, native Android debug APK compilation, and **all seven real emulator phases**:

1. `PORTABLE_EXPORT_READY`: ciphertext and recovery key exported off the original installation (05:51:04 UTC).
2. `PORTABLE_WRONG_KEY`: wrong independent key rejected after actual uninstall/reinstall (05:51:16 UTC).
3. `PORTABLE_ENOSPC_PRE`: simulated storage exhaustion before atomic publication failed closed, leaving no destination or stage (05:51:24 UTC).
4. `PORTABLE_ENOSPC_POST`: simulated failure after native rename preserved a decryptable and revision-checked target (05:51:33 UTC).
5. `PORTABLE_ENOSPC_REOPEN`: after a confirmed Android force-stop, the same ambiguous-acknowledgement target reopened under its own Android Keystore key and verified history (05:51:40 UTC).
6. `PORTABLE_RESTORE_OK`: subsequent clean-install restore with another new Keystore key succeeded (05:51:47 UTC).
7. `PORTABLE_REOPEN_OK`: ordinary restored journal reopened after a further force-stop (05:51:52 UTC).

GitHub Actions completed successfully and uploaded fictional-only debug artifact **14100889828**. All synthetic fault markers were produced by the **real Android app and encrypted isolate**, not a mock. This is **not** a real disk-full or power-loss hardware test.

## Unverified release gates

Physical Android storage exhaustion and OEM filesystems, actual device power loss and torn writes, large media/streaming, secure recovery-key UI, safely handling unknown orphan stages, audit of native secret lifetimes and an independently reviewed private journaling beta remain open. A successful synthetic fault check is not a guarantee that real low-storage conditions cannot corrupt data.

**Never automatically delete or retry a visible vault after a post-rename failure. Authenticated reopen is required. Never use fictional APK 02 builds for private writing.**
