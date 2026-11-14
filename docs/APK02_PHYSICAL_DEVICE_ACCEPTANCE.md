# Navin Journal · APK 02 physical-device acceptance (Stage 5B entry gate)

**Updated:** 14 November 2026  
**Scope:** Disposable **FICTIONAL-DATA-ONLY Android diagnostic**, NOT a private journaling beta, recovery product or release build. No personal text, media, account information, private passwords or sensitive content may be entered. These are instructions for **manual tests still to be completed**, not claims of physical-device success.

## Exact candidate and automated evidence

- PR [#12](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/12), source head `3207e475636344042fcf649a27f2cf43f87d714a`, squash merge `597041cca9f929ae36d32c5bb8ae76bf24750aa9`.
- [Successful Android Library build 43593015820](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43593015820). Artifact **14113870149**: `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY` (GitHub Actions artifact ZIP containing debug APK, expires 28 November 2026). Android app ID: `com.navinjournal.navin_journal_library_probe`.
- [API-34 native Telugu HOME/force-stop regression 43593015839](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43593015839) **SUCCESS**.
- [API-34 clean reinstall, encrypted retained-candidate activation, force-stop and alias-loss 43593015884](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43593015884) **SUCCESS**. This was an **ADB diagnostic**, **NOT** a real Android SAF/user interaction.
- Test report: [Stage 5A safe activation](STAGE5A_SAFE_ACTIVATION_2026-11-14.md).

Download only the **Library** artifact for ordinary fictional UX testing. The separate portable-reinstall artifact is an automated ADB fixture and not the end-user Library screen.

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
