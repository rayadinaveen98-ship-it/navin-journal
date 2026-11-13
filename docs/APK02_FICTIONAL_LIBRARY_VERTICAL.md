# APK 02 — Encrypted Fictional Library Vertical Slice

**Engineering checkpoint:** 13 November 2026. This is a **fictional-data-only Android diagnostic**, not the private journaling beta.

## New code committed

- [Journal Library / Reader / Writing Studio UI](../preview_app/lib/fictional_journal_library.dart) uses our approved Still Pages / Memory Atelier design language, the original Folded Page mark, semantic colors and a responsive constrained layout.
- [Android library app entrypoint](../preview_app/lib/apk02_library_main.dart) gets an Android app-private database directory and reuses the existing AndroidKeyStore wrapping bridge. On a new install it provisions an encrypted fixture; on reopen it authenticates the existing envelope and refuses to reset a mismatched or missing vault.
- The existing [journal_editor worker](../packages/journal_editor/lib/journal_editor_isolate.dart) serializes complete encrypted journal creation, journal metadata, entry listing, reading and editing on a background Dart isolate. No plaintext journal index or preferences cache is created.
- [Journal core](../packages/journal_core/lib/journal_vault.dart) now exposes direct encrypted journal listing without using a full backup snapshot.
- [Flutter integration tests](../preview_app/apk02_test/fictional_journal_library_test.dart) test: empty library; scripted sample save; list refresh and encrypted reader; historical revision after editing; worker close/reopen with the same key; narrow phone and tablet layouts.
- [Standalone debug APK CI](../.github/workflows/apk02-library-debug.yml) builds a separate Android application package. It runs strict analyzer, visual and fictional encrypted UI widget tests, then compiles the Library / Reader / Writer debug APK and uploads the artifact if every stage passes.

## Verified build evidence

- [Successful APK 02 fictional Library debug build](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43457857948): **23/23 encrypted Dart/editor worker integration tests** passed, **13/13 stable Flutter visual/save-status widget tests** passed, strict Dart and Flutter analysis clean, and a standalone Android debug APK compiled and uploaded as artifact ID **14054687841**.
- APK SHA-256: `da678c40cd8cf621e1211b362d3678cc2856d00d5678ea1795b54bf1eb31f6cd`, verified against the downloaded artifact.
- APK 01 remains a **separate application package** and is not replaced by this diagnostic.
- **Four real encrypted-worker Flutter UI integration tests PASSED** in [focused run 43463736435](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43463736435). The earlier fake-async deadlock was resolved by properly awaiting worker operations using WidgetTester.runAsync; full UI tests then caught and led to a Material/ink feedback fix on encrypted saved-page cards. This is **Flutter test-runner evidence only**, not an Android emulator or physical-device runtime test.
- **Separate connected Writing Studio Android crash-recovery fixture PASSED** at API 34 with Android Keystore and two verified process force-stops ([run 43479108180](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43479108180): `ACK_V1 → ACK_V2 → RECOVERED_V2`). The standalone Library/Reader navigation APK itself has **not** been exercised through its UI on an Android emulator/physical handset. Clean-device key-loss recovery, private-data security and real-device accessibility remain open.

## Updated testable APK (latest)

- [APK 02 successful updated build run 43464148090](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43464148090): **23 encrypted worker, 13 stable Flutter UI and 4 true encrypted-worker navigation tests all passed**; standalone Android APK built and uploaded as artifact 14058260789.
- Updated debug APK SHA-256: `623e115685eebdcf23603a655747e5357cc93254a9c841ff12a59e8040a65081` (verified byte-for-byte against GitHub Actions artifact).
- Fixed saved-page Material/ink response; users can install the updated fictional-only debug build. A **separate** connected editor/Keystore native force-stop proof has passed (run 43479108180); hardware phone/tablet testing of the Library remains open.

- [Phone/tablet test acceptance checklist](APK02_PHYSICAL_DEVICE_ACCEPTANCE.md) specifies the exact read/save/reopen/version and UI criteria using fictional text only; same-install force-stop is NOT equivalent to a fresh-device backup/restore test.

## User-visible fictional test journey

1. Launch the **separately installed** library diagnostic. Its data store is not shared with APK 01.
2. Tap **Start a fictional page**; Writing Studio appears with read-only fields.
3. Tap **Use fictional sample**, then **Save and verify** if needed. Check the state reads “Saved locally · version 1” only after a transaction acknowledgement.
4. Use back navigation. The editor only closes when safe, and Library reloads rows from encrypted SQLite.
5. Open the saved card in Reader; observe title, body and encrypted version.
6. Tap **Edit fictional page**. The predefined fictional revision creates version 2; after safely leaving, the Reader shows the updated page and the worker retains the previous version.
7. Force-stop and relaunch. The Android Keystore-wrapped database key must unlock the previously created fictional journal rather than resetting it. **This specific physical-device test has not yet been verified**.

## Safety limits

No real user typing is accepted by this debug build. A warning is visible on all screens. This is not production-ready key custody, app lock, signed release, account sync, private journal storage, independent recovery, or backup/restore. A lost device key may make the test data unrecoverable. Physical Android testing, full lifecycle/IME, durability, durable no-overwrite restore, power-loss/disk-full, migration, accessibility and independent security checks remain open.

The separate Android emulator force-stop workflow is not an approved successful proof until its CI run explicitly passes. The Library debug build workflow only proves static, widget and Android compilation gates; it does not run on an Android emulator.

**Never enter real private diary data.**
