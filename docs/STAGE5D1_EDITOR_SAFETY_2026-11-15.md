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

## Second safety slice — latched version conflicts (15 November 2026)

[PR #21](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/21) **MERGED**, commit `148907512d601877be5a8766b7342394e387ab0f`.

**Discovered risk:** after an encrypted worker rejected a stale `expectedVersion`, the controller only set a transient `SavePhase.conflict`. Further typing could restore `dirty` and schedule new writes; reverting to an earlier acknowledged snapshot could even show `saved` without confirming that the competing persisted revision was resolved. This was a correctness risk in future free-form use, not proof of previously observed private-data loss.

**Implemented (fictional-only integration remains unchanged):**
- The controller now latches a session-level `hasUnresolvedConflict` flag after `DraftConflict`, preserves subsequent fictional edits in memory, prevents further automatic/manual storage writes, and refuses dismiss/retry until a future explicit reconciliation flow is available.
- Returning to previously acknowledged text and ending keyboard composition cannot clear this latch. Queued debounce is cancelled on conflict. The existing encrypted version-checking storage engine remains unchanged.
- The Writing Studio's conflict dialog explains that automatic saves are paused, leaves the editor open and hides the unsafe **Retry saving** action. Other transient save failures may still retry normally.
- **Three controller regressions:** edit after conflict with store later becoming writable, revert to formerly acknowledged snapshot, in-flight conflict with pending debounce and Telugu composing. **One Flutter widget regression:** subsequent free-form fictional edits cannot resume writes, call `onAcknowledged`, dismiss the unsaved editor or surface unsafe retry.
- [Exact-head Library widget/worker/recovery and Android debug APK CI 43674401102](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43674401102) **SUCCESS** and [API34 synthetic Telugu HOME/force-stop emulator CI 43674401157](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43674401157) **SUCCESS**, both at PR head `b1796dd8848c19ad3bf35996261690718bff6773`.

**Product limitation:** a latched conflict intentionally blocks safe exit and cannot be resolved within the current fictional editor. It is a *fail-closed safety stop*, not a complete user-friendly recovery solution. Before any real private writing, design and implement an **explicit, non-destructive conflict review/copy-as-new process**, with verified encrypted preservation of both competing revisions, no clipboard dependency, and hardware/restore tests. Do not claim that such conflict resolution has already been implemented.

## Third engineering slice — encrypted conflict copy-as-new foundation [MERGED + FOUR CI GATES VERIFIED; FICTIONAL ONLY]

[PR #22](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/22) at `0086d8bfd0fde3d99693178089a2b21d17f19c60` implements a **fictional-only worker command**, not a consumer UI. It requires a genuine session-level stored-version conflict, an active same-journal original with a strictly newer competing encrypted revision, nonblank completed content, and writes the losing draft to a *new* encrypted page using the existing transactional `JournalVault.createEntry`. It immediately reads back the new encrypted page before acknowledging. The original entry and revision history are never edited. One in-memory conflict session receives only one idempotent copy for identical content; a changed snapshot is rejected rather than silently copied again. A receipt distinguishes whether the verified snapshot still equals the live draft.

**New tests** (3 encrypted worker integration cases) cover separate source/copy and unchanged historical revisions after worker shutdown/reopen, exact-snapshot same-session duplicate handling, no-conflict rejection and archived-journal rejection.

**Exact PR head CI status as of 15 Nov 2026:**
- [Encrypted Library widget/worker and Android debug APK workflow 43675728678](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43675728678): **SUCCESS**.
- [API34 synthetic Telugu lifecycle 43675728662](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43675728662): **SUCCESS**.
- [Android portable archive separate-key clean reinstall 43675728730](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43675728730): **SUCCESS**.
- [Actual AndroidX DocumentsUI picker workflow 43675728708](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43675728708): **FAILURE twice**, first at `Missing native fictional phase SAF_IMPORT_READY` (emulator ColorBuffer/render warnings) and next at `Real DocumentsUI unavailable; category=other_system_window probePhase=SAF_ROUNDTRIP_EXPORT_READY probeAlive=true`. Both failed runs compiled and passed editor contract tests. **Root cause is not established.** The PR changed only encrypted editor worker and worker integration tests, not the native picker or its driver. Record and investigate under [QA issue #23](https://github.com/rayadinaveen98-ship-it/navin-journal/issues/23), without skipping or weakening actual picker authentication.

**Historical QA failure and resolution (15 Nov 2026):** The two unsuccessful native picker attempts above remain part of the incident record. A separate, isolated test-driver fix [PR #24](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/24), merged `becf71be`, synchronized Android's disposable probe force-stop/clear/launch, required a real system picker preflight, and kept the encrypted DocumentsUI export/import roundtrip unchanged. The QA run [43713646753](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43713646753) **PASSED twice** on the same head. [QA issue #23](https://github.com/rayadinaveen98-ship-it/navin-journal/issues/23) retains the failures and evidence; successful emulator runs do not imply physical OEM certification.

**Final Stage 5D.1-C disposition:** [PR #22](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/22) **MERGED** in commit `a7af9d36ac8637dacd1dbd8b124148ffd854b9e3`. Its exact tested feature head `0e0950adeed58c9872aa32158a2035e2558b3f49` integrated the exact QA-driver content from merged PR #24 and passed all four workflows: [fictional Library/Android debug APK 43740640925](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43740640925), [real AndroidX DocumentsUI 43740640851](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43740640851), [API34 Telugu lifecycle 43740640852](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43740640852), and [portable recovery clean reinstall 43740640854](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43740640854), all **SUCCESS**. The worker API is now in `main` but **not in a new user-installable Stage5C APK** and **not a delivered user-facing Preserve-as-New-Page workflow**. Cross-process crash/unknown-ACK idempotency and conflict provenance are not yet durable. See the [proposed UX/engineering acceptance brief](STAGE5D1_CONFLICT_RECOVERY_UX_BRIEF.md) before enabling any UI. The **entire Stage 5D.1 remains incomplete**, with real private writing and physical QA still blocked.

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
