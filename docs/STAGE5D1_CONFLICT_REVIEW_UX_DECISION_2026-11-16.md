# Navin Journal — Stage 5D.1 conflict review UX decision specification

**State: PROPOSED, NOT IMPLEMENTED. Founder visual/interaction approval required before UI coding. No private diary, APK release, merge or production behavior changed.**
**Prepared:** 16 Nov 2026. **Parent brief:** `STAGE5D1_CONFLICT_RECOVERY_UX_BRIEF.md`. **Engineering dependency:** verified but unmerged draft PR #25, plus proposed v3 archive compatibility RFC.

## Product promise

Users must understand that two versions exist without fearing their writing disappeared. Never silently overwrite the newer saved original, silently create duplicate copies, claim partial IME composition is complete, promise cloud backup, or say that unsaved in-memory words are crash-safe.

## Approved visual-language constraints and proposed treatment

- Preserve approved **A Still Pages + C Memory Atelier** light direction and **B Midnight Archive** dark direction; folded-page mark and current typography/tokens remain authoritative.
- Proposed visual: a quiet paper-toned inline conflict banner and a focused bottom sheet/page, not a frightening destructive red error or modal maze. Reserve red for genuinely destructive actions; use restrained warm-neutral alert accent and clear labels with explicit status.
- Maintain visual rhythm, contrast and content-safe truncation. Layout is *not* final visual approval: exact colors, typography, spacing, motion, microcopy localization and device implementation must be separately reviewed.

## States and transitions (user-visible truth)

| State | Storage meaning | UI presentation | Allowed next action |
| --- | --- | --- | --- |
| Editing pristine / saved | Last acknowledged original revision known | Standard saved indicator, only after completed explicit save | Continue editing |
| Conflict detected | Original's persisted revision is newer than editor expected; current draft remains in memory | Persistent banner: 'A newer version of this page is already saved. Your edits here are not saved.' | Review versions; keep editing; preserve as new |
| IME composing | User has not completed composition | Same conflict banner; preserve control disabled with reason 'Finish typing before saving a separate page' | Finish composing |
| Review | Read-only newest saved original plus current unsaved buffer | Two labeled regions; no auto-merge | Return to draft; explicitly choose 'Save as a new page' |
| Copy in progress | Transaction/ack outstanding | Announce 'Checking separate page…'; keep source editor, block duplicate submissions | Await result in this foreground session, no success claim |
| Copy verified, draft unchanged | New encrypted entry committed, independently reread; still conflicting source | 'A separate page was saved. The original was not changed.' | View separate page, review original |
| Copy verified, draft changed after capture | The copied snapshot is older than current draft | 'Your earlier edits were saved as a separate page. New changes made afterward are not saved.' | Continue reviewing, do not auto-copy |
| Copy error / unknown acknowledgment | No verified confirmed outcome; original still has conflict | 'We could not confirm whether the separate page was saved.' | Keep draft visible; inspect recorded copies; no blind repeat |
| Restart / old unknown ACK | Active editor's unsaved buffer may be gone; encrypted receipt may exist | Explain exactly which saved separate pages are known; do not claim vanished unsaved text was preserved | Open verified candidate, review original, seek recovery guidance |
| Copy edited/trashed later | Receipt still identifies historical copy, current copy may differ | 'A separate page was created earlier, but has since changed or moved to Trash.' | Inspect with separate Trash/restoration permissions; never silent retry |

**Critical invariant:** A successful *copy* is never a successful original-page save. The original conflict remains latched unless a separately approved resolution action occurs. After force-stop, never promise lossless reconstruction of an in-memory draft.

## Step-by-step UX flow

1. On a real version conflict, leave editor text and cursor intact; suppress autosave and unsafe dismissal. Announce the status change once to TalkBack without resetting focus. Show visible persistent 'Review changes' affordance.
2. Tap 'Review changes': on phones use sequential tabs 'Newest saved page' and 'Your unsaved draft' or a vertically stacked review; on tablets prefer balanced two-column regions with independent scroll and visible headings. Do not use color alone to distinguish sides.
3. Explain: 'The newest saved page will remain unchanged. You can preserve these edits as a separate page.' No clipboard, no automatic merge, no claim that a draft is already backed up.
4. Show primary **'Save as a new page'** and secondary **'Keep editing'**. Disable primary if IME composition is unfinished, vault inaccessible, journal archived/trashed, no actual newer saved original, or the buffer is blank. The disabled reason must be accessible and displayed. Use a confirmation description instead of requiring users to retype a dangerous phrase.
5. On tap: capture the exact snapshot; create a new page under one opaque, durable session operation ID; require encrypted SQL commit and independent readback. Do not mark the original saved or dismiss the editor. If a subsequent keyboard change occurs, compare with captured buffer and explicitly state newer text is unsaved.
6. On confirmed success: present two navigation choices, 'View saved separate page' and 'Review newest original'. The draft remains available until the approved safe-exit condition is established. Do not silently erase a changed draft.
7. On ambiguous or failed result: keep current text visible and the conflict warning. Check encrypted receipt metadata and target page existence; if the operation has a committed receipt, report that fact only after independent verification. If the same session token is gone after restart, list candidate receipts by source ID with provenance, not by guessed content. Do not auto-create another page to make an alert disappear.

