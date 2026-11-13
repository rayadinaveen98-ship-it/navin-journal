# APK 02 — Android Writing Studio + encrypted journal core integration

**Scope:** debug-only, fictional data. **Not a release APK; not a production diary.**

## Implemented sources

- [Flutter diagnostic Writing Studio](../preview_app/lib/apk02_probe_main.dart) reuses approved Folded Page primitives. Its fields are read-only scripted fictional Telugu/English/emoji samples.
- FictionalJournalBridgeService uses the [existing A2.4 Flutter KeyStore bridge](../spikes/flutter_bridge_probe/lib/android_key_bridge.dart) and [native AndroidKeyStore implementation](../spikes/flutter_bridge_probe/native/MainActivity.kt). No hard-coded database key or plaintext SQLite fallback.
- All SQLite3MultipleCiphers creation, journal/entry writes, version/revision reads and reopen checks run on separate Dart isolates through [journal_core](../packages/journal_core/lib/journal_vault.dart), off the render isolate.
- Three scripted Android app launches: create and verify fictional v1; reopen and commit fictional v2 with historical revision; reopen v2 and verify exact history after real process termination.
- [ADB emulator script](../preview_app/ci/apk02_android_roundtrip.sh) performs two actual Android force-stops. Only a disposable debug app is reset before the very first phase.
- [CI workflow](../.github/workflows/apk02-android-vertical.yml) runs strict Flutter analysis, six UI tests, Android APK compilation and the API-35 emulator. It uploads the diagnostic APK only when all stages pass.

## Open validation gates

**No real private-data entry is authorized.** The disposable debug envelope is not production-hardended for power-loss/failure and raw database keys cross managed memory. This is not yet the functional APK 02 beta. Original APK 01 remains a separate, sample-only visual preview.

Required follow-up: complete editor autosave and save-state UX, secure app data lifecycle, native race-free no-clobber and fsync, encrypted v2 backup and clean Android reinstall with a separately retained recovery key, bounded-memory attachment streaming, physical device/tablet tests, Telugu IME, accessibility and independent security review.

Do not claim Android integration passed until the live emulator workflow reports success. Emulator success is still distinct from physical-device validation.
