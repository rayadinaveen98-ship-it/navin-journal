# Navin Journal — Stage 5A protected retained recovery candidate

**Checkpoint:** 14 November 2026  
**Scope:** APK02 fictional fixture only, Android debug build and Linux deterministic fake-device test coverage. **NOT an approved personal diary restore.**

## Why this slice exists

Prior Stage 5 import/export could authenticate a separately selected `.njr` file and a separately entered recovery key, but discarded the reconstructed encrypted vault after inspecting it. Stage 5A now supports a **deliberately opt-in, separately retained and device-key-enveloped encrypted recovery candidate**, with independent re-opening after the original archive/recovery key are no longer present in the app process. The current active Library is **never modified**.

## User-facing fictional diagnostic

**Library → Review restore safety → Fictional encrypted archive import**

- Choose an encrypted fictional file and manually re-enter its separate 43-character recovery key.
- **Verify in separate encrypted vault** retains the existing behavior: inspect a disposable vault, then destroy it.
- **Keep separate protected candidate (test)** uses the new Stage 5A behavior: authenticate the imported full-schema AES-256-GCM archive, reserve a unique fixed app-private candidate, generate and wrap a fresh database key with the device key provider, restore into a separately named encrypted vault and independently reopen it using the persisted envelope. Result shows only aggregate notebook/page/revision/media counts.
- **Recheck stored protected candidate (test)** attempts a new encrypted reopen from only the candidate files and *the existing device's wrapping alias*, not the archive, recovery key or previous in-memory database key.
- The screen states **QUARANTINED CANDIDATE ONLY**. Nothing is activated as the current Library, merged with existing entries or authorized for private writing.

## Collision, interruption and failure policy

The service `FictionalRetainedRecoveryCandidate` fixes the candidate name to `nj-fictional-retained-candidate-v1` under the trusted app-private root. It never invents arbitrary unsupervised candidate names or performs automated cleanup. Before creating any files or provisioning a Keystore alias, the full encrypted archive and manually entered key are authenticated; wrong keys and tampering leave the target absent.

A permanent, empty sibling `.reservation` file is created with **exclusive-create semantics** before candidate directory creation. This resolves the check-then-create concurrency race: exactly one concurrent importer can reserve the target. An existing candidate directory, file, link or reservation **blocks further import**, even if the first attempt was interrupted. Do not silently remove this reservation; an explicit inspected recovery disposition is needed in a later stage.

The candidate contains `envelope.json` (authenticated wrapped key, no plaintext key) and an isolated `vault/journal.sqlite3` (encrypted SQLite plus native readiness marker). The existing native no-replace/fsync restorer publishes only into an absent child directory. The independent reopen verifies SQLite integrity, ownership of entries and their prior revisions. A later reopen also checks media counts through a freshly authenticated in-memory encrypted export. Both paths return only counts.

If interrupted after reserving or wrapping but before database publication, the candidate can be **incomplete** and is intentionally left quarantined; it must not be reported as restored, deleted or auto-retried. A missing/retired device alias or corrupted envelope blocks reopen without resetting the original vault.

## Verified automated gates

**Full fictional Library build:** [GitHub Actions run 43587076593](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43587076593) — **SUCCESS**.

- Strict Flutter/Dart analysis: PASS.
- Autosave: **46/46** PASS.
- Encrypted editor/worker and retained recovery: **52/52** PASS.
- Visual/editor widgets: **16/16** PASS.
- Library/index and recovery route integration: **31/31** PASS.
- Read-only recovery review: **5/5** PASS.
- Android debug APK compile/upload: PASS. GitHub artifact **14110499584**, name `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`.

**Separate API34 lifecycle regression:** [GitHub Actions run 43587076581](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43587076581) — **SUCCESS**. Android debug build, previous Keystore encrypted write, synthetic Telugu IME background save, actual HOME, two force-stops and reopen checks passed. **This existing emulator run did not exercise the new retained-candidate button or a fresh-device user-selected restore.**

**Merged:** [PR #10](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/10), squash commit `0669b2f7a872483b5bf2f7a218afd2b9697ebd54`.

The retained-candidate worker tests run on Linux with an **explicitly insecure fake DeviceKeyProtector** that simulates key custody/alias failures; it is NOT encryption and must not be substituted for an Android Keystore runtime or hardware security test. The actual Android integration constructs `FlutterAndroidKeyProtector`, without a software fallback, but its new candidate lifecycle has only been compiled, not directly exercised on Android.

## Remaining release gates

1. **Dedicated Android runtime retention test**: use the real Android Keystore provider to retain, kill/relaunch, reopen the protected candidate; then simulate missing/invalidated alias, power interruption after exclusive reservation/envelope/publish, and independent clean-install import using file/key from outside the original app.
2. **Explicit, non-destructive user-approved activation** of a complete protected candidate in a fresh app only. Must refuse occupied active vaults, use durable transaction/commit markers, avoid auto-deletion, and provide recovery from crashes in every step. No automatic merge/overwrite/reset.
3. **Physical-device acceptance**: actual SAF providers, Telugu Gboard, accessibility, Android Keystore-backed wrapping, tablet portrait/landscape, disk-full, reboot, force-stop and storage/OEM variation.
4. **Independent security/privacy review** of archive import, key ownership, in-memory key lifetime, restore staging, external documents, dependencies and signed build. Dart String/MethodChannel/key copies cannot be guaranteed zeroized.
5. Only after the above gates and a real **user-held independently recoverable archive + key** drill, enable private user-entered journal text and enter the functional beta release gate.

**Do not call this a completed private-data backup, an activated restored journal or Stage 5 graduation.**