## Safe navigation and recoverability rules

- Back while the buffer still has unpreserved edits must never be an unconditional dismiss. Offer 'Continue editing' and a review route. A final discard path, if ever designed, must clearly warn that unsaved writing will be lost and must never silently modify the saved original.
- OS kill / app crash can discard memory-only edits. A non-ACKed write is not proof that storage is empty. After restart, read the encrypted vault and receipt ledger before promising a recovery path.
- Do not persist raw draft text in widget state restoration, debug logs, crash analytics, notifications, clipboard, plaintext SharedPreferences, screenshots or search indexes. Any future crash-safe draft ownership requires a separately scoped encrypted durable-draft model and security approval.
- `FLAG_SECURE` for sensitive review surfaces is a proposed security behavior; assess platform ergonomics, accessibility and limitations, rather than treating it as a guarantee against screenshots.
- A previously preserved copy may have been edited, moved, or trashed. Show its current verified state and link to appropriate navigation. It must **not** be re-created simply because its content changed after receipt creation.

## Accessibility and localization acceptance

- 200% text scaling without clipped title/actions on narrow Android phones or tablets; landscape, large touch targets and keyboard navigation where available.
- Correct TalkBack focus reading order: conflict alert → newest saved page heading/content → your unsaved draft heading/content → consequence summary → primary and secondary actions → status result. Live-region announcements must not be repeated on each keystroke.
- Telugu and English grapheme/IME composition handling. Prevent save-as-new while Gboard or other IME preedit remains active. Test HOME/force-stop during composition and after entering a competing version; never confuse partial encrypted snapshot with editorial completion.
- Meaningful labels, contrast in both themes, non-color status cues, no reliance on animation, reduce-motion behavior and ability to leave review without losing in-memory editor state.

## Proposed acceptance matrix (all fictional fixtures until private beta approval)

| ID | Scenario | Required evidence |
| --- | --- | --- |
| CR01 | Two simultaneous editors edit same source | Losing editor cannot overwrite newer original |
| CR02 | More typing after conflict | Conflict latch persists and suppresses all automatic writes |
| CR03 | Explicit preservation with completed composition | Exactly one encrypted new page; original and revisions unchanged |
| CR04 | Repeated action / lost ACK / restarted worker | Same operation receipt converges to one new page; no duplicate |
| CR05 | More typing while copy is in flight | UI says earlier snapshot copied, latest text not saved |
| CR06 | Simulated ENOSPC/Keystore failure | No success ACK or partial original mutation |
| CR07 | Source archived, trashed or moved | Fail closed, explain reason, no journal escape |
| CR08 | HOME/force-stop before/after commit | No false Saved after restart; independently discover receipt |
| CR09 | 200% font / TalkBack / Telugu + phone/tablet | Focus, content and action sequence accessible |
| CR10 | Authenticated v3 backup and clean restore | Copy and provenance restored exactly; no loss of idempotency |
| CR11 | Copy later edited or trashed | Previous receipt remains findable; no duplicate on retry |
| CR12 | Unsupported legacy/malformed backup | Clear compatibility failure, existing vault unchanged |
| CR13 | Kill before SQL receipt commits | Neither copy nor receipt partially published; unsaved text not falsely called durable |

## Implementation boundary and founder decisions

- Engineering stages: (1) approve authenticated v3 archive contract and PR #25 schema intent; (2) implement provenance-preserving export+restore with isolation; (3) implement this conflict-review UI in *fictional-only* debug pathway; (4) verify complete CR01–CR13 automated suite; (5) real phone/tablet/TalkBack/IME and power-loss review; (6) separately decide private-data beta.
- Approval needed on user copy ('Save as a new page'), no destructive overwrite or auto-merge, mobile/tablet review layout, and notification/error wording. The initial look must align with approved theme rather than launch an unrelated redesign.
- No paid infrastructure, telemetry, cloud sync or new subscription is proposed. Final security/accessibility review remains a release blocker.

**Decision requested:** Approve or revise the proposed flow and v3 compatibility contract before production code changes or UI rollout. The existing installable Stage 5C APK stays the manual-testing baseline.
