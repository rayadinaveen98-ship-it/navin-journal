# Navin Journal — APK 02 connected Writing Studio

**2026-11-13 · engineering-only scripted fixtures**

## Components connected

1. [Connected Writing Studio](../preview_app/lib/connected_writing_studio.dart): approved editorial layout, responsive phone/tablet design, explicit save status, exit guard, lifecycle flush and a read-only scripted-data mode.
2. Existing A3 DraftAutosaveController: text/IME updates, dirty/saving/saved/error/conflict state, no “Saved locally” claim before a committed database transaction is acknowledged.
3. [Journal Editor Worker](../packages/journal_editor/lib/journal_editor_isolate.dart): a dedicated Dart background isolate owns encrypted SQLite3MultipleCiphers; Flutter UI never executes synchronous SQL queries.
4. [Journal Editor Draft Port](../packages/journal_editor/lib/journal_core_draft_port.dart): first save creates one full-schema entry; further saves retain historical revisions and reject stale optimistic edits.
5. [Android connected entrypoint](../preview_app/lib/apk02_connected_main.dart): existing AndroidKeyStore MethodChannel manages wrapped database keys; each launch uses the same app-private encrypted journal file. Independent reopens verify exact version/history before acknowledgment.
6. [Android ADB script](../preview_app/ci/apk02_android_roundtrip.sh): actual force-stop between three fresh process launches: fictional v1, edit/ack v2, reopen v2 with prior revision.
7. [Flutter widget tests](../preview_app/apk02_test/connected_writing_studio_test.dart): fictional-only mode, saving success and failure, conflict, close protection, field wiring, small phone and tablet layouts.

## Evidence and verification

- [22/22 shared encrypted editor/isolate tests passed on Linux](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43450962740).
- Flutter analyzer and widget-test steps passed in [connected APK 02 CI run 43453899899](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43453899899).
- **Android native build and actual emulator force-stop/relaunch remain unverified until workflow completion.** Neither Linux nor widget tests count as physical-device or production security signoff.
- The APK 01 sample-only preview remains a separate build and is not wired to private-data storage.

## Strict diagnostic limitations

The Android test entrypoint has scriptOnly=true, read-only TextFields, hardcoded fictional English/Telugu test strings, and no consumer/private-data writing. It does not provide real backup and restore, a signed functional beta, media capture, app lock, or production-grade key custody. Failed saves, conflicts and missing vault keys are never treated as a successful save or a signal to reset an existing vault.

## Open before a real private journaling APK

Android emulator save/reopen proof; persistent consumer navigation; real journal CRUD; editor lifecycle/crash and accessibility; Telugu IME; hardware phone/tablet verification; robust backup/restore across clean install using an independently held recovery key; native atomic no-overwrite and fsync; disk-full/power-loss and migrations; security review; release signing.

**Do not use this diagnostic for real personal diaries.**
