# Stage 5A — retained recovery candidate on real Android Keystore (API 34)

> **Update 14 November 2026:** This page is the historical **PR #11 retained-candidate proof**. The subsequently implemented, explicitly approved **no-clobber activation** passed all PR #12 Android CI gates and was merged. For the current Stage 5A acceptance and remaining physical release blockers, see [Stage 5A safe activation](STAGE5A_SAFE_ACTIVATION_2026-11-14.md). Statements below saying activation is still unimplemented describe the earlier PR #11 checkpoint.

**Date:** 14 November 2026  
**Decision:** **ENGINEERING / ANDROID EMULATOR VERIFIED** for FICTIONAL SCRIPTED DATA ONLY. **NOT** physical-device certification, durable user-approved activation, an independently confirmed user backup, or an approved private diary beta.

## Purpose and difference from previous milestone

The Stage 5A retained-candidate engine had already passed Linux contract tests with an explicitly **insecure fake** wrapping-key protector, and its Android wiring built successfully. **PR #11** now proves the **same retained-candidate service** can use the real `FlutterAndroidKeyProtector` backed by the Kotlin **Android Keystore**, retain a newly encrypted vault after an original app uninstall, reopen it after an actual app force-stop, and fail closed when **only its own wrapping alias** is retired. The other separately protected encrypted vault stays readable throughout.

## Actual sequence in API-34 emulator

The CI runner creates a disposable Android debug-only probe with native SQLite3MultipleCiphers and Android Keystore; no real user content is ever entered.

1. Create a scripted fictional English/Telugu+emoji journal with one current entry and its prior version. Export its authenticated full-schema v2 AES-256-GCM archive under a distinct randomly generated 256-bit recovery key.
2. Copy archive and key into permission-restricted **CI-host temporary files OUTSIDE Android**, without printing their bytes. **Uninstall** the original Android probe and confirm the old package/Keystore-bound vault is gone.
3. Install the probe afresh; inject only the ciphertext and external key into this **new** app's sandbox. Confirm wrong-key refusal without staging and existing native low-storage pre- and post-rename behaviors; restore an independently keyed first new-device encrypted vault and reopen it after force-stop.
4. A second, explicitly test-only handoff copies the same independently held ciphertext and key back into the clean-install sandbox. `FictionalRetainedRecoveryCandidate.prepare` authenticates the file **before any candidate filesystem or alias creation**, creates an **exclusive** sibling `.reservation`, provisions a fresh native Android Keystore alias distinct from the existing restored vault, and publishes the new encrypted DB under an **absent separate child directory** via native no-replace/fsync. It reopens via its *saved envelope* and validates the fictional record/media counts.
5. Attempt duplicate retention into that same candidate: must fail without replacing its database, envelope, or reservation. Confirm the existing independently keyed journal still opens.
6. Delete **both** one-time imported archive and recovery key from Android. **Force-stop the actual Android process** and relaunch in a separate phase. `FictionalRetainedRecoveryCandidate.reopen` uses **only** the retained ciphertext DB and persisted Keystore envelope, with no source archive, entered key, or previous process DEK. Assert exact fictional Telugu/emoji current content and historical revision in addition to aggregate counts, and verify existing journal independently.
7. Force-stop, then deliberately retire **only the retained candidate's own test alias**. A fresh reopen must fail closed and **must not** delete the retained encrypted database, envelope, or exclusive reservation. The separate previously restored vault still decrypts.
8. Uninstall the disposable probe and securely clean CI-host fixture files. Do not expose any private text, raw key, file path, or Keystore alias in CI logs.

## Verified GitHub evidence

**Critical native runtime proof:** [GitHub Actions 43589135432](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43589135432) — **SUCCESS**.

All ten nonsecret runtime markers passed:

- `PORTABLE_EXPORT_READY`
- `PORTABLE_WRONG_KEY`
- `PORTABLE_ENOSPC_PRE`
- `PORTABLE_ENOSPC_POST`
- `PORTABLE_ENOSPC_REOPEN`
- `PORTABLE_RESTORE_OK`
- `PORTABLE_REOPEN_OK`
- **`CANDIDATE_RETAINED`**
- **`CANDIDATE_REOPEN_OK`**
- **`CANDIDATE_KEY_LOSS_SAFE`**

Android debug artifact ID **14111249212**, name `apk02-PORTABLE-REINSTALL-FICTIONAL-ONLY-NOT-BETA`. This is a specialized **ADB test harness**, not the consumer Library app.

**Separate Library Android APK:** [GitHub Actions 43589135387](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43589135387) — **SUCCESS**, strict analysis, **46/46** autosave, **52/52** encrypted worker, **16/16** visual/editor, **31/31** Library/index and **5/5** recovery verdict tests, plus Kotlin/Flutter debug APK compile and upload. Artifact ID **14112195629**, name `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`.

**Existing API34 lifecycle regression:** [GitHub Actions 43589135396](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43589135396) — **SUCCESS**, synthetic Telugu IME, actual HOME and force-stop encrypted save/reopen, native Android Keystore. Independent of the retained-candidate runtime proof.

**Merged source:** [PR #11](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/11), squash SHA `d5848a293b230bd1e1679bfc4b712b9149422755`.

An early PR run failed at `retain_candidate` because the *previous portable restore correctly consumed/deleted* the temporary archive; it was not a failure of the retained-vault engine. The corrected runner independently retransfers both ciphertext and key from the CI-host copies before the candidate phase. The passing run and commit above are authoritative.

## Remaining risk and release boundary

- The test transfers an archive into Android via the **ADB diagnostic harness**, not by tapping a real Storage Access Framework picker. **Actual SAF provider/UI integration and manual user key entry are NOT exercised on Android by this test.**
- The API-34 emulator is **not physical OEM hardware**. No verified Android tablet, Samsung/Oppo/Xiaomi battery or storage behavior, physical Telugu Gboard, accessibility, reboot/power interruption, OS migration, low-free-disk storage on the retained-candidate path, or independent security audit.
- A retained candidate remains **quarantined**, never activated, merged, published, or automatically cleaned up. A permanent exclusive reservation is deliberately kept after success or failure. User-approved, no-clobber **activation only into an ABSENT active vault** still requires design, crash-safe implementation and separate validation.
- One-time recovery-key text and native/Dart method-channel copies cannot be reliably memory-zeroized; screenshots/clipboard attacks and real-device key custody remain separate review gates.
- **No personal writing is enabled.** This is not an approved disaster recovery, synchronization, user backup, private beta, public release, or production encryption claim.

## Next Stage 5A gate

Design and implement a **non-destructive, user-approved activation transaction** for an independently reopened, complete, device-key-enveloped candidate into a **provably empty active-vault slot** only. Before doing so, validate collision conditions and simulated crash points and retain quarantine/recovery paths; subsequently perform actual Android SAF, physical-device, key-loss, storage, and accessibility acceptance. Keep private writing disabled.
