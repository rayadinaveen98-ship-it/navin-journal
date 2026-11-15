# Navin Journal — Stage 5D.1 editor completion semantics

**Evidence date:** 15 November 2026  
**Scope:** first small, controlled Stage 5D.1 engineering slice. **FICTIONAL DEBUG ONLY**. A completed automated test is not hardware or private-data approval.

## Problem and safety contract

The existing encrypted save-state controller intentionally permits **best-effort lifecycle or explicit flush of an unfinished IME composing buffer** so that Android power/process loss can recover the latest partial preedit. That durable *partial snapshot* can produce a valid storage receipt, but is **not** a completed writing decision. A user pressing **Save and verify** during Telugu/other-language composition must not emit the separate UI-level completed-save acknowledgment.

Before PR #20, the Writing Studio used `SaveIndicator.mayLeaveSafely` and `SavePhase.saved` after `flush()` to decide whether to invoke `onAcknowledged`. Those status fields describe a storage receipt and revision, **not whether the keyboard composing region is finished**. A freshly acknowledged partial snapshot could therefore trigger the explicit finished-page callback.

## Implemented and verified

[PR #20](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/20) **MERGED** as `43e0fb440f983aa76d32694d04e106fa7c67b50b`.

- `preview_app/lib/connected_writing_studio.dart`: after an explicit `flush()`, check `controller.isComposing` **before** the user-level `onAcknowledged` callback. If composition is open, report that the page is not fully verified and request finishing/retrying, while preserving the editor and any partial recovery snapshot.
- `preview_app/apk02_test/connected_writing_studio_test.dart`: new fictional Telugu test covers **partial snapshot persisted but callback remains 0**, followed by **completed composition saved as next version and callback exactly 1**.
- A second regression forces a failed partial write; no callback, no false completed-save label, no stored content.
- The underlying encrypted worker, Keystore, recovery keys, Archive, schema, brand, first-run flow and `scriptOnly: true` Android test guard are **unchanged**.

**Exact final PR head `eaa6aa5c671dd6caef83759fba2637dcc395490f`:**
- [Fictional Library strict analysis / worker and widget suites / debug Android build 43671492084](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43671492084) — **SUCCESS**.
- [Synthetic Telugu Android API34 HOME + force-stop regression 43671492085](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43671492085) — **SUCCESS**.

## What is NOT complete

- **No unrestricted typed personal writing is enabled** in the APK02 Library. It still instantiates `ConnectedWritingStudio(scriptOnly: true)` and uses scripted fictional samples. The separate unprotected-widget test is not a private-data release.
- No physical-device Gboard/Telugu IME, power-loss, or font/accessibility acceptance from this change.
- No consumer-level backup/restore assurance, large media import, independent security review, stable QA signing, or signed release.
- Stage 5C physical phone/tablet ledger remains pending. The previously verified Stage 5C fictional installable APK is still the manual-test baseline; this changed source is **not** a new stable user release.

## Stage 5D.1 remaining milestones

1. Lock written requirements for free-text editing, draft ownership, write/ack/retry/conflict UX, privacy-safe input lifetime, revisions and revision recovery. **PENDING**.
2. Implement editor free-form mode only within a gated, explicitly fictional, production-like integration test path; prove no secret text appears in preferences, logs, screenshots, unencrypted backup or crash output. **PENDING**.
3. Validate IME composition, save/close/navigation/lifecycle and revision conflicts on actual Android phone/tablet with bilingual accessibility. **PENDING**.
4. Validate end-to-end encrypted archive custody and clean-device recovery, disk-full/power failures, orphan retention and security threat model before authorizing real private entries. **PENDING**.
5. Founder reviews final integrated visuals and explicitly approves any private-data beta only after the complete release gate is evidenced. **NOT APPROVED**.

**Release contract:** A successful encrypted write, a complete editorial save and a verified external backup are **three different states**; none may be shown as interchangeable.
