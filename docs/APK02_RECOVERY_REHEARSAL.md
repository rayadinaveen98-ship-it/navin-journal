# APK 02 — Explicit encrypted recovery rehearsal (FICTIONAL ONLY)

**Stage 5 checkpoint:** 14 November 2026. **Verified** against synthetic test data; **NOT a private-data beta, external backup, or production restore feature**.

## Actual functionality

The existing encrypted **Library → Review restore safety** screen now includes an independent, optional **Test fictional encrypted recovery** control. It does **not** restore, publish, replace, erase or clean the user's active journal, and it never performs a destructive operation on interrupted recovery candidates.

When a user deliberately triggers this fictional-only diagnostic:

1. The app obtains a fresh, random independent 256-bit `RecoveryKey` in memory. It asks the existing single-owner `JournalEditorWorker` for a consistent **AES-256-GCM encrypted full-schema v2 snapshot** of the active fictional vault.
2. It creates a uniquely named owned temporary directory and a fresh destination database key; calls `PortableRecoveryWorker.restoreToNewVault`, which authenticates the archive and restores to an **absent directory** only. It uses the existing Linux/Android native no-replace publication and fsync barrier, not a merge or overwrite.
3. It reopens the restored encrypted SQLite vault through a **separate background worker** using the destination key and verifies SQLite integrity, journal count, entry count, journal ownership and revision count. The restorer itself validates the authenticated full snapshot and media integrity during the restore.
4. It closes the independent worker, deletes **only its own newly created disposable rehearsal root** and clears the ciphertext/key buffers. It does not enumerate/clean up unknown interrupted stage directories. Failures show a neutral, non-secret error without claiming recovery.
5. The UI returns only aggregate fictional record counts and the explicit statement **"NOT BACKED UP"**. Neither journal text nor filenames, paths, ciphertext, raw recovery key or destination key are copied to the UI or exported off the device.

This is a useful functional connection between the already tested export and restore modules, **not** independent recovery. The ephemeral new vault is intentionally destroyed; no user-held archive or usable off-device key survives.

## Verification

**Library gate:** [GitHub Actions run 43579984505](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43579984505) — all passed:

- Strict Flutter static analysis.
- **46/46** autosave and IME safe-exit tests.
- **37/37** encrypted worker contract tests (includes real encrypted export → new-vault restore → independent reopen and fail-closed unavailable source).
- **16/16** Flutter visual/editor widgets.
- **28/28** Library/index and real-worker navigation tests, including UI showing a nonsecret verification report, leaving the active encrypted journal untouched, preserving unknown abandoned stage bytes, and neutral failure UI.
- **5/5** read-only restore verdict widgets.
- Android fictional Library debug APK built and uploaded — Actions artifact ID **14107817814**, name `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`.

**Native regression:** [API-34 Android run 43579984540](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43579984540) — passed the existing HOME, synthetic Telugu IME, AndroidKeystore and two real force-stop/reopen phases. This is **not** a physical-device or fresh-device rehearsal test.

**Source:** [PR #7](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/7) merged via `ed0208fc5df0b2517a9cecb937f0a5aa4fed3b2a`.

### Important distinction between tests

The genuine encrypted export, staged restore and independent reopen are executed in dedicated Dart worker tests; Flutter widget tests use a **nonsecret immutable prevalidated report** injected into the view to avoid running native restore operations inside Flutter's simulated-time widget harness. The real Android app wires the button to `FictionalRecoveryRehearsal.run`. Passing the UI tests and compiling the Android APK do **not** claim that this new button has been physically tapped on a real handset.

## Safety gaps still open

- No user-held independently stored encrypted archive, secure recovery-key presentation/custody or separately retained backup.
- No Android Storage Access Framework document picker for selecting/saving archives, no protected file-import UX, no independent fresh-device recovery-key flow.
- No physical phone/tablet QA of this button, cross-device key handling, OS power-loss, low storage, OEM restrictions or signed-release hardening.
- Current temporary rehearsal may leave **its own disposable** files if Android forcibly kills the process before cleanup; it must not be treated as a durable or production-safe backup path.
- No real user typing/private diary data enabled and no independent security review.

**Next product gate:** design and implement user-controlled **off-device archive export and separate key custody** in a highly restricted fictional-only workflow, then demonstrate import and non-destructive restore on a clean device. The real private-data beta must remain blocked until that and the remaining security/device acceptance gates pass.

The approved Still Pages + Memory Atelier theme and Midnight Archive dark direction are unchanged.
