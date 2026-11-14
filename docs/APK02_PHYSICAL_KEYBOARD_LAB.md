# APK 02 — Physical Telugu Keyboard Lab (fictional, memory-only)

**Stage:** Navin Journal Stage 5 · prepared on 14 November 2026  
**Status:** Android **debug APK built** and 7/7 Flutter widget tests passed; **NO actual physical-device results yet**. This is an isolated QA tool, **not** an encrypted journal or a private-data beta.

## Purpose

The [separate Keyboard Lab](../preview_app/lib/fictional_keyboard_lab.dart) gives a human tester actual editable Android system keyboard fields to check Telugu Gboard, mixed English/Telugu/emoji, cursor selection, keyboard overlap, portrait/landscape, 200% text scaling and TalkBack. Existing encrypted Writer tests used synthetic `TextEditingValue` and already passed API-34 HOME and force-stop checks; **they did not test actual Gboard input**. This independent lab enables that on-device observation without accepting real journal data.

### Data and safety contract

- The lab has **no journal database/worker, vault, keys, backups, SharedPreferences, networking, analytics, file writes or autosave**. Text exists only in the live Flutter `TextEditingController` objects. App restart/process termination loses the test text.
- The Copy Checklist action serializes **only six human-checked results**, not the typed title, typed body or composition text. Clipboard handling is external to the app; avoid copying private data.
- The live composing indicator and background-state label are for observation; neither is an automated claim that Telugu Gboard or any real keyboard passed.
- **Use the fixed fictional sample only.** Do not type personal details; system keyboards may have their own suggestions, retention or cloud capabilities beyond this app.
- The separate Android test APK has a release-mode startup guard and is intentionally not a production/private diary.

## APK and automated verification

**Passing dedicated workflow:** [GitHub Actions run 43576477230](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43576477230).

- Flutter static analysis: **PASS**, no issues.
- **7/7 widget tests PASS**: empty-state privacy warning; temporary typing/reset; simulated composing indicator; sanitized-only checklist; sample-button distinction from actual typing; recreation loses transient text; 360px phone / 800px tablet / landscape with simulated keyboard inset and 200% scale.
- Android debug APK compiled and uploaded: **PASS**. GitHub Actions artifact ID **14106364310**, name `navin-apk02-KEYBOARD-LAB-FICTIONAL-NO-STORAGE`. The downloaded artifact ZIP contains `app-debug.apk` and is retained by the workflow for 14 days.
- Existing encrypted Library regression workflow: [run 43576477202](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43576477202) **PASS**, including strict analysis, autosave/worker/widget/navigation/recovery suites and Android diagnostic build.
- Existing API-34 synthetic Telugu Android HOME/Keystore/force-stop regression: [run 43576477216](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43576477216) **PASS**.
- Code merged via [PR #5](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/5), squash commit `a65d710e8ce5101b56e076a96398765000c6604d`.

## Hands-on Android phone/tablet acceptance (PENDING)

1. On an Android test device, open the successful workflow link, download and unzip the `navin-apk02-KEYBOARD-LAB-FICTIONAL-NO-STORAGE` artifact, then install `app-debug.apk`. Do not treat this as a release or install it as your main diary. Installation of a GitHub debug APK may require local sideload approval; follow your device's normal trusted-source settings only if comfortable.
2. Open the lab, confirm the **FICTIONAL QA ONLY** warning and initially blank input fields. Use actual Telugu Gboard to **type** the reference title `నా రోజు — A quiet afternoon` and the displayed fictional paragraph. Do **not** use the Insert sample button for the keyboard-composition check.
3. Exercise Telugu conjuncts such as `క్ష`, `శ్రీ`, and `త్ర`, switch to English and emoji, pause mid-word and observe the **composition** indicator. Some IMEs may not expose a composing range for all keystrokes; record what happens rather than assuming failure/success from that indicator alone.
4. Move the caret into the middle of the paragraph, select a word, delete and retype it; confirm candidate selection, handles and text remain in the expected location.
5. Keep Gboard visible and scroll to both title and body. Ensure labels, caret and usable area are not hidden behind the keyboard. Repeat in portrait and landscape. Press HOME and reopen the app to observe whether temporary text survives while the process remains alive. This lab does not promise retention after process death.
6. Change Android display/text size to the device's approximately **200%** equivalent and repeat on phone and tablet where available. Enable TalkBack and verify headings, warnings, fields, checklist labels, touch targets and reading order.
7. Tick only those checklist items personally verified. Tap **Copy checklist only** and paste the resulting sanitized summary into the review chat. Provide device model, Android version and keyboard version separately in the report (no personal text/screenshots with sensitive data). Tap **Clear test** and check that both fields and checkmarks reset.

**Pass criteria:** All six manually observed checks green on at least one supported phone and one tablet, no critical keyboard/caret/layout/accessibility defects; any issues documented and fixed before calling device UX complete.

## Still-open boundaries

Real physical-device test results, independent human signoff, secure production-writing input, Android key-loss/uninstall and power-loss protection, diverse OEM behavior, complete backup/key custody, accessibility audit and private-data beta are **NOT proven** by this build. Do not mark those stages complete until their separate evidence exists.
