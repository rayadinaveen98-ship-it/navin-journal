# APK 02 portable encrypted recovery — clean Android reinstall gate

**Status: Android test in verification. FICTIONAL FIXTURES ONLY.** No real private journal import is authorized.

## Scope and architecture

The reusable Dart encrypted worker now exports a transactional, validated full-journal snapshot as a versioned `NJR-RECOVERY-2` AES-256-GCM authenticated archive under a **fresh independent random 256-bit recovery key**. Archive ciphertext and recovery key must be retained separately, outside the source Android app.

[PortableRecoveryWorker](../packages/journal_editor/lib/portable_recovery_worker.dart) restores an independently authenticated archive into a newly keyed SQLite3MultipleCiphers database inside a previously nonexistent directory. It runs staged import, transaction commit, close/reopen and complete schema comparison off the Flutter UI isolate, rejects known destination collisions, and never replaces an existing database. Native Android directory no-replace/fsync/power-loss safety is **not yet achieved**.

The [fictional Android probe](../preview_app/lib/apk02_portable_recovery_main.dart) connects this worker to the Android Keystore envelope bridge. Its separate [CI workflow](../.github/workflows/apk02-portable-reinstall.yml) uses [ADB script](../preview_app/ci/apk02_portable_reinstall.sh) to simulate an actual removal of the original Android application before reinstallation. The only app-created test data is explicitly fictional English/Telugu text and one historical revision.

## Test evidence

- [29/29 encrypted editor and portable-recovery tests passed](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43556363294), strict Dart static analysis clean. Six new recovery tests cover encrypted export without plaintext, original vault/key deletion, offline recovery-key reentry, version/history recovery, tampering and wrong-key rejection, no replacement of existing destination, and new database-key isolation.
- **Android clean reinstall**: [CI workflow](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/workflows/apk02-portable-reinstall.yml). Do NOT mark passed until the separate fresh-install run produces all `PORTABLE_EXPORT_READY`, `PORTABLE_WRONG_KEY`, `PORTABLE_RESTORE_OK`, and `PORTABLE_REOPEN_OK` markers and passes the workflow.
- Android API-34 same-install Keystore recovery `ACK_V1 → ACK_V2 → RECOVERED_V2` after two real force-stops **previously passed** in [run 43479108180](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43479108180). That is a different scenario and must not be substituted for this clean-install test.

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

- Native race-free no-clobber publication and directory/file fsync, crash/power loss and disk-full injection; resumable oversized archive streaming, keyed device-level restore state, consistent media and thumbnail preservation.
- Independently held key onboarding and secure human reentry with warnings on irreversible loss; no secret in logs, app preferences, OS backups, clipboard or screenshots.
- Real UI for archive save/share/import, encryption key custody and lost-key handling, authenticated restore preview with journal/media counts, versioning/migrations and duplicate/merge policy.
- Physical phone/tablet testing, biometric/app lock, accessibility, Telugu IME, device-to-device transfer and security review.
- Release-signed APK, honest backup status and never claiming cloud sync or guaranteed recovery before it exists.

**Do not use any diagnostic APK to store or import personal diary entries.**
