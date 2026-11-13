# Navin Journal — Connected Writing-to-Recovery Stage 3 Handoff

**Date:** 13 November 2026  
**Status:** Design prototype and automated QA complete for connected fictional user journey; **not a production diary**.  
**Visual baseline:** Approved Still Pages × Memory Atelier, Midnight Archive dark, Folded Page mark.  
**Latest verified CI:** [GitHub Actions run 43403054214](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43403054214).

## What this changes

The original Stage 3 pages demonstrated writing, reading, and recovery separately. The [connected journey prototype](../prototype/journal-recovery-review.html) now allows a single coherent demo path using only fictional temporary data:

1. Open a journal and start a new sample entry, inheriting its journal context.
2. Write an optional title and mixed-language body, with expanding fields.
3. Add the example to the **in-memory** library, then read it.
4. Edit the same sample entry without assigning a different record ID.
5. Cancel modified draft with explicit discard confirmation.
6. Move the example to Trash after confirmation, then restore it.
7. Archive/unarchive, rename, or delete/restore a whole journal.
8. Restore an orphaned entry to a **user-selected** surviving journal when the original journal no longer exists.
9. Explore invalid/verified backup **illustrations**, which never read or write archive files.

The main [Stage 3 UX preview](../prototype/stage3-ux-preview.html) links to the connected management review. They are still two HTML previews, **not a unified native app** or shared persistent database.

## Fixes identified from real screenshots

- Fixed mobile fixed-bottom navigation covering the writing canvas. It is now hidden on the Writer route, where a visible Back control remains.
- Auto-expanding title and body surfaces avoid nested scrolling and clipping when a sample grows.
- Added Telugu-capable fallback font names and installed Noto fonts **only in the GitHub/Linux screenshot test environment** to ensure legible Unicode captures; no app runtime network font dependency is introduced.
- Reduced repetitive warning copy while preserving clear statements that the preview has **no encryption, autosave or permanent saving**.
- Added browser checks specifically preventing mobile navigation overlap with the editor.

## Verified automated evidence

The [passing GitHub run](https://github.com/rayadinaveen98-ship-it/navin-journal/actions/runs/43403054214) recorded:

| Suite | Passed |
|---|---:|
| Original mocked-DOM checks | 20/20 |
| Core Chromium navigation/layout | 90/90 |
| Extended typography and bilingual sample | 84/84 |
| Keyboard/focus checks | 33/33 |
| Brand exploration | 52/52 |
| Approved Folded Page integration | 31/31 |
| Journal/Trash/recovery browser flows | 80/80 |
| **New connected write/edit/delete/restore flow** | **41/41** |
| **Total** | **431/431** |

The browser suites cover desktop/tablet and phone-sized viewports, fake data, temporary revisions, cancel/discard confirmation, recovery flow and reload reset. The sampled automated axe-core WCAG A/AA scan covered **14 representative HTML states** (7 core plus 7 recovery) with no reported rule violations; it does **not** certify native app accessibility.

Additional staged Android vector XML geometry tests passed but no Android resource was compiled.

## Explicit design/engineering boundaries

- `Add to demo journal` changes a JavaScript object **only until page reload**. This button is a review control, **not the final saving design**. The production app's P0 requirement remains trustworthy, automatic, durable local writing.
- This code is **not encrypted** and must never be used for private real journaling.
- The "verified archive" screen is purely illustrated; it has no actual archive, checksum validation, key recovery or restore engine.
- An edited sample entry is a temporary mutable object, not a real append-only revision history.
- Automated browser text filling does not replicate Telugu input-method composition on physical Android or iOS.
- No production database, cloud sync, APK, or secure lock has been built.

## Engineering contract for Stage 4

Before any data is used outside fictional demonstrations, the app must prove:

- Stable IDs for journals and entries; edit/move/archive/restore must not accidentally duplicate, orphan or silently overwrite records.
- Durable local transaction for entry body, title, journal association, modification times and revision state.
- Autosave with acknowledged `saved`, `saving` and `error` states, including crash/force-close recovery and full-disk behavior; never claim persistence before the transaction is committed.
- Structured deletion state and a clear restore policy. Restoring an entry whose journal was deleted requires explicit destination or a verified parent restoration.
- Encrypted at-rest content and attachments, secure key lifecycle, and protected metadata/search indexes; use audited implementations rather than invented cryptography.
- Portable encrypted backup with versioned manifest, authentication/integrity checking, isolated staged restore, conflict resolution and clean-device restore tests.
- Local-only writing by default; no remote upload, analytics, logging or clipboard exposure of private content without explicit consent.

These acceptance criteria are requirements, **not completed implementations**.

## Still blocking Stage 3 signoff

- Physical phone/tablet keyboard and Telugu IME composition tests.
- Manual TalkBack/VoiceOver, large-system-font, orientation and reduced-motion review.
- Representative first-time journaler usability testing.
- Consumer-facing product name and final launcher/splash approval, beyond the approved Folded Page visual direction.

Stage 4 can be prepared as an isolated engineering proof-of-concept while these manual checks are arranged, but **a production release cannot bypass them**.
