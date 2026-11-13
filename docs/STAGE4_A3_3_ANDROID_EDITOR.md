# Navin Journal — Stage 4 A3.3 Android editor integration

**Date:** 2026-11-13  
**Purpose:** Validate a *fictional-data only* Flutter text editor connected to native Keystore-wrapped encrypted SQLite commits from a background Dart isolate.  
**Product security:** **NOT RELEASE-READY**. No private diaries, no final premium UI, no account or recovery key.  
**A3.3 Android outcome:** CI test results must be verified separately; do not infer Android runtime success from Linux tests.

## What's implemented

- [Background SQLite owner](../spikes/autosave_coordinator/lib/encrypted_isolate_store.dart): a dedicated Dart isolate owns the encrypted `EncryptedDraftStore` connection. Requests are serialized and sent using typed, sanitized `read`, `commit`, `integrity`, and `close` messages. Raw 32-byte key material is transferred into the worker and best-effort cleared after opening; this **does not prove secure memory clearing**.
- [State machine](../spikes/autosave_coordinator/lib/draft_autosave.dart): distinguishes untouched, dirty, saving, saved, failed and conflict states, with debounced typing and explicit flush on lifecycle transitions. The UI only advertises saved after a precise commit acknowledgement.
- [Debug Flutter editor](../spikes/flutter_bridge_probe/lib/autosave_probe.dart): two fictional-data text fields, save-status semantics, explicit test flush, and a verification action that closes/reopens the encrypted database using the existing Android Keystore wrapping key.
- [Android integration checks](../spikes/flutter_bridge_probe/integration_test/autosave_probe_integration_test.dart): actual Flutter test-widget text entry into the Android emulator, confirmed commit and version, encrypted isolate reopening, a second edit after reopening, and dispatch of an inactive lifecycle event to request flush.

## Passing reference evidence

[Linux Dart CI run 43421552880](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43421552880): **41/41 tests passed** — A3.1/A3.2's 33 checks plus **8 new encrypted isolate checks**. The isolate tests cover fresh/open/reopen, Unicode preservation, correct acknowledgements, concurrent conflict rejection, wrong-key refusal with no plaintext fallback, untouched empty drafts, revision retention, and write rejection after shutdown.

The Android integration tests use [the existing A2.4 Flutter workflow](../.github/workflows/flutter-keystore-bridge.yml), expanded to resolve the A3 package and run the additional Android editor test file. The workflow generates a disposable debug harness, never a production app.

## Acceptance checklist

| Proof | Status |
|---|---|
| Dart isolate owns encrypted DB writes | Linux verified |
| 41 state-machine/storage/isolate test scenarios | Linux verified |
| Flutter analysis + Android debug compile | Await matching CI success |
| Android emulator fictional typing → acknowledged save → database reopen | Await matching CI success |
| Android emulator inactive lifecycle callback → flush | Await matching CI success |
| Physical Android Telugu IME and lifecycle | Not tested |
| Force-stop during debounce and commit → recovery | Not tested |
| Disk-full, corrupted WAL, concurrent process writes | Not tested |
| Production secure key backup / restore | Not built |
| Native Flutter app integrating approved visual design | Not built |

## Android test-runner reliability update

The [CI run 43422522118](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43422522118) passed Flutter static analysis, 14 mocked MethodChannel tests and Android debug APK compilation, but **both runtime test files could not install the APK**: the emulator returned `Can't find service: package`. Thus the A3.3 Android widget/lifecycle assertions did **not** execute in that run.

We committed a [device-readiness script](../spikes/flutter_bridge_probe/ci/run_android_integration.sh) that probes `sys.boot_completed` **and** Android's package manager before installation; it runs the two Flutter integration suites sequentially. The [updated workflow](../.github/workflows/flutter-keystore-bridge.yml) uses a cold boot and cancels superseded concurrent runs. Passing the Linux/A3.4 process-kill tests does **not** bypass the A3.3 Android integration gate.

## Key limitations

- The editor surface is deliberately sparse and diagnostic. **Do not judge it as our approved Stage 3 premium design**, and do not ship it.
- The test harness creates disposable files under the system temporary directory. They are cleaned up when the widget is disposed. That is acceptable for imaginary fixtures **only**; actual production storage must not delete or reset a vault after an error or lifecycle event.
- An inactive/pause callback can **request** a flush; Android can still kill a process before a pending write completes. Unsaved keystrokes cannot be considered durable. Only an acknowledged committed snapshot qualifies as saved.
- Manual process death and full storage tests are **A3.4**, separate from widget-driven simulated lifecycle.
- Even if the emulator test passes, the A2 production key/recovery gate is open and the product journal/entry/attachment schema remains ununified.
- The synchronous database code is isolated to a single Dart worker; performance on low-memory Android hardware has not been benchmarked.
- Future production editor must handle accessibility, writing in Telugu with physical IME, conflict resolution UI, system font scaling, and secure attachment handling.

## Next gate after A3.3

1. Verify the Android debug compile and integrated test results; fix any failures.
2. A3.4: preserve an approved save version after real app process kill, launch a new process with the existing Keystore alias, reopen encrypted SQLite and compare exact title/body/revision.
3. A2/A4: design portable encrypted recovery independently of the device-only Keystore key.
4. Only then integrate tested storage into the approved product design, with a full reliability review.

Related: [A3 reference report](../spikes/autosave_coordinator/README.md), [Stage 4 tracker](STAGE4_ENGINEERING_SPIKE.md), [product reliability requirements](DATA_PRIVACY_RELIABILITY.md).
