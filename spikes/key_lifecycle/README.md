# Stage 4 A2.2 — Device-wrapping-key lifecycle proof of concept

**Status on 13 November 2026:** Protocol tested with fictional data and a software key-provider double; Android Keystore adapter **compiled and passed 12/12 API-35 emulator runtime tests** (not tested on physical device). This is not a production key lifecycle or private journaling app.

## Verified evidence

- [Linux key-envelope and encrypted SQLite tests](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43410218147): **14/14 Dart tests passed**, plus static analysis.
- [Android API-35 Kotlin compilation](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43410753987): **successful `compileDebugKotlin`**, no device or emulator execution.
- [Android API-35 emulator runtime instrumentation](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43412815431): **12/12 tests passed** with the actual AndroidKeyStore framework provider. See [A2.3 QA matrix](../../docs/STAGE4_A2_3_ANDROID_RUNTIME.md).
- [A2 encrypted-file baseline](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43408840728): **13/13 checks passed** for file encryption and wrong-key rejection.
- [A1 transactional SQLite baseline](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43405223151): **18/18 tests passed**, not a native app.

## Code

- [Key-envelope coordinator](lib/key_envelope_coordinator.dart) — file-backed, versioned authenticated wrapping-envelope protocol.
- [Linux proof tests](test/key_envelope_test.dart) — fake AES-256-GCM provider with keys kept in memory **only for automated testing**.
- [Staged Android Keystore wrapper](android/src/main/kotlin/com/navinjournal/security/spike/AndroidKeystoreKeyProtector.kt) — AndroidKeyStore AES-256-GCM candidate, native API minimum 23.
- [Android library compilation project](android/build.gradle.kts) — Gradle, Android API 35; compilation verified.
- [OS backup/transfer policy examples](android/policy_examples/data_extraction_rules.xml) and [pre-Android-12 example](android/policy_examples/full_backup_content.xml) — **not installed** in a native app.

## Architecture

Vault data-encryption key (DEK) is a randomly generated 32-byte secret used to open the existing SQLite3MultipleCiphers journal. The platform-specific wrapping key (KEK) is intended to remain inside Android Keystore / iOS Keychain, not be written to disk or backed up as a raw key.

An unencrypted metadata file contains only the vault ID, active alias, generation, and authenticated wrapped DEK (nonce, ciphertext and tag). It contains **no journal entry text or raw DEK**. This file still exposes limited metadata. Actual key-provider behavior and memory lifetimes are platform-specific and have not been security-reviewed.

### Wrapping-key rotation (not SQLite rekey)

1. Confirm an existing encrypted SQLite file and an authenticated active envelope can be opened.
2. Provision a **new** alias without replacing the old alias.
3. Wrap the **same** DEK under the new KEK and write a two-slot envelope, retaining the old active slot.
4. Unwrap and compare the new slot to the original DEK.
5. Promote the new slot as active in a second metadata commit.
6. Only after verification, reduce to a one-slot envelope, then retire the old KEK.

A crash after staging can be resumed; a crash after promotion still leaves both slots. An error after the old slot has been removed but before the old alias is deleted may leave a stale keystore alias, not an inaccessible vault.

This is a **KEK rewrap**; it does not rotate the database's data key, regenerate its cipher salt, or re-encrypt database pages. The older device key must not be considered cryptographically revoked until platform retirement and other copies/recovery policies are verified.

## Automated checks (14 passed)

| # | Test | Result |
|---|---|---|
| 1 | Fresh vault, wrapped envelope only; encrypted database opens | Pass |
| 2 | Coordinator restart reopens same encrypted SQLite contents | Pass |
| 3 | Key rewrap stages a new slot while retaining original key | Pass |
| 4 | Safe finalization retires old key only after envelope promotion | Pass |
| 5 | Injected failure after stage → resume and recover | Pass |
| 6 | Injected failure after promotion → finalize and recover | Pass |
| 7 | Failure after obsolete slot removal retains accessible vault | Pass |
| 8 | Missing device keys do not trigger reset or regeneration | Pass |
| 9 | Tampered authentication tag rejects unlock | Pass |
| 10 | Unsupported envelope schema refuses silent reinitialization | Pass |
| 11 | Database without envelope does not get reset | Pass |
| 12 | Envelope without database does not get reset | Pass |
| 13 | Failure before metadata rename preserves old envelope | Pass |
| 14 | Second rotation is blocked until pending rotation finalized | Pass |

## Critical limitations — A2.2 is not finished for production

- **Platform binding:** The Android Kotlin wrapper is compiled and **12 emulator instrumentation tests pass**; **no physical phone test**, Flutter MethodChannel, hardware-backed key attestation, true reboot/reinstall or biometric gating has been performed.
- **Platform unlock policy:** The Kotlin candidate uses `setUserAuthenticationRequired(false)` explicitly for its test scope. There is no biometric-gated journal, user presence requirement or app lock.
- **Durability:** The envelope writes are flushed and renamed on a Linux test filesystem, but no parent-directory fsync, multi-process exclusivity, Android power-loss or filesystem-failure guarantee is proved. Temporary metadata files are not cleanup-hardened.
- **Key memory:** The DEK crosses Dart and SQLite native memory; best-effort byte clearing does not prove all runtime copies are wiped. The fake provider stores KEKs in ordinary process memory and is **never an acceptable shipping implementation**.
- **Recovery:** A lost/replaced Android Keystore key alone cannot unlock the old DEK. A separate user-controlled **authenticated encrypted archive** with an independently recoverable key is mandatory. Device-only encryption is not a cross-device backup.
- **OS backup:** Android can copy application data unless configured otherwise. The committed policy XML files are examples only and must be merged into the real native manifest and checked for cloud, device-to-device and future platform transfers. Avoid shipping a backed-up envelope that cannot be decrypted after restore.
- **Manifest attacks:** The metadata file is not a trusted monotonic counter. Rollback/replay, alias orphan cleanup, concurrently opened processes and out-of-order rotation are not fully hardened.
- **Platform parity:** iOS Keychain, Windows storage, real app lifecycle, attachments, search indexes, analytics/logs, screenshot redaction, and independent security review remain undone.
- **Full data-key rotation:** The protocol is a wrapping-key rotation. A separate full SQLite rekey/restore plan must be designed and fault-tested before supporting that operation.

## Next gates

1. **A2.3 Android runtime:** Emulator AES-GCM/alias tests passed (12). Physical Android device testing, invalidation behavior with actual biometric policy, reboot/reinstall and long-lived key persistence remain OPEN.
2. **A2.4 Flutter bridge / lifecycle:** connect app-isolated storage with a typed native channel and measured key-memory exposure. Add concurrency/lock semantics and crash-injection.
3. **A4 portable recovery:** design/test authenticated user-controlled recovery archive separately, without relying on a device-bound key.
4. **A3 autosave:** implement `dirty → saving → saved/error` against a production-approved encrypted store, then force-stop and reopen tests.
5. Complete physical-device UX/IME and manual accessibility gates inherited from Stage 3.

Nothing in this spike should be described publicly as a secure finished diary.

## Sources

- [Android Keystore](https://developer.android.com/privacy-and-security/keystore)
- [Android KeyGenParameterSpec](https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec)
- [Android backup-exclusion guidance](https://developer.android.com/privacy-and-security/risks/backup-best-practices)
- [SQLite3MultipleCiphers rekey/salt behavior](https://utelle.github.io/SQLite3MultipleCiphers/docs/features/feat_rekey/)
