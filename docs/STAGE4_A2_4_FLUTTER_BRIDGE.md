# Navin Journal — A2.4 Flutter-to-Android Keystore integration

**Status:** Engineering-only Flutter bridge and debug test harness are implemented. The current CI job determines compile/runtime acceptance; do not mark emulator/native integration passed until the matching workflow succeeds.  
**Project date:** 2026-11-13  
**User data:** **NONE. Fictional, disposable test fixtures only.**

## Scope

Connect the existing [A2.2 key-envelope coordinator](../spikes/key_lifecycle/lib/key_envelope_coordinator.dart) with the already instrumented [Android Keystore AES-GCM provider](../spikes/key_lifecycle/android/src/main/kotlin/com/navinjournal/security/spike/AndroidKeystoreKeyProtector.kt) through Flutter's platform-channel mechanism. Do not add journaling features, UI changes or cloud/network services.

Sources:
- [Flutter typed key adapter](../spikes/flutter_bridge_probe/lib/android_key_bridge.dart)
- [Android bridge host](../spikes/flutter_bridge_probe/native/MainActivity.kt)
- [Debug-only Flutter encrypted-SQLite experiment](../spikes/flutter_bridge_probe/lib/main.dart)
- [Fourteen Flutter MethodChannel tests](../spikes/flutter_bridge_probe/test/android_key_bridge_test.dart)
- [Two Android emulator integration tests](../spikes/flutter_bridge_probe/integration_test/android_key_bridge_integration_test.dart)
- [Flutter build + emulator workflow](../.github/workflows/flutter-keystore-bridge.yml)

## How the adapter works

The Dart `FlutterAndroidKeyProtector` implements the exact `DeviceKeyProtector` interface used in the tested A2.2 encryption-key envelope coordinator. It supports `provision`, `wrap`, `unwrap` and `retire` via one private named MethodChannel. It requires aliases matching the journal's `nj-v1-<32 hex>-gN` format and validates DEK, nonce, tag and ciphertext lengths.

The Android host receives binary payloads through Flutter's `StandardMessageCodec`, passes key-wrap operations to the existing AndroidKeystore implementation on a single worker executor, and returns responses to the engine on the Android main thread. Unexpected native exceptions produce sanitized error codes, never raw exception text or keys. A missing adapter or keystore error is surfaced, never substituted by a software key.

### Integration proof

The debug-only Flutter probe is intended to:
1. Generate a fresh fictional 32-byte data-encryption key and new AndroidKeyStore KEK alias.
2. Encrypt the data key into an authenticated envelope and create a **SQLite3MultipleCiphers** encrypted database.
3. Write a fixed fictional Telugu+English+emoji entry, close SQLite, then reopen it using the native unwrap bridge.
4. Rewrap under a different AndroidKeyStore alias without changing database key or pages.
5. Reopen again, finalize the wrapping-key rotation, re-open once more, and clean up the disposable fixture files.

The test must fail if the runtime loads ordinary unencrypted SQLite. To prevent an accidental default SQLite build, the Flutter probe's root `pubspec.yaml` and generated CI app both explicitly set the `sqlite3mc` native hook.

## Recorded partial evidence

- A2.3 Android runtime: 12/12 instrumentation tests passed on API 35 emulator, [run 43413956404](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43413956404).
- A2.2 Linux protocol: 14/14 test-double checks passed, [run 43410218147](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43410218147).
- A2.4 Flutter MethodChannel contract tests: 14 tests are implemented; CI result should be inspected from the [Flutter bridge Actions workflow](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/workflows/flutter-keystore-bridge.yml).

Do not infer a successful Android APK or full on-device SQLite roundtrip from unit or static-analysis success.

## Remaining security and reliability gates

- Raw DEK necessarily crosses the Flutter MethodChannel boundary and may be copied in Dart, Flutter codec, Java/Kotlin and SQLite native heaps; test byte-array clearing is best-effort only.
- AndroidKeyStore keystore residency on emulator is not evidence of **physical hardware / StrongBox security**.
- This is not a production plugin/lifecycle service: Activity-scoped executor, cancellation/detach and concurrent access need review.
- Native bridge exposes a key-retirement operation and has no app-specific authorization policy; hardening is required.
- The probe deletes its own disposable fixture on exit. **Production must never delete/reset a vault because key operations fail.**
- The envelope coordinator has unverified filesystem durability, multi-process locking and power-loss atomicity.
- Separate passphrase-based encrypted export/restore must work on a replacement device with no original Android Keystore key.
- No production Flutter UI, reliable autosave, user authentication/biometrics, iOS, real Android hardware checks, reboot/reinstall test or security audit exists.

**Acceptance:** Passing Flutter static checks, 14 contract tests, a successful debug Android build, and two real emulator integration tests are necessary for the A2.4 engineering spike. Production A2 security approval will remain open even when this probe passes.

Official Flutter reference: https://docs.flutter.dev/platform-integration/platform-channels
