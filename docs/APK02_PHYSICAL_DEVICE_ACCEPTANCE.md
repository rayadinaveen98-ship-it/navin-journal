# Navin Journal · APK 02 physical-device acceptance

**Diagnostic scope only.** The executable accepts hard-coded *fictional* English/Telugu/emoji pages. No real personal writing. This is not a beta or independently recoverable diary.

**Reference build:** [APK 02 fictional Library, CI run 43464148090](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43464148090) — 23 encrypted-worker Dart tests + 13 stable Flutter widget tests + 4 real-worker Library/Reader/Writer widget tests passed. APK SHA-256 `623e115685eebdcf23603a655747e5357cc93254a9c841ff12a59e8040a65081`. Android app ID: `com.navinjournal.navin_journal_library_probe`.

The production encrypted whole-journal app is **not** release-approved. The APK 02 test app keeps its fictional vault in private app storage. Removing app data or uninstalling it destroys the app-private vault/key envelope; do **not** use this build to test independent recovery.

## Evidence to capture

For every manual test, record: APK build SHA, device make/model, Android version, screen size (phone or tablet), step completed, pass/fail, and the visible outcome. Screenshots should contain *only fictional content*. Avoid screen recordings of OS settings/accounts or any personal data.

## Device acceptance sequence

1. **Fresh fictional test launch** — install the diagnostic APK. App should open `Fictional Pages` and never ask for personal identity or account access. Confirm test-only warning is visible. Expected: empty `Saved pages` section (unless this same diagnostic was used before).
2. **Scripted encrypted save** — tap `Start a fictional page`, then `Use fictional sample`. Expected: it eventually shows `Saved locally · version 1`. The text fields are read-only; typing personal text is prohibited and should be impossible.
3. **Safe editor exit** — tap the Writing Studio back arrow. Expected: editor returns to `Your Pages` and the newly saved fictional card is present. No duplicate entry.
4. **Real encrypted reader** — open the saved card. Expected: original fictional title and body appear with `Encrypted version 1`; back returns to the Library. Tapping the card should display visible Material/ink feedback.
5. **Same-install process restart** — press Home or use Android Settings → Apps → this *diagnostic* app → Force stop, then launch it again. Expected: same fictional page is present, with title, body and version 1. **This is not a device reinstall/restore test.** Do not use `Clear storage` or uninstall.
6. **Revision & journal history** — open the card → `Edit fictional page` → `Use fictional sample`. Expected: `Saved locally · version 2`; return to the Library, open the card, verify updated fictional title/body and `Encrypted version 2`. The previous revision is verified in automated tests; history is not a consumer-visible feature in this APK.
7. **Second force-stop** — repeat step 5 after version 2. Expected: same fictional entry remains at version 2, no duplicate pages, no blank or reset.
8. **Responsive UI** — repeat basic navigation in portrait/landscape where supported on a phone and on a tablet. Expected: title, read-only body, status, back and save controls remain visible and tappable; no text clipping, horizontal overflow, layered controls or broken ink splash.
9. **Poor-connectivity check** — switch to airplane mode after opening. Expected: local fictional Library/Reader still work. No account/network dependency should prevent reading an already unlocked test vault.
10. **Safety/negative check** — app must never claim that a backup has been made, that a cloud sync occurred, that the app is secure for real diaries, or that lost local data can be recovered. An invalid/corrupted envelope should be rejected rather than silently replaced; that destructive negative test is for isolated CI fixtures, **not** a user's installed test data.

## Reporting a failure

A failed case needs an exact reproduction: step number, observed screen/message, whether the saved page existed before the step, and whether the app was backgrounded or force-stopped. Do **not** send any device keys, internal journal DB, account details or private writing. If the app displays a failed save, avoid repeated uninstall/reinstall and capture the fictional-only screen.

## Security gates NOT covered by physical preview

- Android Keystore/device key custody and process-lifecycle proof for the *connected vertical fixture*, including successful ADB `ACK_V1 → ACK_V2 → RECOVERED_V2` after actual force stops
- Independent encrypted backup and recovery on another clean Android installation (not just same-install force-stop)
- Atomic no-clobber restore, fsync/corruption/power-loss/disk-full checks, migrations and key-loss education
- Native media file protection, exports, accessibility, Telugu keyboard composition, physical-device performance and independent security review
- Signed consumer beta, app lock, authentic privacy guarantees and permission audits

No real/private diary entry should be accepted before critical gates are independently verified.
