# Navin Journal — Stage 4 A2.3 Android Keystore runtime QA

**Date:** 13 November 2026  
**Purpose:** Validate the actual Android `AndroidKeyStore` provider, beyond Kotlin compilation and Linux fake-provider tests.  
**Verified status:** **12/12 Android API 35 emulator instrumented tests PASSED** on 13 November 2026 in [run 43413956404](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43413956404). Android test-source compilation also passed in [run 43413956366](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43413956366). **A2 production security gate remains OPEN.**

## Source and execution

- [Android Kotlin Keystore adapter](../spikes/key_lifecycle/android/src/main/kotlin/com/navinjournal/security/spike/AndroidKeystoreKeyProtector.kt)
- [AndroidJUnit4 instrumented tests](../spikes/key_lifecycle/android/src/androidTest/java/com/navinjournal/security/spike/AndroidKeystoreInstrumentedTest.kt)
- [Android API 35 emulator CI](../.github/workflows/android-keystore-emulator.yml)
- [Compiler-only CI](../.github/workflows/android-keystore-compile.yml)
- [A2.2 Linux key-envelope protocol](../spikes/key_lifecycle/README.md)

The instrumented tests use the real Android provider in an Android emulator, with freshly generated **fictional** 32-byte values. They are not proof of hardware-backed encryption, biometric policy, crash-safe storage, production Flutter integration, or clean-device recovery.

## Runtime test matrix

| Test | Expected behavior |
|---|---|
| Create AES-256-GCM wrapping key and unwrap | Decrypted bytes exactly equal generated sample key |
| Duplicate alias provisioning | Existing key cannot be silently replaced |
| Missing alias wrap | Fails without creating a key |
| Tampered GCM authentication tag | Cannot decrypt |
| Wrong authenticated context (AAD) | Cannot decrypt across vault IDs |
| Tampered ciphertext | Cannot decrypt |
| Reinstantiate protector | Existing Android Keystore alias remains usable |
| Retire alias | Old wrapped material becomes inaccessible; missing alias not recreated |
| Rewrap under second alias | Same vault DEK accessible via new alias before and after old alias retirement |
| Repeated wrapping | Fresh random nonce and different ciphertext |
| Invalid key, nonce, tag, empty AAD | Rejected before decryption |
| AndroidKeyStore key characteristics | AES-256, secret not exportable as raw key, test policy has no user-authentication requirement |

## CI evidence and initial setup correction

The initial emulator CI run failed before any test execution because the runner invoked Gradle at the repository root. The workflow now calls `gradle -p spikes/key_lifecycle/android connectedDebugAndroidTest` as a single command. The corrected run [43413956404](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43413956404) booted an emulator, reported **Starting 12 tests** and **Finished 12 tests** on Android API 35, and completed with **BUILD SUCCESSFUL**. Generated JUnit/HTML test reports are uploaded as a GitHub Actions artifact.

The separate [Android test-source compilation run 43413956366](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43413956366) succeeded. These are independently verifiable CI results, not a claim of physical-device tests.

## Emulator vs physical Android

Emulator tests exercise real Android framework APIs but generally run against virtualized or software security components. They **do not prove** hardware security module / StrongBox residency, lock-screen behavior, user-authentication enforcement, or OEM-specific Keystore compatibility. A test run on a physical Android handset is a separate gate.

## Work that remains

- Validate wrapping key across **actual process termination/reboot**, device-lock transitions, system update, and (for a dev-only test vault) app reinstall. Reinstall may destroy Keystore keys; production must offer a separate recovery path.
- Add and verify Flutter-to-Kotlin integration with structured error handling, non-logging of secrets and no silent vault reset.
- Decide user-authentication policy; the isolated Kotlin candidate intentionally uses `setUserAuthenticationRequired(false)` and does not provide a biometric lock.
- Audit native-memory handling of raw DEKs; device-bound keys alone do not make a restorable archive.
- Verify backup/restore policy and independent user-controlled recovery, protected thumbnails/search/caches, and third-party security review.
- Add A3 transactional autosave and A4 authenticated archive/clean-device restoration tests on real Android.

**Do not enter real private diary content into these engineering test packages.**

## Final assertion hardening

After the first passing Android run, the three tag/ciphertext/AAD tamper tests were tightened to require **`GeneralSecurityException`**, rather than any exception. [Final successful instrumented rerun 43413956404](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43413956404) again reported **12 tests started, 12 finished and BUILD SUCCESSFUL**. Android test-source compilation [43413956366](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43413956366) also passed. These results remain emulator-only.
