# Navin Journal · APK 02 physical-device acceptance (Stage 5C entry gate)

**Updated:** 14 November 2026  
**Scope:** Disposable **FICTIONAL-DATA-ONLY Android diagnostic**, NOT a private journaling beta, recovery product or release build. No personal text, media, account information, private passwords or sensitive content may be entered. These are instructions for **manual tests still to be completed**, not claims of physical-device success.

## Exact candidate and automated evidence

**Stage 5C replacement build — use this latest validated Library APK rather than the earlier Stage 5B archive or SAF-only driver.**

- [Stage 5C PR #17](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/17), merged as `3466fafbd11f9c13f96fbf00bda771e918f089c6`, corrects read-only native MethodChannel ciphertext handling in the **user-facing fictional Library import UI**, without changing key/restore semantics. Two new widget regressions verify read-only Android-like ciphertext input and cancellation.
- [Successful encrypted Library Android build 43624305760](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43624305760), artifact ID **14125212901** named `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`. GitHub Actions ZIP expiration **28 November 2026**. Extract its one `app-debug.apk` and install this exact version.
- APK SHA-256: `1d3f119f71110eb8105159c454ccfe5e339c3562ee40a3aa1a8ae70122269a29` (independently checked against CI build log). App ID `com.navinjournal.navin_journal_library_probe`. The GitHub build performed strict Flutter analysis, encrypted worker tests, Library/recovery widget tests and Android debug compilation.
- [Android API34 Telugu HOME/force-stop regression 43624305758](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43624305758) **SUCCESS** at the same exact PR head.
- Previously established [Stage 5B real AndroidX DocumentsUI SAF 43620412491](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43620412491), [portable clean reinstall 43620412555](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43620412555) **SUCCESS** on prior head `9acc9438` ([PR #14](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/14)); **these two separate suites were not rerun on PR #17** and are not claims of physical acceptance.

**Verified debug-signature incompatibility (14 Nov 2026):** the Stage 5B and Stage 5C downloaded APKs have **different APK Signature Scheme v2 signing-certificate SHA-256** fingerprints: Stage 5B `b40390752b51534cb8ee3633cd8c8f7d70ed5307196ed31e708bec170364c5c7`; Stage 5C `c866e2eebab8e68e69872a6441ed240649bdfa8291b2207d614ca7ccbee4aeda`. They share the fictional Library package ID, so **Android cannot in-place update Stage 5B to Stage 5C**. Do NOT press uninstall/clear data for any installation containing private or valuable content. For these disposable fictional fixtures *only*, preserve needed test notes (no keys) and deliberately uninstall the older fictional-only package before installing Stage 5C. This destroys the older fixture's local vault; no data migration is implied. **Future stable QA signing is proposed, not implemented**; it must use one user-approved test key secured outside the public repository, never a committed keystore/password.

**Pre-device feature boundary (source-reviewed):** the executable APK02 Library and first-launch entrypoint currently construct `JournalColors(false)` and therefore display the *light* diagnostic theme only. The approved Midnight Archive dark theme and complete Settings experience are part of Stage 5D, **not available for Stage 5C physical sign-off**. Stage 5C must evaluate the actual light-theme diagnostic; do not claim dark-mode or Settings verification from simulated or physical tests of this APK.

**Physical-device outcomes remain NOT RUN.** No real diary, personal recovery key, production backend, phone/tablet sign-off or public release is approved. Use only fictional samples; never upload/share manual recovery keys.

## Quick phone + tablet acceptance (fictional only)

Test the **same exact Library APK** on the phone and tablet. The app is local/offline: do not expect journals to sync between devices, and do not set up accounts or a backend.

1. **Install:** open the APK on a device and approve the Android install prompt for that trusted source only. If Android reports an incompatible existing debug signature, **do not clear or uninstall an app containing any real content**; stop and report the message. Only replace an entirely disposable fictional-only test installation.
2. **First launch:** confirm the create-or-recover choice appears *before* a journal is created; take a redacted screenshot of this initial screen if it has no private content.
3. **Create and reopen:** create the scripted fictional journal, save the supplied sample as v1, edit via the scripted sample to v2, inspect revision history, return HOME, then force-stop only this test app in Android Settings and reopen. Both versions must survive.
4. **Navigation:** exercise the fictional Library, preset search, Trash/Restore and **Review restore safety**. Report missing buttons, clipped text, spinners, unexpected permissions or crashes. This debug entrypoint does **not** implement the full consumer Settings hub; do not report absent Settings as a Stage 5C diagnostic failure.
5. **Layout and accessibility:** repeat basic navigation at a larger system font size, rotate the tablet where supported, and test Android Back. Readability and button accessibility are mandatory.
6. **Encrypted export/import without uninstalling:** test a cancelled export, then a successful fictional encrypted document export. The system file picker must appear, cancellation must not claim success, and a separate recovery key must be shown only for a successful exported file. **Do not screenshot, paste, or send the key.** Attempt encrypted document import using that file and key on an empty disposable installation only, following optional Track B below.

Stop immediately if the app allows ordinary private writing or silently overwrites a vault. **Do not uninstall or clear app data for Track B until the fictional encrypted archive and separately retained key are confirmed.**

For each device, record only its model and Android version; test case ID, PASS / FAIL / BLOCKED / NOT RUN; short observed behavior; and optional redacted screenshots with fictional text. **A single device pass is not sufficient for phone+tablet approval.**

**Live results ledger:** [Stage 5C two-device acceptance record](STAGE5C_TWO_DEVICE_RESULTS.md). All phone/tablet cases remain **NOT RUN** until actual observations are supplied. The user does not need to edit GitHub; this ledger should be updated from verified, sanitized device reports and screenshots.

## Prerequisites and reporting

Use a disposable test installation on a phone, and a tablet if available. Enable installation only for the trusted GitHub-generated APK as required by Android, then disable the temporary installation permission afterward. Preserve the artifact/version for repeatability.

Log device make/model, OS version, screen dimensions, keyboard version/languages, whether the installation was fresh, exact step, expected vs observed result, and pass/fail. Screenshots must show fictional content only. **Never screenshot or share a recovery key, account setting, private file, Keystore alias, vault database, system identification or personal data.** If any test unexpectedly prompts for personal writing, stop.

## Track A — initial install, encrypted journal and lifecycle

1. Install the fictional Library APK cleanly. Expected: the **Your fictional journal** screen appears with a deliberate **Create a fresh fictional journal** choice and a separate **Fictional encrypted archive import** area. No active journal should be silently created before a choice.
2. Tap **Create a fresh fictional journal**. Expected: the encrypted fictional Library opens without asking for identity, sign-in or network; fictional-only warning remains visible.
3. Tap **Start a fictional page** → **Use fictional sample**. Expected: an acknowledged local save (version 1), then safe return to the Library with one fictional card.
4. Open the card, confirm title/body/version, tap **Edit fictional page**, apply the predefined second fictional sample and verify version 2 and an accessible earlier version. The text fields must be read-only for real writing.
5. Force-stop the diagnostic using Android system settings; relaunch. Expected: the same encrypted fictional page and revision remain. Repeat after the second version. Do **not** clear app storage to simulate a force-stop.
6. Inspect preset fictional-only search, notebook switching/rename/archive and reversible page/notebook Trash as available. Cancelled and conflicting changes must preserve the original pages; restoring a page must keep its journal association and earlier revision history.
7. Repeat main views on portrait/landscape where supported, phone and tablet widths, large system font and airplane mode. No overlapping controls, clipped footer/button or false save/backup confirmation is acceptable.

## Track B — OPTIONAL independently held fictional encrypted archive (destructive to **test install only**)

This track intentionally removes the **fictional diagnostic app** between exports and recovery. Use it only if the source contains **nothing except predefined fictional samples** and you have confirmed the exported .njr file and a separately hand-recorded recovery key exist **outside the app's private storage**. The key is sensitive even in a test: never paste it into reports, chats, screenshots, logs or clipboard. Do not test this with real diary data.

1. In the active fictional Library, open **Review restore safety**, then the encrypted export action. Use Android's Create Document picker to save the fictional `.njr` ciphertext to a user-selected location. Record the separate 43-character recovery key off-device **without screenshots** and verify the file actually exists outside app-private storage.
2. Cancel one export attempt separately; confirm cancellation does not claim that a backup exists or reveal a new recovery key.
3. Only after external ciphertext and key custody are confirmed, uninstall the **disposable fictional app**. Reinstall the same APK. Expected: no auto-created active Library; the first-run create-or-recover choice must appear.
4. Tap **Choose fictional encrypted file**, select the independently held `.njr` through Android's Open Document picker, and manually enter the separate recovery key. First try a deliberately wrong fictional key; it must refuse without creating/erasing an active vault.
5. Re-select/enter the correct test key and select **Verify in separate encrypted vault**. Expected: an isolated verified fictional record-count report, explicitly **not installed** as the active Library. Use **Keep separate protected candidate (test)** to prepare an independently device-wrapped candidate.
6. Use **Recheck stored protected candidate (test)** when available, then **Check recovery state** in **Protected journal recovery**. The approval action must **not** be enabled before checking the acknowledgement checkbox and typing the exact phrase `ACTIVATE FICTIONAL JOURNAL`. Approval must be separate from choosing the file or entering a key.
7. Confirm activation **only into an empty Library**. Expected: authenticated fictional pages become readable under the moved Android-Keystore-wrapped vault. Force-stop and reopen; verify same Telugu/emoji sample, current version and prior revision. Do not copy/re-enter the original archive or key for this reopen.
8. Attempting this activation against an existing occupied Library, a missing/incomplete candidate or an interrupted reservation must **fail closed**, show a non-destructive warning and never offer reset/merge/replacement. Use a separate disposable installation for destructive negative tests; do not deliberately corrupt normal app data.
9. Record the exact displayed outcome. If uncertain, stop: **do not** repeatedly uninstall, overwrite, discard, clear data or attempt unreviewed cleanup of an ambiguous vault.

## Track C — physical keyboard and accessibility

Use the separate **no-storage Telugu Keyboard Lab** from [its runbook](APK02_PHYSICAL_KEYBOARD_LAB.md) for *actual editable* Gboard Telugu/English composing text. The encrypted APK02 Library is intentionally fictional/read-only and does **not** prove real typed diary-writing quality. On actual devices inspect TalkBack focus order, button labels, modal traps, system text scale at 200%, display cutouts, back navigation, focus/keyboard insets and tablet rotation. Record each result by device; do not infer physical accessibility from Chromium/emulator automation.

## Stop conditions / release blockers

Any missing revision after an acknowledged save, false save/backup success, ability to type personal diary content, silent active-vault reset, replaced existing database, unexpected insecure file/key exposure, inability to safely exit the editor, corrupted/locked restoration with no warning, or inaccessible primary action is a **blocking failure**. Report reproduction against fictional content only.

Even if all tracks pass on one device, this does **not** approve private-data input or release. Remaining independent gates include OEM diversity, abrupt power-loss/low-storage filesystem behavior, large-media streaming, migration and key lifecycle, robust user recovery-key UX, security/privacy review and explicit product acceptance.
