# Stage 5B — first-launch recovery UX and physical-device acceptance

**Status:** FIRST-RUN UX GUARD CI VERIFIED (PR #13); REAL ANDROID API34 DOCUMENTSUI FICTIONAL EXPORT/IMPORT EMULATOR GATE VERIFIED + MERGED (PR #14, `6aff5fe0`); **PHYSICAL DEVICE ACCEPTANCE NOT STARTED / PRIVATE-DATA BETA BLOCKED**. This document preserves the Android emulator test evidence and remaining physical-device contract. The real Android system provider was exercised on the emulator, **not** on a user's phone or tablet. No personal journal content or private recovery key is authorized.

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

## Stage 5B native DocumentsUI evidence — independent blocker (14 Nov 2026)

**NOT APPROVED / UNMERGED:** [Draft PR #14](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/14) carries a debug-only, scripted-fictional Android SAF picker test. It is separate from the merged Stage 5A/5B vault protections. On exact candidate head `c8fd8b8fc0f1d363769ed2410885fed4272f76e6`, three required workflows passed and the real-picker integration workflow failed:

- [Encrypted Library worker/widget tests + APK 43606850988](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43606850988): **SUCCESS**.
- [API34 Telugu HOME/force-stop 43606850996](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43606850996): **SUCCESS**.
- [API34 separate-key clean-reinstall restore 43606851003](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43606851003): **SUCCESS**.
- [API34 real Android DocumentsUI picker 43606850995](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43606850995): **FAILED**. The actual `ACTION_CREATE_DOCUMENT` and `ACTION_OPEN_DOCUMENT` cancellation paths passed. The encrypted file was exported and the native provider readback reached `SAF_ROUNDTRIP_IMPORT_READY`. However, actual picker selection did **not** return the encrypted bytes to Dart; `SAF_ROUNDTRIP_BYTES_RETURNED`, `SAF_ROUNDTRIP_AUTH_OK`, and `SAF_ROUNDTRIP_VERIFIED` were **never** reached.

**Grounded diagnosis:** The picker displayed the fictional filename in an enabled, clickable grid `CardView`; the automation then successfully changed to list mode, exposing an enabled, clickable `LinearLayout`. Neither semantic-label nor ADB row-coordinate taps completed document selection. This run did **not** report a launcher ANR. The negative result cannot be equated with corrupted ciphertext, a passed recovery import, or a verified production app defect. This is an unresolved *Android DocumentsUI interaction/automation gate*.

**Next controlled action:** Stop repeated coordinate retries. Either replace this specific picker-driving portion with semantic on-device UI Automator instrumentation, or manually run [the physical device acceptance protocol](APK02_PHYSICAL_DEVICE_ACCEPTANCE.md) on a disposable fictional-only install and capture redacted **PASS/FAIL/BLOCKED** evidence. Do not inject a forged picker `ActivityResult`, direct content URI, bypass consent, or relax the authenticated round-trip requirement merely to achieve a green workflow. Keep PR #14 draft until independently verified.

## Stage 5B AndroidX UI Automator advance — authenticated import and cleanup blocker (14 Nov 2026)

**Later evidence supersedes the earlier selection-only diagnosis above.** On draft [PR #14](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/14), the independent AndroidX UI Automator driver compiled and exercised the real Android `ACTION_CREATE_DOCUMENT` / `ACTION_OPEN_DOCUMENT` picker. At head `5e0e3375b498a446113980710eafe2c3b874a4f1`, [native SAF run 43616167710](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43616167710) reached `SAF_ROUNDTRIP_AUTH_OK`: a real picker-selected fictional archive returned to Dart, exact exported ciphertext bytes matched, AES-256-GCM v2 verification succeeded, and scripted current + earlier Telugu revision assertions passed. **This is genuine native emulator evidence for the file-selection and authenticated-import stages, not the full end-to-end pass.**

The same run failed **after** authentication, with sanitized `SAF_ERROR_CLEANUP`; the final `SAF_ROUNDTRIP_VERIFIED` marker was **not reached**. Three independent exact-head workflows passed: [encrypted Library + APK 43616167696](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43616167696), [Telugu lifecycle 43616167816](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43616167816) and [clean-reinstall recovery 43616167692](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43616167692).

Subsequent **test-only** revisions separate secure import-window reset, disposable archive buffer zeroization, worker close, and key zeroization into fixed nonsecret diagnostic stages and preserve key cleanup if worker shutdown fails. Exact-head [SAF diagnostic run 43617272040](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43617272040) encountered an unrelated emulator DocumentsUI visibility failure **before** reaching the known cleanup blocker. The same head passed [Library 43617271993](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43617271993), [Telugu lifecycle 43617271996](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43617271996) and [clean-reinstall 43617272021](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43617272021). The SAF run has been retried on unchanged code; **treat the verdict as pending unless an exact-head run succeeds**.

**Remaining blockers:** a fully successful and cleanly disposed authenticated picker round trip, reproducibility under emulator system UI instability, physical phone/tablet SAF + key-entry testing, OEM/accessibility conditions, and independent production security review. Preserve strict failure handling, native no-clobber and explicit consent. No private writing is approved.

## Historical Stage 5B diagnostic continuation — 14 November 2026, before final merge

**At that point blocked; no real-data beta or PR merge yet.** Follow-up tests for draft [PR #14](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/14) progressed beyond the original picker-selection failure but did not produce a fully passing real-provider gate.

- [Android SAF run 43616167710](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43616167710): encrypted export, real picker re-selection and authentication reached the fixture's cleanup phase; the test failed at nonsecret `SAF_ERROR_CLEANUP`.
- [Android SAF run 43617272040](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43617272040), unchanged retry: the completed selection/authentication path failed at `SAF_ERROR_IMPORT_HIDE`; another attempt intermittently could not detect Android DocumentsUI.
- [Android SAF run 43618781780](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43618781780): `Real DocumentsUI unavailable`, so the new fine-grained byte-buffer/secure-window cleanup diagnostic was not reached. Three separate regressions at the same candidate head passed: [Library APK 43618781758](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43618781758), [Telugu HOME/force-stop 43618781877](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43618781877), and [portable clean reinstall 43618781863](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43618781863).
- Draft head `8b450395` added fail-fast detection and redacted foreground/phase diagnostics to independent AndroidX UI Automator. [Android SAF run 43619567766](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43619567766) ultimately **FAILED** because the emulator foreground window was not recognized as DocumentsUI while the probe stayed alive at `SAF_ROUNDTRIP_EXPORT_READY`.

This historical failure sequence did **not** establish a complete export→import→authenticated content→cleanup success. The later exact-head run below did. Retain the no-overwrite/recovery-key safeguards and separate device acceptance matrix below. No synthetic ActivityResult/URI injection, no silent cleanup failure, and no private diary permission.

## Final API34 semantic DocumentsUI acceptance — VERIFIED and merged

[PR #14](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/14) merged on 14 November 2026 as `6aff5fe0b9c281b6ea26b12c333e9663e93f420b` after all required checks at candidate head `9acc9438e574423f43cd2f118518658b888a342e`:

| Exact-head workflow | Run | Final verdict |
| --- | --- | --- |
| Strict analysis, encrypted Library worker/widget regressions, Android debug APK | [43620412516](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43620412516) | SUCCESS |
| Android API34 Telugu HOME/force-stop | [43620412493](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43620412493) | SUCCESS |
| Android API34 separate-key portable clean reinstall | [43620412555](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43620412555) | SUCCESS |
| Independent AndroidX UI Automator REAL DocumentsUI encrypted fictional archive | [43620412491](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43620412491) | SUCCESS — `OK (1 test)` |

The AndroidX instrumentation drove actual `ACTION_CREATE_DOCUMENT`/`ACTION_OPEN_DOCUMENT` and cancellation screens, wrote/read back a fictional encrypted file via the Android provider, re-selected it, checked returned encrypted bytes and AES-256-GCM authenticated current plus historical Telugu/emoji versions, and completed cleanup. The diagnostic uses an owned writable ciphertext copy, does not publish recovery keys, refuses forged results, and cannot run as a release-app fixture.

**Scope boundary:** One successful API34 Google emulator provider is not physical OEM/phone/tablet acceptance, on-device manual recovery-key transcription, TalkBack/large-font usability, power- or storage-loss durability, independent security audit, or approval for private writing. Earlier intermittent DocumentsUI visibility failures remain historical evidence and motivate cross-device verification. Keep UX-01 through UX-12 below PENDING PHYSICAL.

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
