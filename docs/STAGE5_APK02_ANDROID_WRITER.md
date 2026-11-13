# APK 02 — Android Writing Studio + encrypted journal core integration

**Scope:** debug-only, fictional data. **Not a release APK; not a production diary.**

## Implemented sources

- [Connected Flutter diagnostic Writing Studio](../preview_app/lib/apk02_connected_main.dart) and [reusable screen](../preview_app/lib/connected_writing_studio.dart) use approved Folded Page primitives and the live encrypted editor worker. All test entry fields are read-only scripted fictional Telugu/English/emoji samples. The earlier `apk02_probe_main.dart` remains a previous proof entrypoint, but is not the active CI build.
- FictionalJournalBridgeService uses the [existing A2.4 Flutter KeyStore bridge](../spikes/flutter_bridge_probe/lib/android_key_bridge.dart) and [native AndroidKeyStore implementation](../spikes/flutter_bridge_probe/native/MainActivity.kt). No hard-coded database key or plaintext SQLite fallback.
- The [encrypted editor worker](../packages/journal_editor/lib/journal_editor_isolate.dart) uses [journal_core](../packages/journal_core/lib/journal_vault.dart) and SQLite3MultipleCiphers off the Flutter render isolate. The 23 encrypted worker contract tests, 13 deterministic Flutter tests, and 4 full encrypted Library/Reader/Writer widget tests have passed on Linux; none substitutes for the Android Keystore test.
- Three scripted Android app launches: create and verify fictional v1; reopen and commit fictional v2 with historical revision; reopen v2 and verify exact history after real process termination.
- [ADB emulator script](../preview_app/ci/apk02_android_roundtrip.sh) performs two actual Android force-stops. Only a disposable debug app is reset before the very first phase.
- [CI workflow](../.github/workflows/apk02-android-vertical.yml) runs strict Flutter analysis, 13 deterministic UI tests, 23 encrypted editor-worker integration tests, Android debug APK compilation and a **currently rerunning API-34** emulator crash-recovery gate. The experimental APK is uploaded only when all stages pass.

## Emulator-host failure and remediation (13 November 2026)

- [Failed run 43463736400](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43463736400) passed all its Flutter/code gates and **compiled its Android debug APK**, but the third-party Android emulator runner failed while configuring the host image: `adb shell input keyevent 82` returned **broken pipe / exit 224** shortly after `sys.boot_completed=1`. The app never reached the journal-recovery script. This is **not evidence of success or failure of journal process recovery**.
- To isolate the host/boot issue, the emulator uses **API 34** with the host animation toggle disabled, an explicit boot timeout and 2-core/3072-MB resources. Inspection of the failed run's detailed logs revealed `ProbeKVM: This user doesn't have permissions to use KVM (/dev/kvm)`, then `-accel off`, a **497-second software-emulated boot**, and an ADB broken pipe. This is the likely underlying CI instability, **not a demonstrated journal-store failure**. The workflow now explicitly grants the CI runner `/dev/kvm` read/write permissions if that character device is present; it logs a warning when hardware acceleration is unavailable. [Acceleration-enabled test run 43479108180](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43479108180) is **pending validation**. Host-only setup changes do not modify the test APK or its keys.
- Continue to block any Android recovery success claim until `ACK_V1`, `ACK_V2` and `RECOVERED_V2` are actually emitted from three Android app launches, including two verified process force-stops. Mere `sys.boot_completed`, APK compilation, or a Linux DB reopen is insufficient.

## Open validation gates

**No real private-data entry is authorized.** The disposable debug envelope is not production-hardended for power-loss/failure and raw database keys cross managed memory. This is not yet the functional APK 02 beta. Original APK 01 remains a separate, sample-only visual preview.

Required follow-up: complete editor autosave and save-state UX, secure app data lifecycle, native race-free no-clobber and fsync, encrypted v2 backup and clean Android reinstall with a separately retained recovery key, bounded-memory attachment streaming, physical device/tablet tests, Telugu IME, accessibility and independent security review.

Do not claim Android integration passed until the live emulator workflow reports success. Emulator success is still distinct from physical-device validation.
