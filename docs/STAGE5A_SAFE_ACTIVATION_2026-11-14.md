# Stage 5A — explicit no-replace fictional recovery activation

**Date:** 14 November 2026  
**Status:** IMPLEMENTED + CI-VERIFIED in an **API-34 emulator with scripted fictional data only**. **NOT** physical-device validated; **NOT** a private-data beta or production release.

## Decision and integrated scope

[PR #12](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/12) merged into `main` with squash commit `597041cca9f929ae36d32c5bb8ae76bf24750aa9` after the required branch checks passed on source head `3207e475636344042fcf649a27f2cf43f87d714a`.

The disposable APK02 Android Library now makes the initial choice explicit: start a **new fictional** journal or choose/import an independently held **fictional encrypted** archive first. No new active vault is automatically created simply because the app launches. An incomplete/occupied active slot fails closed rather than being overwritten or silently repaired.

A separately prepared and independently reopened Keystore-wrapped fictional recovery candidate may be **activated only into an absent active Library directory** after a separately displayed acknowledgement and exact typed phrase `ACTIVATE FICTIONAL JOURNAL`. File selection and recovery-key entry do **not** imply permission to activate.

The activation service authenticates the candidate *before* allocating a permanent exclusive reservation; the native publication layer whitelists the encrypted candidate directory and envelope, writes and syncs a diagnostic approval marker, fsyncs encrypted files/directories and uses Linux/Android `renameat2(RENAME_NOREPLACE)` to move the **entire** candidate+envelope into the active slot atomically. No replacement, merging, plaintext copy, automatic reset, rekey or destructive cleanup is allowed. Post-rename errors are treated as ambiguous and must never be silently retried/erased. After publication, the moved encrypted vault is independently reopened with its existing Android Keystore wrapping alias and its complete logical schema is reauthenticated.

The branch includes negative tests for no/incorrect consent, occupied destination, duplicate/concurrent activation, symlink/file collisions, injected interruption before/after native rename, first-run no-autocreate, and key-loss preservation. These are diagnostic tests only, not physical durability certification.

## Verified CI for exact PR head

| Workflow | GitHub Actions | Outcome |
| --- | --- | --- |
| Fictional encrypted Library UI, strict analysis, worker/widget tests and debug APK compile | [43593015820](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43593015820) | SUCCESS |
| API-34 synthetic Telugu IME, HOME and force-stop encrypted lifecycle regression | [43593015839](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43593015839) | SUCCESS |
| API-34 independently held fictional archive → original uninstall → clean reinstall → separate retained Keystore candidate → explicit no-replace activation → force-stop independent reopen → isolated active alias loss without encrypted-file deletion | [43593015884](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43593015884) | SUCCESS |

GitHub reported all three completed successfully before the PR was marked ready and squash-merged. These prove the **test harness on Android API 34** for the exact branch head, not the behavior of actual third-party SAF providers or production hardware.

## Hard release boundaries

- The end-to-end clean reinstall uses the **ADB test harness** to transfer a retained external archive and key. Actual Android SAF picker taps, real user-entered recovery key across a new install, document-provider variation and user-safe key custody are **not yet validated**.
- This is not a physical phone/tablet test. Real Gboard composition, TalkBack, rotation and 200% text, OEM battery/storage behavior, reboot/power-loss, filesystem exhaustion, migration and large media still require signed-off acceptance.
- The approval consent panel is fictional debug UI; the complete consumer onboarding, app lock/privacy affordances, recovery education and final production design must be validated.
- Explicit activation cannot replace or merge an existing journal. Any interrupted/unknown stage remains quarantined pending a safe, reviewed user decision; there is no automatic destructive cleanup.
- Transient native/Dart key copies and OS-level screen/clipboard/provider behavior require separate security/privacy review.
- No real personal diary text, sensitive attachment or private recovery key should be entered into any APK02 diagnostic. No production-release signing, secure cross-device sync, independent security audit, or private-data beta approval is claimed.

## Next acceptance gate

**Stage 5B (proposed, not a release approval):** validate the actual Android SAF export/import/recovery journey with the disposable fictional APK on physical phone/tablet, record make/model/Android/keyboard/OS state and each outcome, and resolve any observed UX or durability faults. Run physical lifecycle, storage, key-loss and interruption tests; review accessibility and security; preserve the no-clobber invariant. A separate explicit product/security release decision is required before enabling real diary input.

Reference: [physical-device runbook](APK02_PHYSICAL_DEVICE_ACCEPTANCE.md), [retained candidate runtime evidence](STAGE5A_ANDROID_KEYSTORE_RUNTIME.md), [roadmap](ROADMAP.md) and [decision register](DECISION_REGISTER.md).
