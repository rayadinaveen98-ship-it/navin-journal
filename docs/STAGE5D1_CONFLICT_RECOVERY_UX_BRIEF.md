# Stage 5D.1 — Conflict Review & Preserve-as-New Experience Brief

**State:** PROPOSED DESIGN / ENGINEERING REQUIREMENTS, NOT IMPLEMENTED OR APPROVED FOR PRIVATE BETA  
**Prepared:** 15 November 2026  
**Source of truth:** [Stage 5D.1 evidence](STAGE5D1_EDITOR_SAFETY_2026-11-15.md), [roadmap](ROADMAP.md), merged PRs #20/#21 and **merged [PR #22](https://github.com/rayadinaveen98-ship-it/navin-journal/pull/22)** (fictional encrypted-worker foundation, all four exact-head CI checks passed). Only the foundation is implemented; this proposed UX and durable crash/idempotency contract are NOT implemented or approved for private beta.

## User promise and non-negotiable distinctions

When a conflicting encrypted revision exists, the app must **never silently replace it**, lose a locally edited draft, or claim the original saved successfully. Users need an understandable, non-destructive way to review and preserve both versions. A successful *preservation copy* means a distinct encrypted page exists and has been read back; it does **not** mean the original page was edited, a cloud backup exists, or that a prior unknown request failed. All present work remains fictional-data diagnostic only.

### Proposed user flow

1. **Conflict detected.** Keep the current editor visible and editable in memory; display a persistent banner with calm language: “A newer saved version of this page exists. Your current changes are not yet saved.” Suppress autosave, normal **Saved** badges and unsafe back dismissal. The unsaved draft must not be silently discarded.
2. **Review.** Show two clearly titled, read-only columns/cards where space allows: **Latest saved version** and **Your unsaved changes**. On a narrow phone, use tabs or a vertical sequence. Display revision numbers/time only when verified; protect content from screenshots and external app UI. Avoid hidden clipboard copies.
3. **Preserve separate page.** Present a confirmation that the original entry will not change. Only enable the action when the IME composition is complete, the journal is active, encrypted vault is accessible and the original still has an actual competing revision. Proposed button label **Save changes as a new page**. Do not call it “Resolve automatically” or “Replace.”
4. **Verified result.** After a storage transaction and independent encrypted readback, show **“Your changes were preserved in a separate encrypted page. The original page was not changed.”** Offer **View new page** and **Review original**. Never report this result solely from button tap or a database-write attempt.
5. **Still editing.** If the user types after capture starts, verify whether the receipt matches the current draft. If not, report **“The earlier version was preserved; your latest changes are not saved.”** Do not silently change the source conflict latch, discard edits or call a normal save callback.
6. **Errors, crash and unknown acknowledgment.** If copy creation fails, keep source text visible, no success message. If the app is killed or the response is lost, first query the encrypted vault by a stable copy-operation identifier and verify any existing new page before offering another write. Do not blindly retry an unknown-ACK create operation.

## Engineering gates before enabling the control

- **Durable idempotency:** PR #22's current per-process `preservedCopyIds` map is sufficient for an isolated fictional test but **not** cross-restart or crash/unknown-ACK safety. Add a stable operation ID committed atomically with encrypted copy metadata; retry/search must converge to one verified page. No plaintext operation metadata, device preferences or clipboard persistence.
- **Verifiable provenance:** Identify the preserved page as a conflict copy with link to the source page and source/version context, without exposing private titles or text in unencrypted logs. Source and all historical revisions remain intact. No implicit merge.
- **Atomicity:** Inactive/archived/deleted source journal, wrong source revision, storage exhaustion, process death and competing writers must fail closed. No ghost “saved” state when a transaction or readback fails.
- **Security:** Full encrypted read/write and cleanup, real Android Keystore lifecycle, safe log/notification content, `FLAG_SECURE` on sensitive recovery screens when appropriate, privacy-aware accessibility labels. No external services or payment features.
- **Accessibility:** 200% text size, TalkBack sequence, sufficient contrast, large touch targets, Telugu/English reading order, IME composition lifecycle, both narrow phone and tablet. Avoid two-column layouts that become unreadable on phones.
- **Navigation:** Back/Home/force-stop after a successful verified copy may offer viewing the new page. Before verification, source conflict stays visible and safe-exit blocked or requires a separately evidenced recovery route. Never say unsaved memory is crash-safe.

## Fictional acceptance scenarios (required before private-data enablement)

| ID | Scenario | Passing behavior |
| --- | --- | --- |
| CR-01 | Two concurrent editors write the same original | Second conflicting editor cannot overwrite latest saved revision |
| CR-02 | Conflict followed by additional typing | Conflict remains latched; no automatic storage write or false Saved |
| CR-03 | Explicit preserve with completed IME | Exactly one separate encrypted page, independent readback passes, original/history unchanged |
| CR-04 | Duplicate preserve / lost ACK / process restart | Same durable operation converges to one page; no accidental duplicate |
| CR-05 | Copy acknowledged while user edits again | Receipt is not misapplied to newer text; unsaved latest changes remain visible |
| CR-06 | Disk full / wrong key / destroyed alias / vault inaccessible | No false success, no source overwrite, retain safe recoverable state |
| CR-07 | Original archived, trashed or moved during conflict | No unauthorized copy or wrong-journal write |
| CR-08 | Exit, HOME, force-stop before/after copy | Status accurate across restart; preserved page reopens when ACKed |
| CR-09 | 200% text, TalkBack, Telugu composition on phone/tablet | Review, warning, confirm, errors accessible and legible |
| CR-10 | Archive export/recovery after preserving copy | Original, revisions, copy and provenance survive authenticated restore |

## Stage boundary

This document is a **proposal** to align product, UX, security and engineering before UI implementation. It is not permission to enable unrestricted personal writing, bypass hardware testing, change existing backup behavior, or release an APK. The current application remains scripted fictional-only. The fictional PR #22 encrypted-worker and actual Android DocumentsUI integration are verified and merged. **Next:** implement the **durable idempotency and provenance** foundation, followed by an explicit user-visible workflow and end-to-end Android tests. Do not mistake the merged worker method for a finished conflict-resolution screen or real-content approval. The founder retains design and private-beta signoff.
