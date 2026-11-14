# Stage 5C — two-device physical acceptance record

**State:** NOT STARTED / NO REAL HARDWARE RESULTS — 14 November 2026  
**Tested artifact:** APK 02 FICTIONAL LIBRARY ONLY. [GitHub Actions run 43624305760](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43624305760); artifact `14125212901`; APK SHA-256 `1d3f119f71110eb8105159c454ccfe5e339c3562ee40a3aa1a8ae70122269a29`. Merged through [PR #17](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/17). No real journal content, private key, password, file path, document URI, device serial or account data is permitted in this record.

**Role:** This is an evidence ledger, not a test claim. Update only from actual user-supplied device observations and non-sensitive screenshots. Cite actual reproducible bugs and re-test the same app revision after changes. Detailed procedure: [APK 02 physical acceptance](APK02_PHYSICAL_DEVICE_ACCEPTANCE.md).

## Test devices (pending)

| Field | Phone | Tablet |
| --- | --- | --- |
| Device model | NOT REPORTED | NOT REPORTED |
| Android version | NOT REPORTED | NOT REPORTED |
| App installed from exact artifact | NOT RUN | NOT RUN |
| App install fresh vs disposable-only replacement | NOT REPORTED | NOT REPORTED |
| Tested app SHA-256/version | NOT VERIFIED ON DEVICE | NOT VERIFIED ON DEVICE |
| Device keyboard and languages | NOT REPORTED | NOT REPORTED |

## Required user-visible acceptance

Write **PASS**, **FAIL**, **BLOCKED**, or **NOT RUN** per device. Record a concise observation and, if safe, a redacted screenshot. Every row starts NOT RUN.

| ID | Test | Phone | Tablet | Evidence / defect |
| --- | --- | --- | --- | --- |
| 5C-01 | Install and launch; no crash and no auto-created vault | NOT RUN | NOT RUN | — |
| 5C-02 | First-run Create vs Recover choice; no overwrite; long text scrolls | NOT RUN | NOT RUN | — |
| 5C-03 | Create scripted fictional notebook/page; explicit save v1 | NOT RUN | NOT RUN | — |
| 5C-04 | Edit scripted fictional page to v2; earlier version persists | NOT RUN | NOT RUN | — |
| 5C-05 | HOME/force-stop/relaunch preserves acknowledged v1/v2 | NOT RUN | NOT RUN | — |
| 5C-06 | Switch/rename/archive fictional notebooks, search and sorting | NOT RUN | NOT RUN | — |
| 5C-07 | Page and notebook Trash/Restore; no silent overwrite | NOT RUN | NOT RUN | — |
| 5C-08 | Safe `Review restore safety`; cancel export doesn't claim backup | NOT RUN | NOT RUN | — |
| 5C-09 | Actual DocumentsUI encrypted export/select/readback (fictional only) | NOT RUN | NOT RUN | — |
| 5C-10 | Wrong manual fictional recovery key rejected; correct key verifies separately | NOT RUN | NOT RUN | — |
| 5C-11 | Explicit fictional candidate activation only into empty destination | NOT RUN | NOT RUN | — |
| 5C-12 | Increase font size, safe areas, Back navigation, tablet rotation | NOT RUN | NOT RUN | — |
| 5C-13 | Separate **no-storage** Telugu keyboard lab with real Gboard/IME/TalkBack | NOT RUN | NOT RUN | — |

## Automated pre-device evidence (does NOT fill physical result cells)

- [Stage 5C import-buffer safety PR #17](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/17): fixture-only Library app update, two read-only native channel ciphertext regression tests; [Library CI 43624305760](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43624305760) + [Android Telugu lifecycle CI 43624305758](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43624305758) SUCCESS. This is the actual device-test candidate artifact above.
- [Stage 5C first-launch large-font PR #18](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/18): **tests-only**: simulated 360×780 phone and 800×1130 tablet at 200% Android text scale, create/import/recovery action scrollability and bounds, no render exceptions or implicit vault creation; [Library CI 43625752604](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43625752604) + [API34 lifecycle CI 43625752646](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43625752646) SUCCESS. Device installation of a new APK **not required** for this tests-only change.
- No real phone/tablet screenshots, version numbers, interaction results or manual test evidence have been supplied yet. Preserve all result cells as NOT RUN.

## Scope boundaries

- This APK is intentionally read-only/scripted: **do not enter personal diaries**. It uses a **light-only** diagnostic visual theme and has **no full consumer Settings hub**. Midnight Archive theme and finished Settings require Stage 5D; do not mark them Stage 5C PASS.
- A completed `flutter test` or API34 emulator test is **not a physical-device result**.
- Do not uninstall or clear any app holding valuable information. For fictional-only debug builds, the Stage 5B and Stage 5C Android signatures differ; follow [installation warning](APK02_PHYSICAL_DEVICE_ACCEPTANCE.md). **A stable QA signing key is only proposed, not approved.**
- **Do not send screenshots or messages containing any recovery key, keystore material, device ID, private entries, filename/path/URI or account identifiers.**
- Some tests are deliberately destructive to a disposable fictional installation. Start at 5C-01 to 5C-08; only do 5C-09 to 5C-11 after safely saving the fictional ciphertext externally and independently retaining its test key.
- Status remains BLOCKED for private beta if any silent vault creation/replacement, false saved/backup success, data loss, missing recovery warning or security/accessibility issue remains unresolved.

## Defects and decisions

| ID | Severity | Device | Steps / actual vs expected | Status | Fix/retest evidence |
| --- | --- | --- | --- | --- | --- |
| — | — | — | No physical bug observations supplied yet | NOT RUN | — |

**Manual completion:** 0 of 13 scenarios on phone; 0 of 13 on tablet.  
**Founder visual signoff:** NOT GIVEN for physical APK.  
**Stage 5C gate:** OPEN / NOT CERTIFIED.  
**Next evidence needed:** screenshot of the first screen on a real Android phone with fictional text only, plus device model/Android version. Tablet follows when phone first-launch issues are resolved.
