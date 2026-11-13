# Stage 3 — Connected journal management & recovery UX review

**Status:** Interactive design simulation implemented and verified in headless Chromium. **No production data engine is implemented.**  
**Date:** 2026-11-13  
**Verified run:** [GitHub Actions 43400897845](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43400897845)  
**Source:** [journal-recovery-review.html](../prototype/journal-recovery-review.html) and [recovery.mjs](../prototype/tests/recovery.mjs)

## Why this review exists

The core UX preview previously displayed descriptive placeholders for New Journal, entry deletion, and Trash. To make the interaction contracts testable before the encrypted offline engine exists, we built a **connected, browser-only UX simulation** with fictional journal entries and a temporary in-memory model.

The simulation does **not** save a journal on disk; create a backup; encrypt user data; provide a secure lock; sync or upload content; or replace a native APK. All changes are reset when the page reloads. Never use real private journaling data in it.

## Supported simulated actions

| Flow | User behavior | Key safeguard |
|---|---|---|
| Create journal | Name new journal and open its empty state | Empty and duplicate names rejected |
| Rename journal | Change name of an existing journal | Stable simulation ID and entry association |
| Archive / unarchive | Hide from active collection, then restore | Archive stays distinct from deletion |
| Read entry | Open a fictional entry in journal context | Source journal is visible |
| Move entry to Trash | Confirm scope before removal | Entry remains recoverable |
| Restore entry | Return entry to its original journal | No duplicate entry or silently discarded content |
| Move journal to Trash | Confirm number of affected entries | Journal and linked active entries remain recoverable |
| Restore journal | Restore journal and its captured entries | Preserves original relationship |
| Permanent delete | Require separate explicit confirmation | Backup-retention caveat shown |
| Restore orphaned entry | Original journal is missing | Require explicit destination selection; never silently reassign |
| Backup/restore review | Inspect failed or simulated verified state | No real file created or applied; simulated success clearly labeled |
| Theme / responsive | Light/dark and phone/tablet reflow | Same navigation and content model |

## Validation evidence

**All checks passed in the latest verified GitHub Actions run:**

- 80/80 connected journal and recovery Playwright/Chromium checks at 360×800 and 1024×768.
- 20/20 existing mocked-DOM navigation checks.
- 90/90 baseline Chromium responsive checks.
- 84/84 extended typography/Telugu sample checks.
- 33/33 keyboard and focus checks.
- 52/52 original brand comparison checks.
- 31/31 approved Folded Page integration checks.
- Android icon XML source checks passed.
- Sampled axe-core HTML WCAG audit reported no serious or critical violations (this is not a manual accessibility certification).

The connected flow suite covers duplicate prevention, archive status, deletion and cancel behavior, restoring an entry, restoring a whole journal and its entries, returning to source, clearly labeled backup failure/verification simulation, theme switching, horizontal overflow at tested viewports, and reload resetting temporary data.

**Important distinction:** Playwright proving that a simulated restoration changes an in-memory array is *not* evidence that our future encrypted backup/restore implementation will be durable or reliable.

## Design observations and decisions

1. Keep *Archive* and *Trash* conceptually separate, with different recovery paths and user copy.
2. A destructive action must describe **exactly what and how many entries** are affected.
3. Restoration should preserve stable record relationships or prompt when restoration into the original journal is impossible.
4. A journal should not silently absorb orphaned entries. If the source journal was deleted, the user chooses a new destination.
5. Permanent deletion of local objects does not guarantee their removal from previously created backups; copy must not promise otherwise.
6. Display verification of an archive separately from creation of an archive or save of the live journal.

## Outstanding design/engineering gaps

- Existing main preview and the connected recovery review remain separate HTML pages, linked from Journals/Trash/Backup. Integration into the native UX awaits implementation.
- Real user-generated entries are not written or stored by this demonstration.
- True bulk operations, undo, revision history, media integrity, journaling privacy controls and conflict-safe synchronization are not implemented.
- No production-grade schema, encrypted database, autosave, staging restore, backup manifest, or migration logic has been built.
- Manual physical Android tablet/phone testing, real Telugu IME composition, TalkBack/VoiceOver and user usability research remain pending.
- Final consumer-facing product name and native splash/launcher assets remain open; visual mark Folded Page has been approved.

## Stage 4 engineering acceptance contract

Before enabling any real private writing:

1. Durable offline transaction semantics with verified crash-recovery behavior.
2. Encrypted local database and attachment strategy with reviewed key management.
3. Validated Trash and restore logic with explicit retention policy.
4. Backup manifest with versioning, checksums and authenticated encryption; verified clean-device restore.
5. Error states for full disk, interrupted import, invalid archive and unavailable encryption key.
6. No sensitive journal content in logs, analytics or remote requests by default.

**Do not call the Stage 3 browser prototype a secure or persistent diary.** The technical proof of concept is a separate Stage 4 task.
