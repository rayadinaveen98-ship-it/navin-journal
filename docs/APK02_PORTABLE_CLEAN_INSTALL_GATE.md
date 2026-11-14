# APK 02 portable encrypted recovery — clean Android reinstall gate

**Status: Android API-34 clean uninstall/reinstall, wrong-key rejection, independent-key restore and post-restore reopen VERIFIED (4/4). FICTIONAL FIXTURES ONLY.** No real private journal import is authorized.

## Scope and architecture

The reusable Dart encrypted worker now exports a transactional, validated full-journal snapshot as a versioned `NJR-RECOVERY-2` AES-256-GCM authenticated archive under a **fresh independent random 256-bit recovery key**. Archive ciphertext and recovery key must be retained separately, outside the source Android app.

[PortableRecoveryWorker](../packages/journal_editor/lib/portable_recovery_worker.dart) restores an independently authenticated archive into a newly keyed SQLite3MultipleCiphers database inside a previously nonexistent directory. It runs staged import, transaction commit, close/reopen and complete schema comparison off the Flutter UI isolate, rejects known destination collisions, and never replaces an existing database. Native Linux and Android API-34 no-replace/fsync **engineering integration has now passed** ([Linux core run 43560381700](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43560381700), [Android restore run 43560295633](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43560295633)); physical power-loss, low-storage, filesystem variation and final production durability remain **unverified**.

The [fictional Android probe](../preview_app/lib/apk02_portable_recovery_main.dart) connects this worker to the Android Keystore envelope bridge. Its separate [CI workflow](../.github/workflows/apk02-portable-reinstall.yml) uses [ADB script](../preview_app/ci/apk02_portable_reinstall.sh) to simulate an actual removal of the original Android application before reinstallation. The only app-created test data is explicitly fictional English/Telugu text and one historical revision.

## Test evidence

- [29/29 encrypted editor and portable-recovery tests passed](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43556363294), strict Dart static analysis clean. Six new recovery tests cover encrypted export without plaintext, original vault/key deletion, offline recovery-key reentry, version/history recovery, tampering and wrong-key rejection, no replacement of existing destination, and new database-key isolation.
- **Android clean reinstall VERIFIED** in [successful run 43558301280](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43558301280) (artifact **14099640721**, debug-only). API-34 emulator produced all four markers: `PORTABLE_EXPORT_READY` (04:51:53 UTC), `PORTABLE_WRONG_KEY` (04:52:08 UTC), `PORTABLE_RESTORE_OK` (04:52:17 UTC), and `PORTABLE_REOPEN_OK` (04:52:24 UTC). The runner confirmed original app uninstall, file absence in a fresh app sandbox, byte-identical authenticated archive reinjection, wrong-key no-staging, fresh Android Keystore database key, and exact version/history after a further force-stop. **29/29 encrypted worker/recovery tests and 13/13 Flutter widget tests passed** in the same workflow. The Android diagnostic itself was uninstalled after the test; the recovery secret was never printed in logs.
- Android API-34 same-install Keystore recovery `ACK_V1 → ACK_V2 → RECOVERED_V2` after two real force-stops **previously passed** in [run 43479108180](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43479108180). That is a different scenario and must not be substituted for this clean-install test.

- **Updated native publisher regression verified** in [Android run 43560295633](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43560295633): 4/4 portable markers, 29/29 encrypted recovery tests and 13/13 Flutter checks. Native code used the new atomic `renameat2(RENAME_NOREPLACE)` publication and fsync pathway. [Detailed Linux/native fault-injection evidence](APK02_NATIVE_RESTORE_PUBLICATION.md).

## Actual clean-install acceptance sequence

1. Install an isolated test package, create a fictional journal and version 1/2 revision through the validated background storage worker.
2. Export the encrypted portable archive; separately export its fictional test recovery key to the CI runner *outside* the Android sandbox. Never print the key to logs.
3. **Uninstall the original Android package**, deleting the old app-private DB and Android Keystore alias. Confirm the package is gone.
4. Install the same APK as a clean installation. Verify the old sandbox data is absent. Transfer only the encrypted archive and independent recovery key into its isolated fixture folder.
5. Attempt a wrong recovery key and verify there is **no new vault directory or Android Keystore envelope**. The old archive must remain unchanged.
6. Re-enter the correct independent key. Authenticate before provisioning the new Android Keystore alias; stage into a separate absent directory with a new random database key. Verify journal ID, current version 2 and historical version 1. Delete one-time import-key test input.
7. Force-stop the new Android process, then unlock and reopen the independently rekeyed vault via the *new* Android Keystore alias. Verify the same data/history. Uninstall the disposable test package.
8. Only after all steps succeed, report clean-install **fictional test** recovery verified. No consumer/private data may be accepted.

## Unresolved production release gates

- **Atomic no-clobber publication and native file/directory fsync are implemented and Linux/API-34 emulator tested**. Still open: actual crash/power loss and disk-full injection, device-specific filesystem behavior, resumable oversized archive streaming, app-level recoverable commit states, consistent media and thumbnail preservation.
- Independently held key onboarding and secure human reentry with warnings on irreversible loss; no secret in logs, app preferences, OS backups, clipboard or screenshots.
- Real UI for archive save/share/import, encryption key custody and lost-key handling, authenticated restore preview with journal/media counts, versioning/migrations and duplicate/merge policy.
- Physical phone/tablet testing, biometric/app lock, accessibility, Telugu IME, device-to-device transfer and security review.
- Release-signed APK, honest backup status and never claiming cloud sync or guaranteed recovery before it exists.

**Do not use any diagnostic APK to store or import personal diary entries.**
