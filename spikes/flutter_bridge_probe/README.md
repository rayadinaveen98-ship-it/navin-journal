# Stage 4 A2.4 — Flutter → AndroidKeyStore bridge probe

**Only fictional data.** This is an isolated, debug-only Flutter engineering harness. It is **not** Navin Journal, not a production APK, not a tested user-data vault, and must not accept real diary entries.

## What is in the repository

- [lib/android_key_bridge.dart](lib/android_key_bridge.dart) — typed Dart `DeviceKeyProtector` implementation over the private platform channel `navin_journal/security_key_wrap_v1`, compatible with our existing [A2.2 key-envelope coordinator](../key_lifecycle/lib/key_envelope_coordinator.dart).
- [native/MainActivity.kt](native/MainActivity.kt) — disposable Flutter Android host that sends method calls to the [existing native Keystore adapter](../key_lifecycle/android/src/main/kotlin/com/navinjournal/security/spike/AndroidKeystoreKeyProtector.kt). Keystore work is executed off the UI thread and returns a coded error instead of logging native exception details.
- [lib/main.dart](lib/main.dart) — isolated diagnostic UI. It generates a random test database key; creates fictional, encrypted SQLite sample content; closes and reopens through the native AndroidKeyStore adapter; rotates the wrapping key while preserving the encrypted database key; and deletes this deliberately temporary *fictional* test afterward.
- [test/android_key_bridge_test.dart](test/android_key_bridge_test.dart) — **14** Dart/Flutter mock-channel contract tests for binary payloads, type/length validation, alias checks, missing plugin, and fail-closed errors.
- [integration_test/android_key_bridge_integration_test.dart](integration_test/android_key_bridge_integration_test.dart) — **2** Android emulator integration tests (complete real-platform roundtrip and missing-alias rejection).
- [GitHub CI workflow](../../.github/workflows/flutter-keystore-bridge.yml) — generates a temporary Flutter Android project from the current Flutter stable SDK, injects these tracked source files, runs unit tests, builds a debug-only engineering APK, and attempts the real Android API 35 emulator integration tests.

## Why the Android app scaffold is generated in CI

We do not commit a separate large Flutter template project or pretend this is a production UI. CI creates a disposable project under `spikes/_generated_bridge_probe/`, then injects the version-controlled Dart code and the tested native Kotlin Keystore implementation. The Flutter SDK version and build outcome are recorded by CI, rather than assumed.

## Security boundaries

1. Device-bound AES-256-GCM wrapping keys are created in AndroidKeyStore. No implicit key provision occurs when the Dart layer calls `unwrap`; native failures are surfaced with sanitized error codes.
2. The 32-byte database encryption key **crosses the platform channel** as binary. Copies in Dart/Flutter's codec and JVM/native heap may persist; `fillRange` on one byte array **does not** prove memory-wide zeroization.
3. The demo performs deletion of temporary fixture files and aliases on exit, **only because the data is fictional**. Production must never delete or reinitialize an unknown vault to recover from a key error.
4. The native bridge exposes a powerful `retire` operation, intentionally retained for key rotation; production must constrain when and how the app may invoke it. Do not expose this test bridge to arbitrary user-generated scripts or remote callers.
5. The code is Android-only. iOS Keychain, hardware-backed key attestation, biometric gating, key invalidation behavior, portability, OS backup exclusions and a secure archive recovery mechanism remain unimplemented.
6. The app contains **no real journal editor and no autosave**. A successful demo roundtrip does not establish safe process death, reboot, reinstall, full-disk, or clean-device recovery.

## Expected validation ladder

- Flutter static analysis and 14 mocked channel tests.
- Android debug APK compilation with SQLite3MultipleCiphers native library.
- Android API 35 emulator: run two true Flutter→Kotlin→AndroidKeyStore and encrypted SQLite tests.
- Then physical Android hardware, reboot/reinstall/biometric policy, Flutter lifecycle and manual security QA.
- Only after the A2 device/recovery gate is satisfied, begin connecting A3 durable autosave and private editor storage.

### Running the CLI experiment

The CI workflow is the reproducible entrypoint; it invokes `flutter create` to produce the disposable scaffold. You can reproduce these steps locally using the commands under the [GitHub workflow](../../.github/workflows/flutter-keystore-bridge.yml).

**Do not publish this debug test harness or treat it as a usable journal.**
