# APK 02 — Android simulated storage-exhaustion validation

**FICTIONAL FIXTURES ONLY. Android workflow still needs a completed success before this gate can be marked passed.** This is a developer diagnostic, not a consumer backup/restore UI.

## New diagnostic architecture

- [PortableRecoveryWorker](../packages/journal_editor/lib/portable_recovery_worker.dart) now supports a strictly allowlisted `faultCheckpointForDiagnostics` parameter for **non-release builds only**. It injects synthetic errno 28 (`ENOSPC`) while encrypted restoration runs off the Flutter UI isolate. Other checkpoint names are refused, and this never deliberately fills real storage.
- [Android fixture](../preview_app/lib/apk02_portable_recovery_main.dart) and [ADB script](../preview_app/ci/apk02_portable_reinstall.sh) add three separate phases **after the source app has been uninstalled, a clean app installed, and a wrong recovery key rejected**.
- **PORTABLE_ENOSPC_PRE:** inject after writing the staged readiness marker but before kernel no-replace rename. Expect `ProductRestoreRejected`, absent destination, no lingering owned staging paths and the encrypted archive still available.
- **PORTABLE_ENOSPC_POST:** use a different Android Keystore-backed destination key and inject after the successful `renameat2(RENAME_NOREPLACE)` but before parent-directory sync. Expect rejected acknowledgement, yet an existing published encrypted vault. The diagnostic must independently decrypt, integrity-check and compare fictional current/revision records; marker presence is insufficient.
- **PORTABLE_ENOSPC_REOPEN:** after a verified Android force-stop, unlock the new destination's Keystore envelope in a separate process and re-check the full fictional journal/history. No staging directories may remain.
- Finally, the **normal portable restore and reopen** still execute using the off-device encrypted archive, ensuring the test additions do not break ordinary clean-install recovery.

## Evidence and acceptance

Existing [Linux restore fault tests](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43561427213) passed 30/30 with actual SIGKILL and simulated ENOSPC. New editor-worker tests additionally check the synthetic pre-rename failure and retry, post-rename preservation and authenticated reopen, and invalid diagnostic checkpoint rejection.

[Android clean-reinstall workflow](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/workflows/apk02-portable-reinstall.yml) **must pass as a whole**, including all three new phase markers, before Android fault handling is considered verified.

## Unverified release gates

Physical Android storage exhaustion and OEM filesystems, actual device power loss and torn writes, large media/streaming, secure recovery-key UI, safely handling unknown orphan stages, audit of native secret lifetimes and an independently reviewed private journaling beta remain open. A successful synthetic fault check is not a guarantee that real low-storage conditions cannot corrupt data.

**Never automatically delete or retry a visible vault after a post-rename failure. Authenticated reopen is required. Never use fictional APK 02 builds for private writing.**
