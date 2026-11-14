# Stage 5B — first-launch recovery UX and physical-device acceptance

**Status:** FIRST-RUN UX GUARD IMPLEMENTED + CI VERIFIED (PR #13, merge `9230d4137082bca52019764d552c4d00b0a0bdbc`); PHYSICAL DEVICE ACCEPTANCE NOT STARTED / FICTIONAL DIAGNOSTIC ONLY. This document is a testing contract, **not** evidence that a phone/tablet or actual SAF provider has been tested. No personal journal content or actual private recovery key is authorized.

## Purpose

After a fictional encrypted archive is imported into a *separate* native Keystore-protected retained candidate, first launch must automatically reflect the new recovery state. A new empty Library must not silently occupy the only no-clobber activation destination while a candidate is pending, or while the activation/reservation state is uncertain. Archive import, retention, explicit activation, and new journal creation remain distinct actions.

## Engineering changes proposed in PR #13

- Fictional external import section sends a **presentation-only** `onCandidateRetained` notification **only after verified retention succeeds**. Import cancellation, temporary verification and retention failure do not invoke it. The signal cannot activate/approve/replace a vault. UI-refresh failures do not relabel successful retention as a failed import.
- First-run Android Library re-inspects retained recovery state and refreshes the separate approval panel after that signal. The **Create a fresh fictional journal** action is disabled for pending recovery and uncertain/occupied state; the creation handler also rechecks the recovery state before creating any directory, protecting against a stale screen.
- Approval still requires the independent checkbox + typed phrase, and the native no-overwrite directory rename, permanent reservation, independently authenticated reopen and Keystore alias rules remain untouched.
- Regression tests cover success-only status refresh, failure does not signal refresh, pending candidate blocks fresh creation, incomplete state blocks creation, plus existing no-consent/no-overwrite/force-stop checks.

## Verification of the code change

- [PR #13](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/13) merged after exact-head CI checks completed successfully: [Library worker/import/first-launch widgets + Android debug APK build 43594995920](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43594995920), [API-34 Telugu HOME/force-stop 43594995940](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43594995940).
- Updated test expectations reflect existing fail-closed behavior: uncertain state shows a no-reset error and **does not enter setup**, rather than showing a disabled setup button.
- Latest produced fictional Library test artifact: GitHub Actions artifact ID **14114028203**, `navin-apk02-FICTIONAL-LIBRARY-NOT-PRIVATE-DIARY`, from run 43594995920. It is a debug build, **not** a safe diary or Play Store release.

## Device acceptance matrix (manual; NOT YET EXECUTED)

| ID | Test scenario | Acceptance criterion | Result |
| --- | --- | --- | --- |
| UX-01 | Install fresh fictional Library APK | Create-or-recover choice; no auto-created active vault | PENDING PHYSICAL |
| UX-02 | Create fictional Library with no recovery candidate | Explicit tap opens scripted encrypted Library; no silent reset | PENDING PHYSICAL |
| UX-03 | Cancel Android document picker | No recovery, no stored key, no false success; empty new-Library option remains available | PENDING PHYSICAL |
| UX-04 | Wrong key/corrupted ciphertext | Neutral failure; no retained candidate approval or auto-activation; files preserved | PENDING PHYSICAL |
| UX-05 | Select valid fictional .njr; retain candidate | The candidate is independently authenticated and kept separate; approval panel updates without manual refresh; fresh-Library action becomes disabled | PENDING PHYSICAL |
| UX-06 | Candidate pending; restart application | Candidate still recognized; no new Library creation, no automatic activation | PENDING PHYSICAL |
| UX-07 | Consent action | Activation disabled until separately checked acknowledgment **and** exact typed phrase; picker/import itself is not consent | PENDING PHYSICAL |
| UX-08 | Activation into confirmed empty destination only | Full encrypted candidate + envelope moves without overwrite, then reopens and verifies history/record counts | PENDING PHYSICAL |
| UX-09 | Android force-stop after activation | Active fictional Library still independently reopens with scripted Telugu+emoji and historical revision | PENDING PHYSICAL |
| UX-10 | Existing or interrupted candidate/active destination | No merge, auto-rekey, reset, cleanup or creation that would occupy the candidate destination | PENDING PHYSICAL |
| UX-11 | Phone & tablet screen sizes, TalkBack, 200% font | Key controls and warning remain accessible, no overlaps/clipped text; keyboard and back navigation usable | PENDING PHYSICAL |
| UX-12 | Actual Android SAF document provider | Create Document and Open Document picker work with a user-controlled fictional file without misleading success or leaked key | PENDING PHYSICAL |

**Safety:** Do not deliberately corrupt or clear an installed journal containing anything personal. The disposable APK02 may only store scripted fictional content; never send or screenshot a full recovery key or encrypted journal database. Real-world key loss, force reboot, disk exhaustion, alternative providers/OEMs, media scale, security audit and signed release remain separate gates.

## Evidence collection template

For each manual case, record only: test ID, artifact run ID + APK SHA256, device make/model, Android version, keyboard/accessibility configuration, fresh vs reused diagnostic install, action/expected result, **PASS / FAIL / BLOCKED / NOT RUN**, observed fictional-only UI symptom, and a redacted screenshot if safe. Never put keys, personal writing, device IDs or secure screens in issue comments.

## Release interpretation

Passing Flutter widget tests or API-34 emulator flows is **engineering validation**, not physical UX signoff. No user-private diary feature may be unlocked based on Stage 5B first-run checks alone. Signoff requires the separately documented [physical acceptance protocol](APK02_PHYSICAL_DEVICE_ACCEPTANCE.md) and security/recovery audit, with an explicit founder release decision.
